using Unity.Mathematics;

namespace ShapeUp.Core.ShapeEditor
{
    /// <summary>Any object that can be selected in the 2D Shape Editor.</summary>
    public interface ISelectable
    {
        /// <summary>Whether the object is selected.</summary>
        bool selected { get; set; }

        /// <summary>The position of the object on the grid.</summary>
        float2 position { get; set; }

        /// <summary>General purpose editor variable available to the object with input focus.</summary>
        float2 gpVector1 { get; set; }
    }
}

