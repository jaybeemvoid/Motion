local CinematicController = {}
CinematicController.__index = CinematicController

local RunService = game:GetService("RunService")
local Runtime = require(script.Runtime)

local function createSignal()
    local bindable = Instance.new("BindableEvent")
    return {
        Fire = function(...) bindable:Fire(...) end,
        Connect = function(self, fn) return bindable.Event:Connect(fn) end,
        Wait = function() return bindable.Event:Wait() end,
        Destroy = function() bindable:Destroy() end,
    }
end

function CinematicController.new(manifest)
    local self = setmetatable({}, CinematicController)

    self.Data = typeof(manifest) == "Instance" and require(manifest) or manifest
    self.Time = 0
    self.Speed = 1
    self.IsPlaying = false

    self.Completed = createSignal()
    self.Stopped = createSignal()

    self._connection = nil

    return self
end

function CinematicController:Play()
    if self.IsPlaying then return end
    self.IsPlaying = true

    self._connection = RunService.RenderStepped:Connect(function(dt)
        self.Time = self.Time + (dt * self.Speed)

        if self.Time >= self.Data.Metadata.Duration then
            self:Stop()
            self.Completed:Fire()
            return
        end

        Runtime.update(self.Data, self.Time)
    end)
end

function CinematicController:Pause()
    self.IsPlaying = false
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
end

function CinematicController:Stop()
    self:Pause()
    self.Time = 0

    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Custom

    self.Stopped:Fire()
end

function CinematicController:Seek(seconds)
    self.Time = math.clamp(seconds, 0, self.Data.Metadata.Duration)
    Runtime.update(self.Data, self.Time)
end

function CinematicController:Destroy()
    self:Stop()
    self.Completed:Destroy()
    self.Stopped:Destroy()
end

return CinematicController