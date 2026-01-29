local selection = game:GetService("Selection")

local Engine = require(script.Parent.Parent.Parent.Parent.Core.Sequencer.Previewer)

local closeTimer = nil

local utils = {}
utils.__index = utils

function utils.new(context)
    local self = setmetatable({}, utils)
    self.context = context
    return self
end

function utils:setState(category, patch)
    local currentState = self.context.state
    local categoryData = currentState[category]

    if typeof(patch) == "table" and typeof(categoryData) == "table" then
        local nextValue = table.clone(categoryData)
        for k, v in pairs(patch) do
            nextValue[k] = v
        end
        self.context:setState({ [category] = nextValue })
    else
        self.context:setState({ [category] = patch })
    end
end

function utils:getState()
    return self.context.state
end

function utils:zoom(wheelDelta, mouseX)
    local ZOOM_SPEED = 1.15
    local state = self.context.state

    local currentPPS = state.viewport.verticalPixelsPerSecond
    local currentScrollX = state.viewport.positionX
    local duration = state.project.duration

    local newPPS = wheelDelta > 0 and currentPPS * ZOOM_SPEED or currentPPS / ZOOM_SPEED
    newPPS = math.clamp(newPPS, 10, 2000)

    local viewportWidth = 300 
    local oldTotalWidth = duration * currentPPS
    local oldMaxScroll = math.max(0, oldTotalWidth - viewportWidth)
    local oldScrollOffset = currentScrollX * oldMaxScroll

    local timeAtMouse = (mouseX + oldScrollOffset) / currentPPS

    local newTotalWidth = duration * newPPS
    local newMaxScroll = math.max(0, newTotalWidth - viewportWidth)
    local newScrollOffset = (timeAtMouse * newPPS) - mouseX

    local newPercentX = 0
    if newMaxScroll > 0 then
        newPercentX = math.clamp(newScrollOffset / newMaxScroll, 0, 1)
    end

    local newViewport = table.clone(state.viewport)
    newViewport.verticalPixelsPerSecond = newPPS
    newViewport.positionX = newPercentX

    self.context:setState({
        viewport = newViewport
    })
end

function utils:deleteSelected()
    local selectionState = self.context.state.selection

    if selectionState.keyframes and next(selectionState.keyframes) then
        self.context.Actions.keyframe:deleteSelectedKeyFrame() 
    end

    if selectionState.clips and next(selectionState.clips) then
        self.context.Actions.director:deleteSelectedClips()
    end
    
    Engine.update(self.context.state.tracks, self.context.state.playback.currentTime, self.context.state.ui.cameraPreviewActive, self.context.locks)
end

function utils:graphZoom(wheelDelta, mouseX)
    local ZOOM_SPEED = 1.1
    local viewport = self.context.state.viewport
    local newZoomY = wheelDelta > 0 and viewport.zoomY * ZOOM_SPEED or viewport.zoomY / ZOOM_SPEED

    local newViewport = table.clone(viewport)
    newViewport.zoomY = math.clamp(newZoomY, 0.01, 50)

    return self.context:setState({
        viewport = newViewport
    })
end

function utils:onHoverSubMenu(level, itemConfig, itemOffset)
    if closeTimer then
        task.cancel(closeTimer)
        closeTimer = nil
    end

    self.context:setState(function(prevState)
        local ui = table.clone(prevState.ui)
        local newMenus = table.clone(ui.openMenus)

        if typeof(itemConfig) == "table" and itemConfig.Children then
            local parentMenu = newMenus[level]
            if not parentMenu then return nil end

            local parentX = parentMenu.pos.X.Offset
            local parentY = parentMenu.pos.Y.Offset

            newMenus[level + 1] = {
                items = itemConfig.Children,
                pos = UDim2.fromOffset(parentX + itemOffset.X, parentY + itemOffset.Y)
            }

            ui.openMenus = newMenus
            return { ui = ui }
        else
            if #newMenus > level then
                closeTimer = task.delay(0.25, function()
                    self.context:setState(function(latestState)
                        local latestUI = table.clone(latestState.ui)
                        local finalMenus = table.clone(latestUI.openMenus)

                        for i = #finalMenus, level + 1, -1 do
                            table.remove(finalMenus, i)
                        end

                        latestUI.openMenus = finalMenus
                        return { ui = latestUI }
                    end)
                    closeTimer = nil
                end)
            end
            return nil 
        end
    end)
end

function utils:addSelected()
    local selectedObjects = selection:Get()

    if #selectedObjects > 0 then
        local target = selectedObjects[1]
        self.context.createTrack(
            target.Name,
            target,
            {
                {name = "CFrame", keyframes = {} },
                {name = "Transparency", keyframes = {} },
                {name = "Size", keyframes = {} },
            }
        )
    else
        warn("Please select an object in the Explorer first.")
    end
end

function utils:openPropertyPicker(trackId, position)
    -- Updated to store inside the 'ui' table
    local ui = table.clone(self.context.state.ui)
    ui.propertyPickerTrackId = trackId
    -- Note: Added propertyPickerPosition to ui structure based on your function call
    ui.propertyPickerPosition = position 

    self.context:setState({
        ui = ui
    })
end

return utils