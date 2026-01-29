local Roact = require(script.Parent.Parent.Parent.Roact)
local Timeline = Roact.Component:extend("Timeline")

local GridLayer = require(script.GridLayer)
local ScrollbarsHolder = require(script.ScrollbarsHolder)
local PropertyPickerOverlay = require(script.Parent.Parent.Components.Widgets.PropertyPicker)

local DynamicProperties = require(script.Parent.Parent.Store.DynamicProperties)

function Timeline:render()
    return Roact.createElement("Frame", {
        Style = {
            s = UDim2.new(1, 0, 1, -32),
            ps = UDim2.new(0, 0, 0, 32),
            bg = "primary",
        },
        [Roact.Event.InputBegan] = function(rbx, event)
            if event.UserInputType == Enum.UserInputType.MouseButton1 then
                self.props.Plugin:Activate(true)
            end
        end,
    }, {
        Grid = Roact.createElement(GridLayer, {
            tracks = self.props.tracks,
            totalSeconds = self.props.totalSeconds,
            pixelsPerSecond = self.props.pixelsPerSecond,
            positionX = self.props.positionX,
            scrollPercentX = self.props.scrollPercentX,
            positionY = self.props.positionY,
            offsetY = self.props.offsetY,
            onStateChange = self.props.onStateChange,
            currentTime = self.props.currentTime,
            toggleTrackExpansion = self.props.toggleTrackExpansion,
            canScroll = self.props.canScroll,
            fps = self.props.fps,
            
            director = self.props.director,
            selectClip = self.props.selectClip,
            
            onDirectorKeyframeUpdate = self.props.onDirectorKeyframeUpdate,
            toggleDirectorProperty = self.props.toggleDirectorProperty,
            toggleDirectorExpansion  = self.props.toggleDirectorExpansion,
            
            selection = self.props.selection,
            onKeyFrameSelection = self.props.onKeyFrameSelection,
            createKeyFrame = self.props.createKeyFrame,
            onKeyframeMove = self.props.onKeyframeMove,
            
            isInputHandledByUI = self.props.isInputHandledByUI,
            trackOrder = self.props.trackOrder,
            --addSelectedInstance = self.props.addSelectedInstance,
            isPanelOpen = self.props.isPanelOpen,
            
            triggerContext = self.props.triggerContext,
            mousePos = self.props.mousePos,
            
            onAction = self.props.onAction,
            
            findKeyframeById = self.props.findKeyframeById,
            
            onHoverSubMenu = self.props.onHoverSubMenu,
            openMenus = self.props.openMenus,
            
            onAddClip = self.props.onAddClip,
            cameraPreviewActive = self.props.cameraPreviewActive,
            toggleCameraPreview = self.props.toggleCameraPreview,

            onClipMove = self.props.onClipMove,

            onClipResize = self.props.onClipResize,
            
            clipSelection = self.props.clipSelection,
            
            locks = self.props.locks,
            onPropertyUiChange = self.props.onPropertyUiChange,
            vps = self.props.vps,
            
            onZoom = self.props.onZoom,
            
            openPropertyPicker = self.props.openPropertyPicker,
            
            playbackController = self.props.playbackController,
            
            Recomposition = self.props.Recomposition,
            
            smartAdd = self.props.smartAdd,
            getLinearRegistry = self.props.getLinearRegistry,
            
            mode = self.props.mode,
            
            panX = self.props.panX,
            panY = self.props.panY,
            onKeyframeUpdate = self.props.onKeyframeUpdate,
            onHandleUpdate = self.props.onHandleUpdate,
            onGraphZoom = self.props.onGraphZoom,
            zoomY = self.props.zoomY,
            onKeyframeUpdateFromGraph = self.props.onKeyframeUpdateFromGraph,
            
            --getExpandedTracksForGraph = self.props.getExpandedTracksForGraph,
        }),
        ScrollbarsHolder = Roact.createElement(ScrollbarsHolder, {
            positionX = self.props.positionX,
            positionY = self.props.positionY,
            scrollPercentX = self.props.scrollPercentX,
            canScroll = self.props.canScroll,
            offsetY = self.props.offsetY,
            onStateChange = self.props.onStateChange,
        }),

    })
end

return Timeline

--[[

        PropertyPicker = Roact.createElement(PropertyPickerOverlay, {
            trackId = self.props.propertyPickerTrackId,
            tracks = self.props.tracks,

            onPropertySelected = function(propertyName)
                local trackId = self.props.propertyPickerTrackId
                local track = self.props.tracks[trackId]

                if track and track.instance then
                    local updatedTrack = DynamicProperties.addPropertyToTrack(
                        track, 
                        propertyName, 
                        track.instance
                    )

                    if updatedTrack ~= track then
                        self.props.context:setState(function(prevState)
                            local nextTracks = table.clone(prevState.tracks)
                            nextTracks[trackId] = updatedTrack
                            return { tracks = nextTracks }
                        end)
                    end
                end

                self.props.context:setState({
                    propertyPickerTrackId = nil,
                })
            end,

            onClose = function()
                self.props.context:setState({
                    propertyPickerTrackId = nil,
                })
            end
        })

]]