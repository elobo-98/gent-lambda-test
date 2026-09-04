#!/bin/bash
# Exercises deploy/deploy.sh with mock environment variables and a stubbed `gent` binary - no real
# AWS/Gitea/gent calls are made. Run this locally or as a CI step to catch template/script
# regressions before trusting the generated platform-context file or the real deploy.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

rendered="deploy/platform-context.rendered.yaml"
fake_bin="$(mktemp -d)"
gent_calls="$(mktemp)"
stderr_capture="$(mktemp)"

# Any pre-existing (real) rendered context is backed up and restored afterward, so this test never
# clobbers a developer's local state.
backup=""
if [[ -f "$rendered" ]]; then
  backup="$(mktemp)"
  cp "$rendered" "$backup"
fi
cleanup() {
  if [[ -n "$backup" ]]; then mv "$backup" "$rendered"; else rm -f "$rendered"; fi
  rm -rf "$fake_bin"
  rm -f "$gent_calls" "$stderr_capture"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# A fake `gent` that records its arguments instead of touching AWS/Gitea. GENT_FAKE_EXIT_CODE lets
# a case simulate a failing deploy.
cat >"$fake_bin/gent" <<'FAKE_GENT'
#!/bin/bash
echo "$@" > "$GENT_CALLS_FILE"
exit "${GENT_FAKE_EXIT_CODE:-0}"
FAKE_GENT
chmod +x "$fake_bin/gent"

echo "Case: valid environment variables render the context and invoke the stubbed gent correctly"
rm -f "$rendered" "$gent_calls"
env PATH="$fake_bin:$PATH" GENT_CALLS_FILE="$gent_calls" GENT_ENVIRONMENT=staging LAMBDA_REGION=us-east-1 \
  bash deploy/deploy.sh >/dev/null
[[ -f "$rendered" ]] || fail "expected $(basename "$rendered") to be written"
grep -Fq "environment: staging" "$rendered" || fail "environment placeholder was not substituted"
grep -Fq "region: us-east-1" "$rendered" || fail "region placeholder was not substituted"
grep -Eq '\$\{[A-Z_]+\}' "$rendered" && fail "unresolved placeholder(s) remain in output"
[[ -s "$gent_calls" ]] || fail "expected the stubbed gent to have been invoked"
grep -Fq "platform deploy --environment staging --platform-context deploy/platform-context.rendered.yaml" \
  "$gent_calls" || fail "gent was not invoked with the expected arguments: $(cat "$gent_calls")"

echo "Case: a different environment/region substitutes correctly (no stale values carried over)"
rm -f "$rendered" "$gent_calls"
env PATH="$fake_bin:$PATH" GENT_CALLS_FILE="$gent_calls" GENT_ENVIRONMENT=production LAMBDA_REGION=eu-west-1 \
  bash deploy/deploy.sh >/dev/null
grep -Fq "environment: production" "$rendered" || fail "environment placeholder was not substituted for production"
grep -Fq "region: eu-west-1" "$rendered" || fail "region placeholder was not substituted for production"
grep -Fq "us-east-1" "$rendered" && fail "stale value from a previous run leaked into output"
grep -Fq "platform deploy --environment production --platform-context deploy/platform-context.rendered.yaml" \
  "$gent_calls" || fail "gent was not invoked with the expected arguments for production: $(cat "$gent_calls")"

echo "Case: a failing gent causes deploy.sh to fail too"
rm -f "$rendered" "$gent_calls"
if env PATH="$fake_bin:$PATH" GENT_CALLS_FILE="$gent_calls" GENT_FAKE_EXIT_CODE=1 \
  GENT_ENVIRONMENT=staging LAMBDA_REGION=us-east-1 bash deploy/deploy.sh >"$stderr_capture" 2>&1; then
  fail "expected deploy.sh to fail when gent fails"
fi
[[ -s "$gent_calls" ]] || fail "expected the stubbed gent to have been invoked before failing"

echo "Case: missing GENT_ENVIRONMENT fails fast without rendering or invoking gent"
rm -f "$rendered" "$gent_calls"
if env PATH="$fake_bin:$PATH" GENT_CALLS_FILE="$gent_calls" LAMBDA_REGION=us-east-1 \
  bash deploy/deploy.sh >"$stderr_capture" 2>&1; then
  fail "expected failure when GENT_ENVIRONMENT is unset"
fi
grep -Fq "GENT_ENVIRONMENT" "$stderr_capture" || fail "error message did not mention GENT_ENVIRONMENT"
[[ -f "$rendered" ]] && fail "output should not exist when GENT_ENVIRONMENT is missing"
[[ -f "$gent_calls" ]] && fail "gent should not have been invoked when GENT_ENVIRONMENT is missing"

echo "Case: missing LAMBDA_REGION fails fast without rendering or invoking gent"
rm -f "$rendered" "$gent_calls"
if env PATH="$fake_bin:$PATH" GENT_CALLS_FILE="$gent_calls" GENT_ENVIRONMENT=staging \
  bash deploy/deploy.sh >"$stderr_capture" 2>&1; then
  fail "expected failure when LAMBDA_REGION is unset"
fi
grep -Fq "LAMBDA_REGION" "$stderr_capture" || fail "error message did not mention LAMBDA_REGION"
[[ -f "$rendered" ]] && fail "output should not exist when LAMBDA_REGION is missing"
[[ -f "$gent_calls" ]] && fail "gent should not have been invoked when LAMBDA_REGION is missing"

echo "All deploy.sh tests passed."
