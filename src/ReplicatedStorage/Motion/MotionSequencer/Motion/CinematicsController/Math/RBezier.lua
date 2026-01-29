local RBezier = {}

local function cubicBezier(t, p0, p1, p2, p3)
    local mt = 1 - t
    return mt * mt * mt * p0 + 3 * mt * mt * t * p1 + 3 * mt * t * t * p2 + t * t * t * p3
end

local function cubicBezierDerivative(t, p0, p1, p2, p3)
    local mt = 1 - t
    return 3 * mt * mt * (p1 - p0) + 6 * mt * t * (p2 - p1) + 3 * t * t * (p3 - p2)
end

-- Time Solver (X-Axis)
local function solveBezierX(targetX, p1x, p2x)
    local t = targetX
    for i = 1, 20 do
        local currentX = cubicBezier(t, 0, p1x, p2x, 1)
        local diff = currentX - targetX
        if math.abs(diff) < 0.000001 then return t end
        local derivative = cubicBezierDerivative(t, 0, p1x, p2x, 1)
        if math.abs(derivative) < 0.0000001 then break end
        t = math.clamp(t - diff / derivative, 0, 1)
    end
    return t
end

function RBezier.evaluate(timeAlpha, kf0, kf1, returnVector)
    local DEFAULT_HANDLE_TIME = 0.3
    local timeDelta = kf1.time - kf0.time
    local val0 = kf0.value
    local val1 = kf1.value
    if type(val0) ~= "number" or type(val1) ~= "number" then
        if returnVector then
            return Vector2.new(kf0.time, val0 and 1 or 0)
        else
            return val0
        end
    end

    if timeDelta <= 0 then 
        return returnVector and Vector2.new(kf0.time, val0) or val0
    end

    local h0x = kf0.handleRight and kf0.handleRight.x or DEFAULT_HANDLE_TIME
    local h0y = kf0.handleRight and kf0.handleRight.y or 0
    local h1x = kf1.handleLeft and kf1.handleLeft.x or DEFAULT_HANDLE_TIME
    local h1y = kf1.handleLeft and kf1.handleLeft.y or 0

    -------------------------------------------------------
    -- X-AXIS (TIME) CALCULATION
    -------------------------------------------------------
    local p1x = math.clamp(h0x / timeDelta, 0, 1)
    local p2x = math.clamp(1 - (h1x / timeDelta), 0, 1)

    local t = solveBezierX(timeAlpha, p1x, p2x)

    -------------------------------------------------------
    -- Y-AXIS (VALUE) CALCULATION
    -------------------------------------------------------
    local p0y = val0
    local p1y = val0 + h0y
    local p2y = val1 + h1y
    local p3y = val1

    local realValue = cubicBezier(t, p0y, p1y, p2y, p3y)

    -------------------------------------------------------
    -- RETURN
    -------------------------------------------------------
    if returnVector then
        local realTime = kf0.time + (timeAlpha * timeDelta)
        return Vector2.new(realTime, realValue)
    else
        return realValue
    end
end

return RBezier