using Godot;

namespace ShapeUp.Infrastructure.Clipboard;

public static class GodotClipboard
{
    public static void SetText(string text) => DisplayServer.ClipboardSet(text);

    public static string GetText() => DisplayServer.ClipboardGet();
}
