using System.Numerics;

namespace ShapeUp.Core.TrenchBroomClipboard;

/// <summary>Unity-compatible plane: normal and distance such that closest point to origin is -Normal * Distance.</summary>
public readonly record struct UnityStylePlane(Vector3 Normal, float Distance);
