local RunService = game:GetService("RunService")
local Previewer = require(script.Parent.Parent.Parent.Core.Sequencer.Previewer)
local maid = require(script.Parent.Parent.Parent.Util.Maid)

local PlaybackController = {}
PlaybackController.__index = PlaybackController

function PlaybackController.new(context)
    local self = setmetatable({}, PlaybackController)
    self.context = context
    self._conn = nil
    self.masterTime = 0
    self.maid = maid.new()
    return self
end

function PlaybackController:start()
    if self._conn then return end

    local currentState = self.context.state
    self.masterTime = (currentState and currentState.playback.currentTime) or self.masterTime or 0

    self._conn = RunService.RenderStepped:Connect(function(dt)
        if not self.context then 
            warn("PlaybackController: context is nil, stopping playback")
            return 
        end

        local state = self.context.state

        if not state or not state.playback.isPlaying then return end

        if not self.masterTime then 
            self.masterTime = state.playback.currentTime or 0 
        end

        self.masterTime = self.masterTime + (dt * (state.playback.playDirection or 1))

        if self.masterTime < 0 then 
            self.masterTime = 0
            self.context.Actions.utils:setState("playback", { isPlaying = false })
            return
        end

        if self.masterTime > state.project.duration then 
            self.masterTime = state.project.duration 
            self.context.Actions.utils:setState("playback", { isPlaying = false })
            return
        end

        if not state or not state.playback.isPlaying then 
            return 
        end

        if self.context.locks then 
            self.context.locks.isInternalUpdate = true 
        end

        Previewer.update(
            state.tracks, 
            self.masterTime, 
            self.context.state.ui.cameraPreviewActive, 
            self.context.locks
        )

        self.throttleCounter = (self.throttleCounter or 0) + 1
        if self.throttleCounter >= 2 then 
            self.context.Actions.utils:setState("playback", { currentTime = self.masterTime })
            self.throttleCounter = 0
        end

        if self.context.locks then 
            self.context.locks.isInternalUpdate = false 
        end
    end)
end

function PlaybackController:stop()
    if self._conn then
        self._conn:Disconnect()
        self._conn = nil
    end
end

function PlaybackController:setTime(t)
    self.masterTime = t

    if self.context and self.context.state then
        local state = self.context.state

        Previewer.update(
            state.tracks, 
            t, 
            state.ui.cameraPreviewActive, 
            self.context.locks
        )
    end
end

function PlaybackController:destroy()
    self.maid:DoCleaning()
    self:stop()
    self.context = nil
end

return PlaybackController