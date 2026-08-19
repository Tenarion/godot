using System.Threading.Tasks;
using Xunit;

namespace Godot.SourceGenerators.Tests;

public class ScriptSignalsGeneratorTests
{
    [Fact]
    public async Task EventSignals()
    {
        await CSharpSourceGeneratorVerifier<ScriptSignalsGenerator>.Verify(
            "EventSignals.cs",
            "EventSignals_ScriptSignals.generated.cs"
        );
    }

    [Fact]
    public async Task Generic()
    {
        await CSharpSourceGeneratorVerifier<ScriptSignalsGenerator>.Verify(
            "Generic.cs",
            "Generic(Of T)_ScriptSignals.generated.cs"
        );
    }
}
