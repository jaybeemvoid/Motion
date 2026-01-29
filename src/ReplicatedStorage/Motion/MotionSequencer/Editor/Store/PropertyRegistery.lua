-- PropertyTypeRegistry.lua
-- Centralized system for handling all property types in the sequencer

local PropertyTypes = {}

local RQuat = require(script.Parent.Parent.Parent.Core.Math.RQuat)

--------------------------------------------------------------------
-- TYPE DEFINITIONS
--------------------------------------------------------------------

PropertyTypes.TypeDefinitions = {
    CFrame = {
        channels = {"X", "Y", "Z", "RX", "RY", "RZ"},

        decompose = function(value)
            local pos = value.Position
            local rx, ry, rz = value:ToEulerAnglesXYZ()

            return {
                X = pos.X,
                Y = pos.Y,
                Z = pos.Z,
                RX = math.deg(rx),
                RY = math.deg(ry),
                RZ = math.deg(rz)
            }
        end,

        recompose = function(channels, instance)
            local pos = Vector3.new(
                channels.X or instance.CFrame.Position.X,
                channels.Y or instance.CFrame.Position.Y,
                channels.Z or instance.CFrame.Position.Z
            )

            local rot
            if channels.RX or channels.RY or channels.RZ then
                rot = RQuat.fromEuler(
                    math.rad(channels.RX or 0),
                    math.rad(channels.RY or 0),
                    math.rad(channels.RZ or 0)
                ):toCFrame()
            else
                rot = instance.CFrame - instance.CFrame.Position
            end

            return CFrame.new(pos) * rot
        end,

        extractChannel = function(value, channelName)
            if channelName == "X" then return value.Position.X
            elseif channelName == "Y" then return value.Position.Y
            elseif channelName == "Z" then return value.Position.Z
            elseif channelName == "RX" then
                local x, _, _ = value:ToEulerAnglesXYZ()
                return math.deg(x)
            elseif channelName == "RY" then
                local _, y, _ = value:ToEulerAnglesXYZ()
                return math.deg(y)
            elseif channelName == "RZ" then
                local _, _, z = value:ToEulerAnglesXYZ()
                return math.deg(z)
            end
            return 0
        end,

        interpolate = function(v0, v1, alpha)
            return v0:Lerp(v1, alpha)
        end
    },

    Vector3 = {
        channels = {"X", "Y", "Z"},

        decompose = function(value)
            return {X = value.X, Y = value.Y, Z = value.Z}
        end,

        recompose = function(channels, instance, propName)
            local current = instance[propName]
            return Vector3.new(
                channels.X or current.X,
                channels.Y or current.Y,
                channels.Z or current.Z
            )
        end,

        extractChannel = function(value, channelName)
            return value[channelName] or 0
        end,

        interpolate = function(v0, v1, alpha)
            return v0:Lerp(v1, alpha)
        end
    },

    Vector2 = {
        channels = {"X", "Y"},

        decompose = function(value)
            return {X = value.X, Y = value.Y}
        end,

        recompose = function(channels, instance, propName)
            local current = instance[propName]
            return Vector2.new(
                channels.X or current.X,
                channels.Y or current.Y
            )
        end,

        extractChannel = function(value, channelName)
            return value[channelName] or 0
        end,

        interpolate = function(v0, v1, alpha)
            return v0:Lerp(v1, alpha)
        end
    },

    UDim2 = {
        channels = {"XScale", "XOffset", "YScale", "YOffset"},

        decompose = function(value)
            return {
                XScale = value.X.Scale,
                XOffset = value.X.Offset,
                YScale = value.Y.Scale,
                YOffset = value.Y.Offset
            }
        end,

        recompose = function(channels, instance, propName)
            local current = instance[propName]
            return UDim2.new(
                channels.XScale or current.X.Scale,
                channels.XOffset or current.X.Offset,
                channels.YScale or current.Y.Scale,
                channels.YOffset or current.Y.Offset
            )
        end,

        extractChannel = function(value, channelName)
            if channelName == "XScale" then return value.X.Scale
            elseif channelName == "XOffset" then return value.X.Offset
            elseif channelName == "YScale" then return value.Y.Scale
            elseif channelName == "YOffset" then return value.Y.Offset
            end
            return 0
        end,

        interpolate = function(v0, v1, alpha)
            return v0:Lerp(v1, alpha)
        end
    },

    UDim = {
        channels = {"Scale", "Offset"},

        decompose = function(value)
            return {Scale = value.Scale, Offset = value.Offset}
        end,

        recompose = function(channels, instance, propName)
            local current = instance[propName]
            return UDim.new(
                channels.Scale or current.Scale,
                channels.Offset or current.Offset
            )
        end,

        extractChannel = function(value, channelName)
            return value[channelName] or 0
        end,

        interpolate = function(v0, v1, alpha)
            return UDim.new(
                v0.Scale + (v1.Scale - v0.Scale) * alpha,
                v0.Offset + (v1.Offset - v0.Offset) * alpha
            )
        end
    },

    Color3 = {
        channels = {"R", "G", "B"},

        decompose = function(value)
            return {R = value.R, G = value.G, B = value.B}
        end,

        recompose = function(channels, instance, propName)
            local current = instance[propName]
            return Color3.new(
                channels.R or current.R,
                channels.G or current.G,
                channels.B or current.B
            )
        end,

        extractChannel = function(value, channelName)
            return value[channelName] or 0
        end,

        interpolate = function(v0, v1, alpha)
            return v0:Lerp(v1, alpha)
        end
    },

    number = {
        channels = {"Value"},

        decompose = function(value)
            return {Value = value}
        end,

        recompose = function(channels)
            return channels.Value
        end,

        extractChannel = function(value)
            return value
        end,

        interpolate = function(v0, v1, alpha)
            return v0 + (v1 - v0) * alpha
        end
    },

    boolean = {
        channels = {"Value"},

        decompose = function(value)
            return {Value = value}
        end,

        recompose = function(channels)
            return channels.Value
        end,

        extractChannel = function(value)
            return value
        end,

        interpolate = function(v0, v1, alpha)
            return v0
        end
    },

    NumberRange = {
        channels = {"Min", "Max"},

        decompose = function(value)
            return {Min = value.Min, Max = value.Max}
        end,

        recompose = function(channels, instance, propName)
            local current = instance[propName]
            return NumberRange.new(
                channels.Min or current.Min,
                channels.Max or current.Max
            )
        end,

        extractChannel = function(value, channelName)
            return value[channelName] or 0
        end,

        interpolate = function(v0, v1, alpha)
            return NumberRange.new(
                v0.Min + (v1.Min - v0.Min) * alpha,
                v0.Max + (v1.Max - v0.Max) * alpha
            )
        end
    },

    NumberSequence = {
        channels = {"Value"},

        decompose = function(value)
            -- Store the entire NumberSequence as a serialized string
            local keypoints = {}
            for i, kp in ipairs(value.Keypoints) do
                table.insert(keypoints, {
                    Time = kp.Time,
                    Value = kp.Value,
                    Envelope = kp.Envelope
                })
            end
            return {Value = game:GetService("HttpService"):JSONEncode(keypoints)}
        end,

        recompose = function(channels)
            if type(channels.Value) == "string" then
                local success, keypoints = pcall(function()
                    return game:GetService("HttpService"):JSONDecode(channels.Value)
                end)

                if success and keypoints then
                    local sequenceKeypoints = {}
                    for _, kp in ipairs(keypoints) do
                        table.insert(sequenceKeypoints, 
                            NumberSequenceKeypoint.new(kp.Time, kp.Value, kp.Envelope)
                        )
                    end
                    return NumberSequence.new(sequenceKeypoints)
                end
            end
            return NumberSequence.new(0)
        end,

        extractChannel = function(value)
            -- For display, show the value at time 0
            if value.Keypoints and #value.Keypoints > 0 then
                return value.Keypoints[1].Value
            end
            return 0
        end,

        interpolate = function(v0, v1, alpha)
            -- Interpolate keypoints
            local kp0 = v0.Keypoints
            local kp1 = v1.Keypoints

            if #kp0 ~= #kp1 then
                return v0 -- Can't interpolate different lengths
            end

            local newKeypoints = {}
            for i = 1, #kp0 do
                local time = kp0[i].Time + (kp1[i].Time - kp0[i].Time) * alpha
                local value = kp0[i].Value + (kp1[i].Value - kp0[i].Value) * alpha
                local envelope = kp0[i].Envelope + (kp1[i].Envelope - kp0[i].Envelope) * alpha
                table.insert(newKeypoints, NumberSequenceKeypoint.new(time, value, envelope))
            end

            return NumberSequence.new(newKeypoints)
        end
    },

    ColorSequence = {
        channels = {"Value"},

        decompose = function(value)
            -- Store the entire ColorSequence as a serialized string
            local keypoints = {}
            for i, kp in ipairs(value.Keypoints) do
                table.insert(keypoints, {
                    Time = kp.Time,
                    R = kp.Value.R,
                    G = kp.Value.G,
                    B = kp.Value.B
                })
            end
            return {Value = game:GetService("HttpService"):JSONEncode(keypoints)}
        end,

        recompose = function(channels)
            if type(channels.Value) == "string" then
                local success, keypoints = pcall(function()
                    return game:GetService("HttpService"):JSONDecode(channels.Value)
                end)

                if success and keypoints then
                    local sequenceKeypoints = {}
                    for _, kp in ipairs(keypoints) do
                        table.insert(sequenceKeypoints, 
                            ColorSequenceKeypoint.new(kp.Time, Color3.new(kp.R, kp.G, kp.B))
                        )
                    end
                    return ColorSequence.new(sequenceKeypoints)
                end
            end
            return ColorSequence.new(Color3.new(1, 1, 1))
        end,

        extractChannel = function(value)
            -- For display, return a color representation
            if value.Keypoints and #value.Keypoints > 0 then
                return value.Keypoints[1].Value
            end
            return Color3.new(1, 1, 1)
        end,

        interpolate = function(v0, v1, alpha)
            -- Interpolate keypoints
            local kp0 = v0.Keypoints
            local kp1 = v1.Keypoints

            if #kp0 ~= #kp1 then
                return v0 -- Can't interpolate different lengths
            end

            local newKeypoints = {}
            for i = 1, #kp0 do
                local time = kp0[i].Time + (kp1[i].Time - kp0[i].Time) * alpha
                local color = kp0[i].Value:Lerp(kp1[i].Value, alpha)
                table.insert(newKeypoints, ColorSequenceKeypoint.new(time, color))
            end

            return ColorSequence.new(newKeypoints)
        end
    },

    Rect = {
        channels = {"MinX", "MinY", "MaxX", "MaxY"},

        decompose = function(value)
            return {
                MinX = value.Min.X,
                MinY = value.Min.Y,
                MaxX = value.Max.X,
                MaxY = value.Max.Y
            }
        end,

        recompose = function(channels, instance, propName)
            local current = instance[propName]
            return Rect.new(
                channels.MinX or current.Min.X,
                channels.MinY or current.Min.Y,
                channels.MaxX or current.Max.X,
                channels.MaxY or current.Max.Y
            )
        end,

        extractChannel = function(value, channelName)
            if channelName == "MinX" then return value.Min.X
            elseif channelName == "MinY" then return value.Min.Y
            elseif channelName == "MaxX" then return value.Max.X
            elseif channelName == "MaxY" then return value.Max.Y
            end
            return 0
        end,

        interpolate = function(v0, v1, alpha)
            return Rect.new(
                v0.Min.X + (v1.Min.X - v0.Min.X) * alpha,
                v0.Min.Y + (v1.Min.Y - v0.Min.Y) * alpha,
                v0.Max.X + (v1.Max.X - v0.Max.X) * alpha,
                v0.Max.Y + (v1.Max.Y - v0.Max.Y) * alpha
            )
        end
    },

    PhysicalProperties = {
        channels = {"Density", "Friction", "Elasticity", "FrictionWeight", "ElasticityWeight"},

        decompose = function(value)
            return {
                Density = value.Density,
                Friction = value.Friction,
                Elasticity = value.Elasticity,
                FrictionWeight = value.FrictionWeight,
                ElasticityWeight = value.ElasticityWeight
            }
        end,

        recompose = function(channels, instance, propName)
            local current = instance[propName] or PhysicalProperties.new(0.7, 0.3, 0.5)
            return PhysicalProperties.new(
                channels.Density or current.Density,
                channels.Friction or current.Friction,
                channels.Elasticity or current.Elasticity,
                channels.FrictionWeight or current.FrictionWeight,
                channels.ElasticityWeight or current.ElasticityWeight
            )
        end,

        extractChannel = function(value, channelName)
            return value[channelName] or 0
        end,

        interpolate = function(v0, v1, alpha)
            return PhysicalProperties.new(
                v0.Density + (v1.Density - v0.Density) * alpha,
                v0.Friction + (v1.Friction - v0.Friction) * alpha,
                v0.Elasticity + (v1.Elasticity - v0.Elasticity) * alpha,
                v0.FrictionWeight + (v1.FrictionWeight - v0.FrictionWeight) * alpha,
                v0.ElasticityWeight + (v1.ElasticityWeight - v0.ElasticityWeight) * alpha
            )
        end
    },

    BrickColor = {
        channels = {"Value"},

        decompose = function(value)
            return {Value = value.Number}
        end,

        recompose = function(channels)
            return BrickColor.new(channels.Value or 1)
        end,

        extractChannel = function(value)
            return value.Number
        end,

        interpolate = function(v0, v1, alpha)
            -- Step interpolation for BrickColor
            return v0
        end
    },

    EnumItem = {
        channels = {"Value"},

        decompose = function(value)
            return {Value = value.Value}
        end,

        recompose = function(channels, instance, propName)
            -- Get the enum type from the current value
            local current = instance[propName]
            local enumType = typeof(current) == "EnumItem" and current.EnumType or nil

            if enumType then
                for _, item in ipairs(enumType:GetEnumItems()) do
                    if item.Value == channels.Value then
                        return item
                    end
                end
            end

            return current
        end,

        extractChannel = function(value)
            return value.Value
        end,

        interpolate = function(v0, v1, alpha)
            -- Step interpolation for enums
            return v0
        end
    }
}

--------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------

-- Get the type definition for a Roblox type
function PropertyTypes.getType(valueType)
    return PropertyTypes.TypeDefinitions[valueType]
end

-- Decompose any value into channels
function PropertyTypes.decompose(value)
    local valueType = typeof(value)
    local typeDef = PropertyTypes.getType(valueType)

    if not typeDef then
        warn("PropertyTypes: Unknown type", valueType)
        return {Value = value}
    end

    return typeDef.decompose(value)
end

-- Recompose channels back into a value
function PropertyTypes.recompose(channels, valueType, instance, propName)
    local typeDef = PropertyTypes.getType(valueType)

    if not typeDef then
        warn("PropertyTypes: Unknown type", valueType)
        return channels.Value
    end

    return typeDef.recompose(channels, instance, propName)
end

-- Extract a specific channel from a value
function PropertyTypes.extractChannel(value, channelName)
    local valueType = typeof(value)
    local typeDef = PropertyTypes.getType(valueType)

    if not typeDef then
        return type(value) == "number" and value or 0
    end

    return typeDef.extractChannel(value, channelName)
end

-- Get channel names for a type
function PropertyTypes.getChannels(valueType)
    local typeDef = PropertyTypes.getType(valueType)
    return typeDef and typeDef.channels or {"Value"}
end

-- Interpolate between two values
function PropertyTypes.interpolate(v0, v1, alpha)
    local valueType = typeof(v0)
    local typeDef = PropertyTypes.getType(valueType)

    if not typeDef then
        return v0
    end

    return typeDef.interpolate(v0, v1, alpha)
end

-- Check if a type is supported
function PropertyTypes.isSupported(valueType)
    return PropertyTypes.TypeDefinitions[valueType] ~= nil
end

return PropertyTypes