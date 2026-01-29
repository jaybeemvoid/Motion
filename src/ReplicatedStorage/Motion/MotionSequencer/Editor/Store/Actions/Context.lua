local contextMenu = {}
contextMenu.__index = contextMenu

function contextMenu.new(context)
    local self = setmetatable({}, contextMenu)

    self.context = context

    return self
end

function contextMenu:trigger(position, context)
    local state = self.context.state

    self.context:setState({
        ui = {
            expandedTracks = state.ui.expandedTracks,
            openMenus = {
                {
                    items = nil,
                    pos = UDim2.fromOffset(position.X, position.Y),
                    context = context
                }
            },
            mousePos = state.ui.mousePos,
            canScroll = state.ui.canScroll,
            isInputHandledByUI = state.ui.isInputHandledByUI,
            isPanelOpen = true,
            propertyPickerTrackId = state.ui.propertyPickerTrackId,
            cameraPreviewActive = state.ui.cameraPreviewActive,
            viewSettings = state.ui.viewSettings,
        }
    })
end

return contextMenu