using System.Collections.Generic;
using ShapeUp.Core.ShapeEditor;
using UnityEngine;

namespace ShapeUp.Features.Editor2D;

/// <summary>Undo/redo via full <see cref="Project"/> JSON snapshots (Unity JsonUtility).</summary>
public sealed class ProjectUndoStack
{
    const int MaxDepth = 48;
    readonly List<string> _undo = new();
    readonly List<string> _redo = new();

    public bool CanUndo => _undo.Count > 0;
    public bool CanRedo => _redo.Count > 0;

    public void Clear()
    {
        _undo.Clear();
        _redo.Clear();
    }

    /// <summary>Record current project before a mutation; clears redo branch.</summary>
    public void PushBeforeMutation(Project current)
    {
        _redo.Clear();
        _undo.Add(JsonUtility.ToJson(current.Clone()));
        while (_undo.Count > MaxDepth)
            _undo.RemoveAt(0);
    }

    public Project? PopUndo(Project present)
    {
        if (_undo.Count == 0)
            return null;
        _redo.Add(JsonUtility.ToJson(present.Clone()));
        var i = _undo.Count - 1;
        var json = _undo[i];
        _undo.RemoveAt(i);
        return JsonUtility.FromJson<Project>(json);
    }

    public Project? PopRedo(Project present)
    {
        if (_redo.Count == 0)
            return null;
        _undo.Add(JsonUtility.ToJson(present.Clone()));
        var i = _redo.Count - 1;
        var json = _redo[i];
        _redo.RemoveAt(i);
        return JsonUtility.FromJson<Project>(json);
    }
}
