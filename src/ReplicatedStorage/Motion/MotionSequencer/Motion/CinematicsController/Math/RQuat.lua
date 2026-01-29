--[[
    Usage:
        local Quat = require(path.to.Quaternion)
        local q1 = Quat.fromCFrame(someCFrame)
        local q2 = Quat.fromCFrame(anotherCFrame)
        local interpolated = q1:slerp(q2, 0.5)
        local result = interpolated:toCFrame(position)
]]

local RQuat = {}
RQuat.__index = RQuat

function RQuat.new(x, y, z, w)
    return setmetatable({
        x = x or 0,
        y = y or 0, 
        z = z or 0,
        w = w or 1
    }, RQuat)
end

function RQuat.fromCFrame(cf)
    local _, _, _, m00, m01, m02, m10, m11, m12, m20, m21, m22 = cf:GetComponents()

    local trace = m00 + m11 + m22
    local x, y, z, w

    if trace > 0 then
        local s = math.sqrt(trace + 1) * 2
        w = 0.25 * s
        x = (m21 - m12) / s
        y = (m02 - m20) / s
        z = (m10 - m01) / s
    elseif m00 > m11 and m00 > m22 then
        local s = math.sqrt(1 + m00 - m11 - m22) * 2
        w = (m21 - m12) / s
        x = 0.25 * s
        y = (m01 + m10) / s
        z = (m02 + m20) / s
    elseif m11 > m22 then
        local s = math.sqrt(1 + m11 - m00 - m22) * 2
        w = (m02 - m20) / s
        x = (m01 + m10) / s
        y = 0.25 * s
        z = (m12 + m21) / s
    else
        local s = math.sqrt(1 + m22 - m00 - m11) * 2
        w = (m10 - m01) / s
        x = (m02 + m20) / s
        y = (m12 + m21) / s
        z = 0.25 * s
    end

    return RQuat.new(x, y, z, w)
end

function RQuat.fromAxisAngle(axis, angle)
    local s = math.sin(angle / 2)
    return RQuat.new(
        axis.X * s,
        axis.Y * s,
        axis.Z * s,
        math.cos(angle / 2)
    ):normalize()
end

function RQuat.fromEuler(x, y, z)
    local qx = RQuat.fromAxisAngle(Vector3.new(1, 0, 0), x)
    local qy = RQuat.fromAxisAngle(Vector3.new(0, 1, 0), y)
    local qz = RQuat.fromAxisAngle(Vector3.new(0, 0, 1), z)

    return qy * qx * qz 
end

function RQuat.__mul(a, b)
    return RQuat.new(
        a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
        a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
        a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
        a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z
    )
end

function RQuat:toCFrame(position)
    position = position or Vector3.new(0, 0, 0)

    local x, y, z, w = self.x, self.y, self.z, self.w

    local xx = x * x
    local yy = y * y
    local zz = z * z
    local xy = x * y
    local xz = x * z
    local yz = y * z
    local wx = w * x
    local wy = w * y
    local wz = w * z

    return CFrame.new(
        position.x, position.y, position.z,
        1 - 2 * (yy + zz), 2 * (xy - wz), 2 * (xz + wy),
        2 * (xy + wz), 1 - 2 * (xx + zz), 2 * (yz - wx),
        2 * (xz - wy), 2 * (yz + wx), 1 - 2 * (xx + yy)
    )
end

function RQuat:slerp(other, alpha)
    local x1, y1, z1, w1 = self.x, self.y, self.z, self.w
    local x2, y2, z2, w2 = other.x, other.y, other.z, other.w

    local dot = x1 * x2 + y1 * y2 + z1 * z2 + w1 * w2

    if dot < 0 then
        x2, y2, z2, w2 = -x2, -y2, -z2, -w2
        dot = -dot
    end

    if dot > 0.9995 then
        return RQuat.new(
            x1 + alpha * (x2 - x1),
            y1 + alpha * (y2 - y1),
            z1 + alpha * (z2 - z1),
            w1 + alpha * (w2 - w1)
        ):normalize()
    end

    local theta = math.acos(dot)
    local sinTheta = math.sin(theta)
    local a = math.sin((1 - alpha) * theta) / sinTheta
    local b = math.sin(alpha * theta) / sinTheta

    return RQuat.new(
        a * x1 + b * x2,
        a * y1 + b * y2,
        a * z1 + b * z2,
        a * w1 + b * w2
    )
end

function RQuat:normalize()
    local len = math.sqrt(self.x^2 + self.y^2 + self.z^2 + self.w^2)
    if len > 0 then
        return RQuat.new(
            self.x / len,
            self.y / len,
            self.z / len,
            self.w / len
        )
    end
    return RQuat.new(0, 0, 0, 1)
end

function RQuat:distanceTo(other)
    local dot = math.abs(self.x * other.x + self.y * other.y + self.z * other.z + self.w * other.w)
    dot = math.min(1, dot)
    return math.deg(2 * math.acos(dot))
end

function RQuat:isClose(other, threshold)
    threshold = threshold or 0.1
    return self:distanceTo(other) < threshold
end

function RQuat:toEulerAngles()
    local x, y, z, w = self.x, self.y, self.z, self.w

    local sinr_cosp = 2 * (w * x + y * z)
    local cosr_cosp = 1 - 2 * (x * x + y * y)
    local roll = math.atan2(sinr_cosp, cosr_cosp)

    local sinp = 2 * (w * y - z * x)
    local pitch
    if math.abs(sinp) >= 1 then
        pitch = math.pi / 2 * (sinp >= 0 and 1 or -1)
    else
        pitch = math.asin(sinp)
    end

    local siny_cosp = 2 * (w * z + x * y)
    local cosy_cosp = 1 - 2 * (y * y + z * z)
    local yaw = math.atan2(siny_cosp, cosy_cosp)

    return roll, pitch, yaw
end

function RQuat:serialize()
    return {
        x = self.x,
        y = self.y,
        z = self.z,
        w = self.w
    }
end

function RQuat.deserialize(data)
    return RQuat.new(data.x, data.y, data.z, data.w)
end

return RQuat