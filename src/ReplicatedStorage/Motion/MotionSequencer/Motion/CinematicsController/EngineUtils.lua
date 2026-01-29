local EU = {}
local TweenService = game:GetService("TweenService")
local RBezier = require(script.Parent.Math.RBezier)
local RQuat = require(script.Parent.Math.RQuat)
local PropertyTypes = require(script.Parent.PropertyRegistery)

local VALID_STYLES = {}
for _, enum in ipairs(Enum.EasingStyle:GetEnumItems()) do 
    VALID_STYLES[enum.Name] = true 
end

local VALID_DIRS = {}
for _, enum in ipairs(Enum.EasingDirection:GetEnumItems()) do 
    VALID_DIRS[enum.Name] = true 
end

--------------------------------------------------------------------
-- CORE INTERPOLATION
--------------------------------------------------------------------

function EU.safeTween(alpha, style, direction)
    if style == "Linear" or not VALID_STYLES[style] or not VALID_DIRS[direction] then
        return alpha
    end
    return TweenService:GetValue(alpha, Enum.EasingStyle[style], Enum.EasingDirection[direction])
end

function EU.findKeyframeRange(keyframes, playheadTime)
    local count = #keyframes
    if count == 0 then return nil, nil end
    if count == 1 then return keyframes[1], nil end

    local low, high = 1, count
    while low <= high do
        local mid = math.floor((low + high) / 2)
        local kf = keyframes[mid]
        local kfTime = kf.t or kf.time

        if kfTime <= playheadTime then
            local nextKf = keyframes[mid + 1]
            local nextTime = nextKf and (nextKf.t or nextKf.time)
            if mid == count or nextTime > playheadTime then
                return kf, keyframes[mid + 1]
            else 
                low = mid + 1 
            end
        else 
            high = mid - 1 
        end
    end

    return nil, nil
end

function EU.getChannelValue(keyframes, currentTime)
    if not keyframes or #keyframes == 0 then return nil end

    local kf0, kf1 = EU.findKeyframeRange(keyframes, currentTime)

    if not kf0 then 
        return keyframes[1].v or keyframes[1].value 
    end

    if not kf1 then 
        return kf0.v or kf0.value 
    end

    local t0, t1 = kf0.t or kf0.time, kf1.t or kf1.time
    local v0, v1 = kf0.v or kf0.value, kf1.v or kf1.value
    local duration = t1 - t0

    if duration <= 0 then return v1 end

    local alpha = (currentTime - t0) / duration
    local easing = kf0.e or kf0.interpolation or "Linear"
    local direction = kf0.d or kf0.interpolationDirection or "In"

    if type(v0) == "number" and easing == "Bezier" and RBezier then
        local hr = kf0.handleRight or {
            x = kf0.hrx or 0.3, 
            y = kf0.hry or 0
        }

        local hl = kf1.handleLeft or {
            x = kf1.hlx or 0.3, 
            y = kf1.hly or 0
        }

        local wrap0 = { 
            time = t0, 
            value = v0, 
            handleRight = hr 
        }

        local wrap1 = { 
            time = t1, 
            value = v1, 
            handleLeft = hl 
        }

        return RBezier.evaluate(alpha, wrap0, wrap1)
    end

    if type(v0) == "number" then
        local easedAlpha = EU.safeTween(alpha, easing, direction)
        return v0 + (v1 - v0) * easedAlpha
    elseif type(v0) == "boolean" then
        return v0
    end

    return v0
end

function EU.applyProperty(instance : Instance, propName, channels, propType)
    if not instance or not propName then return end

    if propType == "CFrame" then
        local pos
        local rot

        if instance:IsA("Motor6D") and propName == "C0" then
            local currentC0 = instance.C0

            if channels.X or channels.Y or channels.Z then
                pos = Vector3.new(
                    channels.X or currentC0.Position.X,
                    channels.Y or currentC0.Position.Y,
                    channels.Z or currentC0.Position.Z
                )
            else
                pos = currentC0.Position
            end

            if channels.RX or channels.RY or channels.RZ then
                rot = EU.getRotationCFrame(channels)
            else
                rot = currentC0 - currentC0.Position
            end

            instance.C0 = CFrame.new(pos) * rot

        else
            pos = Vector3.new(
                channels.X or instance.CFrame.Position.X,
                channels.Y or instance.CFrame.Position.Y,
                channels.Z or instance.CFrame.Position.Z
            )

            if channels.RX or channels.RY or channels.RZ then
                rot = EU.getRotationCFrame(channels)
            else
                rot = instance.CFrame - instance.CFrame.Position
            end

            instance.CFrame = CFrame.new(pos) * rot
        end

        return
    end

    local typeDef = PropertyTypes.getType(propType)
    if typeDef then
        local newValue = typeDef.recompose(channels, instance, propName)
        if newValue ~= nil then
            instance[propName] = newValue
        end
    else
        local val = channels.Value
        if val ~= nil then
            instance[propName] = val
        end
    end
end

function EU.buildCFrame(values)
    local px = values.X or 0
    local py = values.Y or 0
    local pz = values.Z or 0

    local rx = values.RX or 0
    local ry = values.RY or 0
    local rz = values.RZ or 0

    local position = Vector3.new(px, py, pz)

    local rotation = CFrame.Angles(
        math.rad(rx),
        math.rad(ry),
        math.rad(rz)
    )

    return CFrame.new(position) * rotation
end

function EU.getRotationCFrame(values)
    return RQuat.fromEuler(
        math.rad(values.RX or 0),
        math.rad(values.RY or 0),
        math.rad(values.RZ or 0)
    ):toCFrame()
end

function EU.applyHandheld(baseCFrame, intensity, speed, time)
    local x = math.noise(time * speed, 0, 0) * intensity
    local y = math.noise(0, time * speed, 0) * intensity
    local z = math.noise(0, 0, time * speed) * intensity 
    return baseCFrame * CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

return EU