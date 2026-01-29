-- Central type definitions for Motion.
-- These types define the data contracts shared between
-- editor, runtime, and serialization layers.

export type Time = number
export type Seconds = number
export type PropertyName = string
export type Id = string

export type Value = CFrame | Vector3 | Vector2 | UDim2 | UDim | number | boolean

--Add more interpolation
export type Interpolation = "Linear" | "Cubic" | "Bezier" | "Constanct" | "Quad" | "Exponential"
export type InterpolationDirection = "In" | "Out" | "InOut" | "OutIn"

export type BezierHandle = {
    x: number, -- time offset
    y: number, -- value offset
}

-- A single point in time for a specific attribute
export type Keyframe = {
    id: Id,
    time: Time,
    value: any,
    easing: Interpolation?,
    easingDirection: InterpolationDirection?,
    handleLeft: { x: number, y: number }?,
    handleRight: { x: number, y: number }?,
}

-- A collection of keyframes for one sub-property (e.g., just "X" or "R")
export type Channel = {
    keyframes: { Keyframe }
}

-- A property belongs to an instance (e.g., "Color3" or "CFrame")
-- It contains multiple channels (e.g., R, G, B)
export type Property = {
    name: string,
    channels: { [string]: Channel }
}

-- The clipboard format for Copy/Paste
export type ClipboardItem = {
    trackId: string,
    propertyName: string,
    channelName: string,
    value: any,
    easing: string,
    easingDirection: string?,
    offsetTime: number,
}

export type Error = {
    Code: number,
    Message: string,
    Context: string?, -- Which module threw the error
    Timestamp: number,
}

return {}