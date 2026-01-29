local maid = require(script.Parent.Parent.Parent.Util.Maid)

local keyboard = {}
keyboard.__index = keyboard

function keyboard.new(context, bind)
    local self = setmetatable({}, keyboard)
    
    self.context = context
    self.bind = bind
    
    self._conn = nil
    
    self.maid = maid.new()
    return self
end

function keyboard:connect()
    if self.bind then
        if self._conn then
            self._conn:Disconnect()
            self._conn = nil
        end
        
        self._conn = self.bind.Event:Connect(function(action)
            local state = self.context.state -- Get current state snapshot

            if action == "Play_Sequence" then
                print(":Hehetwey")
                -- 1. Calculate new values based on current state
                local nowPlaying = not state.playback.isPlaying
                local direction = state.playback.playDirection

                if nowPlaying then
                    if state.playback.currentTime <= 0 then
                        direction = 1
                    elseif state.playback.currentTime >= state.project.duration then
                        direction = -1
                    end
                end

                -- 2. Use your utils to update the specific categories
                -- Note: we pass a table of changes so your utils:onStateChange can merge them
                self.context.Actions.utils:setState("playback", {
                    isPlaying = nowPlaying,
                    playDirection = direction
                })

                self.context.Actions.utils:setState("ui", {
                    cameraPreviewActive = nowPlaying -- Usually syncs with play state
                })

            elseif action == "Delete_Keyframe" then
                self.context.Actions.utils:deleteSelected()

            elseif action == "To_Start" then
                -- Correct the path to 'playback'
                self.context.Actions.utils:setState("playback", {
                    currentTime = 0,
                    isPlaying = false,
                })

            elseif action == "Undo" then
                self.context.Actions.history:undo()

            elseif action == "Redo" then
                self.context.Actions.history:redo()
            end
        end)
    end
end

function keyboard:destroy()
    self.maid:DoCleaning()
end

return keyboard
