# hello-lambda

A minimal .NET AWS Lambda function deployed via the `gent` CLI's `lambda` platform
(`gent.io/lambda/v1alpha1`). It exists to demonstrate the build/publish/deploy pipeline, not as a
real workload - see `src/HelloLambda/Function.cs` for the (uppercase-echo) handler.

## Prerequisites

- .NET 10 SDK
- The `gent` CLI on `PATH`
- A Lambda function named `hello-lambda` already created in AWS with the `dotnet10` managed runtime
  and handler `HelloLambda::HelloLambda.Function::FunctionHandler` (Gent never creates it)
- AWS credentials with `lambda:UpdateFunctionCode` on that function
- Gitea credentials: `GENT_REGISTRY_USERNAME`, `GENT_GITEA_TOKEN`, and a registry host
  (`GENT_GITEA_REGISTRY` or `--registry`)

Before deploying, edit the placeholder `repository: sandbox/hello-lambda` in `GentFile.yaml` for
your own Gitea setup.

`deploy/deploy.sh` renders `deploy/platform/platform-context.yaml` (its `${VAR}` placeholders
substituted with environment variables supplied by the CI pipeline, e.g. TeamCity build
parameters) into `deploy/platform-context.rendered.yaml` - not checked in - and then calls
`gent platform deploy` itself. Required variables:

| Variable | Fills in |
| --- | --- |
| `GENT_ENVIRONMENT` | `environment` (also passed as `gent platform deploy --environment`) |
| `LAMBDA_REGION` | `platforms.lambda.region` |

## Pipeline

```bash
gent build
gent artifact publish --name function-package --registry "$GENT_GITEA_REGISTRY" --branch "$GENT_BRANCH"
GENT_ENVIRONMENT=staging LAMBDA_REGION=us-east-1 ./deploy/deploy.sh
```

`--branch` (or `GENT_BRANCH`) determines the release policy: `main` requires a plain release version
and rejects `--prerelease`; any other branch requires `--prerelease` and a prerelease-shaped version
(e.g. `1.0.0-beta.1`) - see the application's own `.csproj`/`Directory.Build.props` `<Version>`.

## Testing

`deploy/test-deploy.sh` exercises `deploy/deploy.sh` with mock `GENT_ENVIRONMENT`/`LAMBDA_REGION`
values and a stubbed `gent` binary on `PATH` - no real AWS/Gitea/`gent` calls are made. It covers
correct substitution across two different environment/region pairs (checking for stale values
leaking between runs), that the stubbed `gent` receives the expected `platform deploy` arguments,
that a failing `gent` causes `deploy.sh` to fail too, and both required-variable failure cases. Any
real `deploy/platform-context.rendered.yaml` you already generated locally is backed up and
restored automatically:

```bash
./deploy/test-deploy.sh
```
