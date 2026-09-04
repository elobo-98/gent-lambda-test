using Amazon.Lambda.Core;

[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace HelloLambda;

public class Function
{
    /// <summary>A minimal Lambda handler: echoes the input back, uppercased. Replace with real
    /// business logic - this only exists to prove the build/publish/deploy pipeline end-to-end.</summary>
    public string FunctionHandler(string input, ILambdaContext context)
    {
        context.Logger.LogInformation($"Received input: {input}");
        return input.ToUpperInvariant();
    }
}
