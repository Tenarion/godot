using System;

namespace Godot
{
    /// <summary>
    /// Exports the annotated member as a readonly property of the Godot Object.
    /// </summary>
    [AttributeUsage(AttributeTargets.Field | AttributeTargets.Property)]
    public sealed class ExportReadOnlyAttribute : Attribute;
}
