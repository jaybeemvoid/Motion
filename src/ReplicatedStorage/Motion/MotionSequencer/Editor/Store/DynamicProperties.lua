-- DynamicProperties_Updated.lua
-- Uses PropertyTypeRegistry for automatic channel detection

local DynamicProperties = {}
local PropertyTypes = require(script.Parent.PropertyRegistery)

-- Property definitions now just list what's animatable
-- Channels are determined automatically by PropertyTypeRegistry
local ANIMATABLE_PROPERTIES = {
    -- Parts & Models
    BasePart = {
        "CFrame", "Position", "Orientation", "Size", 
        "Color", "Transparency", "Reflectance", "CastShadow",
        "Material", "CustomPhysicalProperties"
    },

    MeshPart = {
        "TextureID"
    },

    SpecialMesh = {
        "Scale", "Offset"
    },

    Decal = {
        "Transparency", "Color3"
    },

    Texture = {
        "Transparency", "Color3", "OffsetStudsU", "OffsetStudsV",
        "StudsPerTileU", "StudsPerTileV"
    },

    -- Lighting
    Light = {
        "Brightness", "Color", "Enabled", "Shadows"
    },

    PointLight = {
        "Range"
    },

    SpotLight = {
        "Angle", "Face", "Range"
    },

    SurfaceLight = {
        "Angle", "Face", "Range"
    },

    -- Effects
    -- Effects
    ParticleEmitter = {
        "Rate", "Color", "Size", "Transparency", 
        "Lifetime", "Speed", "Acceleration",
        "Drag", "EmissionDirection", "Enabled",
        "LightEmission", "LightInfluence",
        "Orientation", "Rotation", "RotSpeed",
        "SpreadAngle", "VelocityInheritance", "ZOffset",
        "Brightness", "SquashFactor"
    },

    Beam = {
        "Color", "Transparency", "LightEmission", "LightInfluence",
        "Width0", "Width1", "CurveSize0", "CurveSize1",
        "Enabled", "FaceCamera"
    },

    Trail = {
        "Color", "Transparency", "LightEmission", "LightInfluence",
        "Lifetime", "MinLength", "Enabled", "FaceCamera",
        "WidthScale"
    },

    Fire = {
        "Color", "SecondaryColor", "Size", "Heat", "Enabled"
    },

    Smoke = {
        "Color", "Opacity", "RiseVelocity", "Size", "Enabled"
    },

    Sparkles = {
        "SparkleColor", "Enabled"
    },

    -- UI Elements
    GuiObject = {
        "Position", "Size", "AnchorPoint", 
        "BackgroundColor3", "BackgroundTransparency",
        "BorderColor3", "BorderSizePixel",
        "Rotation", "Visible", "ZIndex",
        "LayoutOrder"
    },

    TextLabel = {
        "TextColor3", "TextTransparency",
        "TextStrokeColor3", "TextStrokeTransparency", 
        "TextSize", "TextScaled"
    },

    TextButton = {
        "TextColor3", "TextTransparency",
        "TextStrokeColor3", "TextStrokeTransparency", 
        "TextSize"
    },

    TextBox = {
        "TextColor3", "TextTransparency",
        "TextStrokeColor3", "TextStrokeTransparency", 
        "TextSize", "PlaceholderColor3"
    },

    ImageLabel = {
        "ImageColor3", "ImageTransparency",
        "ImageRectOffset", "ImageRectSize"
    },

    ImageButton = {
        "ImageColor3", "ImageTransparency",
        "ImageRectOffset", "ImageRectSize"
    },

    ViewportFrame = {
        "ImageColor3", "ImageTransparency",
        "Ambient", "LightColor", "LightDirection"
    },

    ScrollingFrame = {
        "CanvasPosition", "CanvasSize",
        "ScrollBarImageColor3", "ScrollBarImageTransparency"
    },

    Frame = {
        -- Inherits from GuiObject
    },

    -- UI Constraints & Layouts
    UIGradient = {
        "Color", "Transparency", "Offset", "Rotation", "Enabled"
    },

    UIStroke = {
        "Color", "Transparency", "Thickness", "Enabled"
    },

    UICorner = {
        "CornerRadius"
    },

    UIPadding = {
        "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight"
    },

    UIScale = {
        "Scale"
    },

    -- Camera
    Camera = {
        "CFrame", "FieldOfView", "Focus"
    },

    -- Audio
    Sound = {
        "Volume", "PlaybackSpeed", "TimePosition", "Playing",
        "RollOffMinDistance", "RollOffMaxDistance"
    },

    SoundGroup = {
        "Volume"
    },

    EqualizerSoundEffect = {
        "HighGain", "MidGain", "LowGain"
    },

    ReverbSoundEffect = {
        "DecayTime", "Density", "Diffusion", "DryLevel", "WetLevel"
    },

    -- Constraints & Physics
    Attachment = {
        "CFrame", "Visible"
    },

    Constraint = {
        "Enabled"
    },

    HingeConstraint = {
        "TargetAngle", "AngularVelocity", "ServoMaxTorque"
    },

    SpringConstraint = {
        "FreeLength", "Stiffness", "Damping", "MaxForce"
    },

    RopeConstraint = {
        "Length", "Thickness", "Visible"
    },

    RodConstraint = {
        "Length", "Thickness", "Visible"
    },

    -- Humanoid & Character
    Humanoid = {
        "WalkSpeed", "JumpPower", "Health", "MaxHealth",
        "HipHeight", "CameraOffset"
    },

    -- Special Objects
    Sky = {
        "CelestialBodiesShown", "SunAngularSize", "MoonAngularSize",
        "StarCount"
    },

    Atmosphere = {
        "Density", "Offset", "Color", "Decay", "Glare", "Haze"
    },

    Clouds = {
        "Cover", "Density", "Color"
    },

    BloomEffect = {
        "Intensity", "Size", "Threshold", "Enabled"
    },

    BlurEffect = {
        "Size", "Enabled"
    },

    ColorCorrectionEffect = {
        "Brightness", "Contrast", "Saturation", 
        "TintColor", "Enabled"
    },

    SunRaysEffect = {
        "Intensity", "Spread", "Enabled"
    },

    DepthOfFieldEffect = {
        "FarIntensity", "FocusDistance", "InFocusRadius",
        "NearIntensity", "Enabled"
    }
}

function DynamicProperties.getAvailableProperties(instance)
    if not instance then return {} end

    local available = {}
    local className = instance.ClassName
    local seenProps = {}

    -- Helper to add properties from a class
    local function addPropsFromClass(cls)
        local propList = ANIMATABLE_PROPERTIES[cls]
        if propList then
            for _, propName in ipairs(propList) do
                if not seenProps[propName] then
                    seenProps[propName] = true

                    -- Try to get the property value to determine type
                    local success, value = pcall(function()
                        return instance[propName]
                    end)

                    if success and value ~= nil then
                        local valueType = typeof(value)
                        local channels = PropertyTypes.getChannels(valueType)

                        table.insert(available, {
                            name = propName,
                            type = valueType,
                            channels = channels
                        })
                    end
                end
            end
        end
    end

    -- Add direct class properties
    addPropsFromClass(className)

    -- Add inherited properties
    for baseClass, _ in pairs(ANIMATABLE_PROPERTIES) do
        if instance:IsA(baseClass) and baseClass ~= className then
            addPropsFromClass(baseClass)
        end
    end

    return available
end

function DynamicProperties.createPropertyStructure(propName, propType, channels, initialValue)
    local channelMap = {}
    for _, chanName in ipairs(channels) do
        channelMap[chanName] = {keyframes = {}}
    end

    return {
        name = propName,
        type = propType,
        isExpanded = false,
        defaultValue = initialValue,
        channels = channelMap
    }
end

function DynamicProperties.hasProperty(track, propertyName)
    if not track.properties then return false end

    for _, prop in ipairs(track.properties) do
        if prop.name == propertyName then
            return true, prop
        end
    end

    return false
end

function DynamicProperties.addPropertyToTrack(track, propertyName, instance)
    if not instance then return track end

    local exists = DynamicProperties.hasProperty(track, propertyName)
    if exists then return track end

    local success, value = pcall(function()
        return instance[propertyName]
    end)

    if not success then
        warn("Property not accessible:", propertyName)
        return track
    end

    local valueType = typeof(value)
    if not PropertyTypes.isSupported(valueType) then
        warn("Property type not supported:", propertyName, valueType)
        return track
    end

    local channels = PropertyTypes.getChannels(valueType)
    local nextTrack = table.clone(track)
    nextTrack.properties = table.clone(track.properties or {})

    local newProp = DynamicProperties.createPropertyStructure(
        propertyName,
        valueType,
        channels,
        value
    )

    table.insert(nextTrack.properties, newProp)
    return nextTrack
end

return DynamicProperties