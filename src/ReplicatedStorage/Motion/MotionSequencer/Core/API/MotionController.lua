--@MotionController
--The public API
--Is a layer to communicate with the runtime engine

--Methods starting with "_" are private and shouldn't be called externally

--[[
    Usage:
]]
local MotionController = {}
MotionController.__index = MotionController

local RunService = game:GetService("RunService")
local Runtime = require(script.Parent.Parent.Sequencer.Runtime)

type manifest = {

}

--[Signal Class]
--Simple signal implementation using BindableEvents
--Might get a rewrite for more performance
local function createSignal()
    local bindable = Instance.new("BindableEvent")
    return {
        Fire = function(...) bindable:Fire(...) end,
        Connect = function(self, fn) return bindable.Event:Connect(fn) end,
        Wait = function() return bindable.Event:Wait() end,
        Destroy = function() bindable:Destroy() end,
    }
end

--Creates a new controller for an animation file
function MotionController.new(manifest : manifest) : typeof(setmetatable({}, MotionController))
    local self = setmetatable({} :: {}, MotionController :: {}) :: {}

    self.Data = typeof(manifest) == "Instance" and require(manifest) or manifest
    self.Time = 0
    self.Speed = 1
    self.IsPlaying = false

    self.Completed = createSignal()
    self.Stopped = createSignal()

    self._connection = nil

    return (self :: typeof(setmetatable({}, MotionController))) :: any?
end

--Plays an animation
function MotionController:Play() : ()
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
--Pauses an on-going animation
function MotionController:Pause()
    self.IsPlaying = false
    if self._connection then
        self._connection:Disconnect()
        self._connection = nil
    end
end
--Stops an on-going animation
function MotionController:Stop()
    self:Pause()
    self.Time = 0

    local camera = workspace.CurrentCamera
    camera.CameraType = Enum.CameraType.Custom

    self.Stopped:Fire()
end
--Render a specific timestamp on an animation
function MotionController:Seek(seconds)
    self.Time = math.clamp(seconds, 0, self.Data.Metadata.Duration)
    Runtime.update(self.Data, self.Time)
end
--_private method
function MotionController:_destroy()
    self:Stop()
    self.Completed:Destroy()
    self.Stopped:Destroy()
end

return MotionController