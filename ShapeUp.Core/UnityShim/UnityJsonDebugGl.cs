using System;
using System.Text.Json;

namespace UnityEngine;

public static class JsonUtility
{
    static readonly JsonSerializerOptions Options = new() { IncludeFields = true, WriteIndented = false };

    public static string ToJson(object obj) => JsonSerializer.Serialize(obj, obj.GetType(), Options);

    public static T FromJson<T>(string json) => JsonSerializer.Deserialize<T>(json, Options)!;
}

public static class Debug
{
    public static void Assert(bool condition, string? message = null)
    {
        System.Diagnostics.Debug.Assert(condition, message);
    }

    public static void LogError(string message) => Console.Error.WriteLine(message);

    public static void LogWarning(string message) => Console.WriteLine(message);
}

public static class GL
{
    public static void Color(Color c) { }

    public static void Vertex3(float x, float y, float z) { }
}
