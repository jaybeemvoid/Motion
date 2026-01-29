local UserInputService = game:GetService("UserInputService")
local Roact = require(script.Parent.Parent.Parent.Parent.Roact)

local GridLayer = Roact.Component:extend("GridLayer")

local VerticalLines = require(script.VerticalLines)

local PlayHeadComponent = require(script.Parent.Parent.Parent.Components.Timeline.PlayHead)
local RowTrack = require(script.Parent.Parent.Parent.Components.Timeline.RowTrack)
local LaneComponent = require(script.Parent.Parent.Parent.Components.Timeline.Lane)
local RulerComponent = require(script.Parent.Ruler)
local GraphCanvas = require(script.Parent.Parent.Parent.Components.GraphEditor.GraphCanvas)

local Images = require(script.Parent.Parent.Parent.Assets.UI.Images)

local Panel = require(script.Parent.Parent.Panels.Interpolation)
local ContextMenu = require(script.Parent.Parent.Parent.Components.ContextMenu.ContextMenu)

local Theme = require(script.Parent.Parent.Parent.Themes.Theme)

local function getTrackDepth(trackId, tracks)
    local depth = 0
    local current = tracks[trackId]
    while current and current.parentId do
        depth = depth + 1
        current = tracks[current.parentId]
    end
    return depth
end

local function isTrackVisible(trackId, tracks)
    local current = tracks[trackId]
    if not current then return false end

    -- FIX: If it's a top-level track (no parent), it MUST be visible
    if not current.parentId or current.parentId == "" then 
        return true 
    end

    -- If it has a parent, check if the parent is open
    local parent = tracks[current.parentId]
    if not parent then return true end
    if not parent.dataOpen then
        return false
    end
    return isTrackVisible(current.parentId, tracks)
end

local function buildLayoutData(props)
    local layoutData = {}
    local currentY = 0

    if props.director then
        layoutData["Director_Track_Header"] = {
            yPos = currentY,
            height = 30,
            depth = 0,
            rowType = "director"
        }
        currentY = currentY + 30

        if props.director.isExpanded and props.director.clips then
            for clipIndex, clip in ipairs(props.director.clips) do
                local isActiveClip = props.currentTime >= clip.startTime and props.currentTime <= clip.endTime

                if isActiveClip and clip.properties then
                    for propName, propData in pairs(clip.properties) do
                        local propKey = "Director_Clip_" .. clip.id .. "_Prop_" .. propName

                        layoutData[propKey] = {
                            yPos = currentY,
                            height = 20,
                            depth = 1,
                            rowType = "directorProperty",
                            clipId = clip.id,
                            propertyName = propName
                        }
                        currentY = currentY + 20

                        if propData.expanded then
                            local kfKey = propKey .. "_Value"
                            layoutData[kfKey] = {
                                yPos = currentY,
                                height = 20,
                                depth = 2,
                                rowType = "directorKeyframe",
                                clipId = clip.id,
                                propertyName = propName,
                                clipStartTime = clip.startTime
                            }
                            currentY = currentY + 20
                        end
                    end
                end
            end
        end
    end

    for _, trackId in ipairs(props.trackOrder or {}) do
        local trackData = props.tracks[trackId]
        if not trackData then continue end
        if trackId == "director" then continue end

        if isTrackVisible(trackId, props.tracks) then
            local depth = getTrackDepth(trackId, props.tracks)

            layoutData["Track_" .. trackId .. "_Header"] = {
                yPos = currentY,
                height = 20,
                depth = depth
            }
            currentY = currentY + 20

            if trackData.dataOpen then
                layoutData["Track_" .. trackId .. "_Data"] = {
                    yPos = currentY,
                    height = 20,
                    depth = depth
                }
                currentY = currentY + 20

                -- Property rows
                if trackData.propertyListOpen then
                    for propIndex, prop in ipairs(trackData.properties) do
                        layoutData["Track_" .. trackId .. "_Prop_" .. propIndex] = {
                            yPos = currentY,
                            height = 20,
                            depth = depth
                        }
                        currentY = currentY + 20

                        if prop.channels and prop.isExpanded then
                            local sortedChannels = {}
                            for name in pairs(prop.channels) do
                                if name ~= "Rotation" then
                                    table.insert(sortedChannels, name)
                                end
                            end
                            table.sort(sortedChannels)

                            for _, channel in ipairs(sortedChannels) do
                                layoutData["Track_" .. trackId .. "_Prop_" .. propIndex .. "_Chan_" .. channel] = {
                                    yPos = currentY,
                                    height = 20,
                                    depth = depth,
                                    isChannel = true,
                                    channelName = channel
                                }
                                currentY = currentY + 20
                            end
                        end
                    end
                end
            end
        end
    end

    return layoutData, currentY
end

local function getSelectedKeyframesData(self)
    local initialPositions = {}
    local tracks = self.props.tracks
    local selection = self.props.selection.keyframes or {}
    local director = self.props.director

    -- Get regular keyframe positions
    for _, track in pairs(tracks) do
        if track.type == "director" then continue end
        if track.properties then
            for _, prop in ipairs(track.properties) do
                if prop.channels then
                    for chanName, channelData in pairs(prop.channels) do
                        -- FIX: Skip the Rotation channel - it contains quaternion tables, not numbers
                        if chanName == "Rotation" then
                            continue
                        end

                        if channelData.keyframes then
                            for _, kf in ipairs(channelData.keyframes) do
                                if selection[kf.id] then
                                    -- Store the TIME, not the value
                                    initialPositions[kf.id] = kf.time
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Get director keyframe positions
    if director and director.clips then
        for _, clip in ipairs(director.clips) do
            if clip.properties then
                for propName, propData in pairs(clip.properties) do
                    if propData.keyframes then
                        for _, kf in ipairs(propData.keyframes) do
                            if selection[kf.id] then
                                -- Store ABSOLUTE time (relative + clip start)
                                initialPositions[kf.id] = clip.startTime + kf.time
                            end
                        end
                    end
                end
            end
        end
    end
    return initialPositions
end

local function getBulkKeyFrames(self, startMouse, endMouse, isShiftDown)
    local content = self.contentRef:getValue()
    if not content then return end

    local contentPos = content.AbsolutePosition

    local relMinX = math.min(startMouse.X, endMouse.X) - contentPos.X
    local relMaxX = math.max(startMouse.X, endMouse.X) - contentPos.X
    local relMinY = math.min(startMouse.Y, endMouse.Y) - contentPos.Y
    local relMaxY = math.max(startMouse.Y, endMouse.Y) - contentPos.Y

    local startTime = relMinX / self.props.pixelsPerSecond
    local endTime = relMaxX / self.props.pixelsPerSecond

    local newSelection = {}
    local currentY = 0
    local ROW_HEIGHT = 20

    -- Check DIRECTOR KEYFRAMES FIRST
    if self.props.director then
        currentY = currentY + 30 -- Director header height

        if self.props.director.isExpanded and self.props.director.clips then
            for _, clip in ipairs(self.props.director.clips) do
                local isActiveClip = self.props.currentTime >= clip.startTime and self.props.currentTime <= clip.endTime

                if isActiveClip and clip.properties then
                    for propName, propData in pairs(clip.properties) do
                        currentY = currentY + ROW_HEIGHT -- Property row

                        if propData.expanded then
                            local laneTop = currentY
                            local laneBottom = currentY + ROW_HEIGHT

                            if (relMinY <= laneBottom) and (relMaxY >= laneTop) then
                                if propData.keyframes then
                                    for _, kf in ipairs(propData.keyframes) do
                                        local absoluteTime = clip.startTime + kf.time
                                        if absoluteTime >= startTime and absoluteTime <= endTime then
                                            newSelection[kf.id] = true
                                        end
                                    end
                                end
                            end

                            currentY = laneBottom
                        end
                    end
                end
            end
        end
    end

    -- Check REGULAR TRACK KEYFRAMES
    for _, trackId in ipairs(self.props.trackOrder or {}) do
        local trackData = self.props.tracks[trackId]
        if not trackData or trackData.type == "director" or not isTrackVisible(trackId, self.props.tracks) then continue end

        currentY = currentY + ROW_HEIGHT -- Header

        if trackData.dataOpen and #trackData.properties > 0 then
            currentY = currentY + ROW_HEIGHT -- Data folder

            if trackData.propertyListOpen then
                for propIndex, prop in ipairs(trackData.properties) do
                    currentY = currentY + ROW_HEIGHT -- Property row

                    if prop.channels and prop.isExpanded then
                        local sortedNames = {}
                        for name in pairs(prop.channels) do 
                            if name ~= "Rotation" then
                                table.insert(sortedNames, name) 
                            end
                        end
                        table.sort(sortedNames)

                        for _, chanName in ipairs(sortedNames) do
                            local channelData = prop.channels[chanName]
                            local laneTop = currentY
                            local laneBottom = currentY + ROW_HEIGHT

                            if (relMinY <= laneBottom) and (relMaxY >= laneTop) then
                                if channelData.keyframes then
                                    for _, kf in ipairs(channelData.keyframes) do
                                        if kf.time >= startTime and kf.time <= endTime then
                                            newSelection[kf.id] = true
                                        end
                                    end
                                end
                            end
                            currentY = laneBottom
                        end
                    end
                end
            end
        end
    end

    -- FIX: Pass the selection object directly, not wrapped
    self.props.onKeyFrameSelection(newSelection, "Replace")
end

function GridLayer:updateDraggingSelection(currentMousePos, startMousePos)
    if not self.state.isDragging or not self.initialKeyframePositions then return end

    local fps = self.props.fps or 60
    local frameDuration = 1 / fps 

    local deltaX = currentMousePos.X - startMousePos.X
    local deltaTime = deltaX / self.props.pixelsPerSecond
    local movedUpdates = {}

    for kfId, originalTime in pairs(self.initialKeyframePositions) do
        -- originalTime is already in the correct space:
        -- - For regular keyframes: it's their actual time
        -- - For director keyframes: it's absolute time (clip.startTime + kf.time)
        local newTime = math.max(0, originalTime + deltaTime)
        newTime = math.floor(newTime / frameDuration + 0.5) * frameDuration
        movedUpdates[kfId] = newTime
    end

    self.props.onKeyframeMove(movedUpdates)
end

function GridLayer:init()
    self.state = {
        isSelecting = false,
        isDragging = false,
    }

    self.initialKeyframePositions = {}

    self.selectionRef = Roact.createRef()
    self.contentRef = Roact.createRef()
    self.mainFrameRef = Roact.createRef()
    self.sidebarContentRef = Roact.createRef() -- NEW: Track sidebar content
    self.laneViewportRef = Roact.createRef()   -- NEW: Track lane viewport

    self.onChangeConnection = nil
    self.releaseConnection = nil

    self.readyToDrag = false
end

function GridLayer:didMount()
    local sidebarContent = self.sidebarContentRef:getValue()
    local laneViewport = self.laneViewportRef:getValue()

    if sidebarContent and laneViewport then
        -- Store the connection in the instance
        self.sizeConnection = sidebarContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            local canvasHeight = sidebarContent.AbsoluteSize.Y
            local viewportHeight = laneViewport.AbsoluteSize.Y
            local maxScrollY = math.max(0, canvasHeight - viewportHeight)

            if self.props.onStateChange then
                self.props.onStateChange("ui", {maxScrollY = maxScrollY})
                self.props.onStateChange("ui", {canvasHeight = canvasHeight})
            end
        end)
    end
end

function GridLayer:willUnmount()
    if self.sizeConnection then
        self.sizeConnection:Disconnect()
    end
    -- Also cleanup mouse connections just in case
    if self.onChangeConnection then self.onChangeConnection:Disconnect() end
    if self.releaseConnection then self.releaseConnection:Disconnect() end
end

local function countDictionary(dict)
    local count = 0
    for _ in pairs(dict or {}) do
        count = count + 1
    end
    return count
end

function GridLayer:getMetadataAtMouseY(mouseY)
    local content = self.contentRef:getValue()
    if not content then return nil, nil end

    local lanesHolder = content:FindFirstChild("LanesHolder")
    if not lanesHolder then return nil, nil end

    for _, trackId in ipairs(self.props.trackOrder or {}) do
        local trackData = self.props.tracks[trackId]
        if not trackData then continue end

        if not isTrackVisible(trackId, self.props.tracks) then continue end

        -- Check header lane
        local headerLane = lanesHolder:FindFirstChild("Track_" .. trackId .. "_Header_Lane")
        if headerLane then
            local laneTop = headerLane.AbsolutePosition.Y
            local laneBottom = laneTop + headerLane.AbsoluteSize.Y

            if mouseY >= laneTop and mouseY < laneBottom then
                return trackId, nil -- On header row
            end
        end

        -- If track is expanded, check property lanes
        if trackData.dataOpen and trackData.propertyListOpen and trackData.properties then
            for propIndex, prop in ipairs(trackData.properties) do
                local propLane = lanesHolder:FindFirstChild("Track_" .. trackId .. "_Prop_" .. propIndex .. "_Lane")

                if propLane then
                    local laneTop = propLane.AbsolutePosition.Y
                    local laneBottom = laneTop + propLane.AbsoluteSize.Y

                    if mouseY >= laneTop and mouseY < laneBottom then
                        return trackId, prop.name -- On property row
                    end
                end
            end
        end
    end

    return nil, nil
end

function GridLayer:render()
    local menuElements = {}

    if self.props.isPanelOpen then
        for levelIndex, data in ipairs(self.props.openMenus or {}) do
            menuElements["MenuLevel_" .. levelIndex] = Roact.createElement(ContextMenu, {
                level = levelIndex,
                items = data.items, 
                mousePos = data.pos,
                mode = self.props.mode,
                isPanelOpen = true,

                onAction = self.props.onAction, 
                selectionCount = countDictionary(self.props.selection.keyframes or {}),  -- NEW: count keyframes
                onHoverSubMenu = self.props.onHoverSubMenu,

                zIndex = 10 + levelIndex, 
            })
        end
    end


    local sidebarItems = {}
    local layoutData, totalHeight = buildLayoutData(self.props)
    local laneItems = {}

    if self.props.director then
        local directorLayout = layoutData["Director_Track_Header"]
        if directorLayout then
            local directorKey = "Director_Track_Header"

            sidebarItems[directorKey] = Roact.createElement(RowTrack, {
                trackData = self.props.director,
                Position = UDim2.fromOffset(0, directorLayout.yPos),
                Size = UDim2.new(1, 0, 0, directorLayout.height),
                indent = 5,
                rowType = "director",
                onStateChange = self.props.onStateChange,
                onAddClip = self.props.onAddClip,
                currentTime = self.props.currentTime,
                toggleCameraPreview = self.props.toggleCameraPreview,
                cameraPreviewActive = self.props.cameraPreviewActive,
                toggleDirectorExpansion = self.props.toggleDirectorExpansion,
            })

            laneItems[directorKey .. "_Lane"] = Roact.createElement(LaneComponent, {
                directorData = self.props.director,
                rowType = "director",
                pixelsPerSecond = self.props.pixelsPerSecond,
                onStateChange = self.props.onStateChange,
                totalSeconds = self.props.totalSeconds,
                yPosition = directorLayout.yPos,
                height = directorLayout.height,
                selectClip = self.props.selectClip,
                clipSelection = self.props.selection.clips,
                onClipMove = self.props.onClipMove,
                onClipResize = self.props.onClipResize,
            })

            if self.props.director.isExpanded and self.props.director.clips then
                for clipIndex, clip in ipairs(self.props.director.clips) do
                    local isActiveClip = self.props.currentTime >= clip.startTime and self.props.currentTime <= clip.endTime

                    if isActiveClip and clip.properties then
                        for propName, propData in pairs(clip.properties) do
                            local propKey = "Director_Clip_" .. clip.id .. "_Prop_" .. propName
                            local propLayout = layoutData[propKey]

                            if propLayout then
                                sidebarItems[propKey] = Roact.createElement(RowTrack, {
                                    trackData = self.props.director,
                                    propertyData = propData,
                                    propertyName = propName,
                                    clipId = clip.id,
                                    Position = UDim2.fromOffset(0, propLayout.yPos),
                                    Size = UDim2.new(1, 0, 0, propLayout.height),
                                    indent = 30,
                                    rowType = "directorProperty",
                                    toggleDirectorProperty = self.props.toggleDirectorProperty,
                                })
                                
                                laneItems[propKey .. "_Lane"] = Roact.createElement(LaneComponent, {
                                    directorData = self.props.director,
                                    rowType = "directorProperty",
                                    clipId = clip.id,
                                    propertyName = propName,
                                    propertyData = propData,
                                    pixelsPerSecond = self.props.pixelsPerSecond,
                                    totalSeconds = self.props.totalSeconds,
                                    yPosition = propLayout.yPos,
                                    height = propLayout.height,
                                    clipStartTime = clip.startTime,
                                    currentTime = self.props.currentTime,
                                    selection = self.props.selection.keyframes or {}, -- FIX: Use keyframes
                                    onKeyFrameSelection = self.props.onKeyFrameSelection,
                                })

                                if propData.expanded then
                                    local kfKey = propKey .. "_Value"
                                    local kfLayout = layoutData[kfKey]

                                    if kfLayout then
                                        sidebarItems[kfKey] = Roact.createElement(RowTrack, {
                                            trackData = self.props.director,
                                            propertyName = propName,
                                            clipId = clip.id,
                                            keyframeData = propData.keyframes and propData.keyframes[1] or { value = 0 },
                                            allKeyframes = propData.keyframes,
                                            clipStartTime = clip.startTime,
                                            clipEndTime = clip.endTime,
                                            Position = UDim2.fromOffset(0, kfLayout.yPos),
                                            Size = UDim2.new(1, 0, 0, kfLayout.height),
                                            indent = 45,
                                            rowType = "directorKeyframe",
                                            currentTime = self.props.currentTime,
                                            onDirectorKeyframeUpdate = self.props.onDirectorKeyframeUpdate,
                                        })

                                        laneItems[kfKey .. "_Lane"] = Roact.createElement(LaneComponent, {
                                            directorData = self.props.director,
                                            rowType = "directorKeyframe",
                                            clipId = clip.id,
                                            propertyName = propName,
                                            propertyData = propData,
                                            pixelsPerSecond = self.props.pixelsPerSecond,
                                            totalSeconds = self.props.totalSeconds,
                                            yPosition = kfLayout.yPos,
                                            height = kfLayout.height,
                                            clipEndTime = clip.endTime,
                                            clipStartTime = clip.startTime,
                                            currentTime = self.props.currentTime,
                                            selection = self.props.selection.keyframes or {}, -- FIX: Just pass keyframes as "selection"
                                            onStateChange = self.props.onStateChange,
                                            isInputHandledByUI = self.props.isInputHandledByUI,
                                            onKeyFrameSelection = self.props.onKeyFrameSelection,
                                            onKeyframeMove = self.props.onKeyframeMove,
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- ============================================
    -- RENDER REGULAR TRACKS
    -- ============================================
    for _, trackId in ipairs(self.props.trackOrder or {}) do
        local trackData = self.props.tracks[trackId]
        if not trackData or trackData.type == "director" then continue end

        if isTrackVisible(trackId, self.props.tracks) then
            local headerKey = "Track_" .. trackId .. "_Header"
            local headerLayout = layoutData[headerKey]

            if headerLayout then
                sidebarItems[headerKey] = Roact.createElement(RowTrack, {
                    trackData = trackData,
                    index = trackId,
                    Position = UDim2.fromOffset(0, headerLayout.yPos),
                    Size = UDim2.new(1, 0, 0, headerLayout.height),
                    indent = headerLayout.depth * 5,
                    rowType = "header",
                    currentTime = self.props.currentTime,
                    toggleTrackExpansion = self.props.toggleTrackExpansion,
                    onStateChange = self.props.onStateChange,
                    createKeyFrame = self.props.createKeyFrame
                })

                laneItems[headerKey .. "_Lane"] = Roact.createElement(LaneComponent, {
                    trackData = trackData,
                    rowType = "header",
                    pixelsPerSecond = self.props.pixelsPerSecond,
                    totalSeconds = self.props.totalSeconds,
                    selection = self.props.selection,
                    onKeyFrameSelection = self.props.onKeyFrameSelection,
                    onKeyframeMove = self.props.onKeyframeMove,
                    isInputHandledByUI = self.props.isInputHandledByUI,
                    onStateChange = self.props.onStateChange,
                    yPosition = headerLayout.yPos,
                    height = headerLayout.height,
                })
            end

            if trackData.dataOpen then
                local dataKey = "Track_" .. trackId .. "_Data"
                local dataLayout = layoutData[dataKey]
                
                if dataLayout then
                    sidebarItems[dataKey] = Roact.createElement(RowTrack, {
                        trackData = trackData,
                        index = trackId,
                        Position = UDim2.fromOffset(0, dataLayout.yPos),
                        Size = UDim2.new(1, 0, 0, dataLayout.height),
                        indent = dataLayout.depth * 5 + 3,
                        rowType = "dataFolder",
                        onStateChange = self.props.onStateChange,
                        toggleTrackExpansion = self.props.toggleTrackExpansion,
                        
                        openPropertyPicker = function(trackId, position)
                            self.props.openPropertyPicker(trackId, position)
                        end
                    })

                    laneItems[dataKey .. "_Lane"] = Roact.createElement(LaneComponent, {
                        trackData = trackData,
                        rowType = "dataFolder",
                        pixelsPerSecond = self.props.pixelsPerSecond,
                        totalSeconds = self.props.totalSeconds,
                        yPosition = dataLayout.yPos,
                        height = dataLayout.height,
                    })
                end

                -- Property rows
                if trackData.propertyListOpen then
                    for propIndex, prop in ipairs(trackData.properties) do
                        local propKey = "Track_" .. trackId .. "_Prop_" .. propIndex
                        local propLayout = layoutData[propKey]

                        if propLayout then
                            sidebarItems[propKey] = Roact.createElement(RowTrack, {
                                trackData = trackData,
                                propertyData = prop,
                                propertyIndex = propIndex,
                                index = trackId,
                                Position = UDim2.fromOffset(0, propLayout.yPos),
                                Size = UDim2.new(1, 0, 0, propLayout.height),
                                indent = propLayout.depth * 5 + 30,
                                rowType = "property",
                                onPropertyUiChange = self.props.onPropertyUiChange,
                                currentTime = self.props.currentTime,
                                createKeyFrame = self.props.createKeyFrame,
                            })

                            laneItems[propKey .. "_Lane"] = Roact.createElement(LaneComponent, {
                                trackData = trackData,
                                propertyData = prop,
                                rowType = "property",
                                pixelsPerSecond = self.props.pixelsPerSecond,
                                totalSeconds = self.props.totalSeconds,
                                selection = self.props.selection,
                                onKeyFrameSelection = self.props.onKeyFrameSelection,
                                onKeyframeMove = self.props.onKeyframeMove,
                                isInputHandledByUI = self.props.isInputHandledByUI,
                                onStateChange = self.props.onStateChange,
                                Recomposition = self.props.Recomposition,
                                yPosition = propLayout.yPos,
                                height = propLayout.height,
                            })

                            if prop.channels and prop.isExpanded then
                                local sortedChannels = {}
                                for name in pairs(prop.channels) do         
                                    if name ~= "Rotation" then
                                        table.insert(sortedChannels, name) 
                                    end
                                end
                                table.sort(sortedChannels)

                                for _, channelName in ipairs(sortedChannels) do
                                    local chanKey = "Track_" .. trackId .. "_Prop_" .. propIndex .. "_Chan_" .. channelName
                                    local chanLayout = layoutData[chanKey]

                                    if chanLayout then
                                        sidebarItems[chanKey] = Roact.createElement(RowTrack, {
                                            trackData = trackData,
                                            property = prop.name,
                                            channelName = channelName,
                                            channelData = prop.channels[channelName],
                                            Position = UDim2.fromOffset(0, chanLayout.yPos),
                                            Size = UDim2.new(1, 0, 0, chanLayout.height),
                                            createKeyFrame = self.props.createKeyFrame,
                                            currentTime = self.props.currentTime,
                                            indent = propLayout.depth * 5 + 45,
                                            rowType = "channel",
                                        })

                                        laneItems[chanKey .. "_Lane"] = Roact.createElement(LaneComponent, {
                                            trackData = trackData,
                                            propertyData = prop,
                                            channelName = channelName,
                                            rowType = "channel",
                                            pixelsPerSecond = self.props.pixelsPerSecond,
                                            totalSeconds = self.props.totalSeconds,
                                            yPosition = chanLayout.yPos,
                                            height = chanLayout.height,
                                            selection = self.props.selection,
                                            onKeyFrameSelection = self.props.onKeyFrameSelection,
                                            onStateChange = self.props.onStateChange,
                                            onKeyframeMove = self.props.onKeyframeMove,
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return Roact.createElement("Frame", {
        [Roact.Ref] = self.mainFrameRef,
        Style = {
            s = UDim2.new(1, -25, 1, -25),
            ps = UDim2.new(0, 25, 0, 0),
            bg = Theme.EditorBG,
            sBorder = 0,
            clip = true,
        }
    }, {

        Ruler = Roact.createElement(RulerComponent, {
            totalSeconds = self.props.totalSeconds,
            pixelsPerSecond = self.props.pixelsPerSecond,
            currentTime = self.props.currentTime,
            fps = self.props.fps,
            position = self.props.positionX - (self.props.panX or 0),
            onStateChange = self.props.onStateChange,
            locks = self.props.locks,
            playbackController = self.props.playbackController,
        }),

        SidebarViewport = Roact.createElement("Frame", {
            Size = UDim2.new(0, 350, 1, 0),
            BackgroundColor3 = Theme.PanelBG,
            BorderSizePixel = 0,
            ZIndex = 10,
            ClipsDescendants = true,
        }, {
            RightBorder = Roact.createElement("Frame", {
                Size = UDim2.new(0, 1, 1, 0),
                Position = UDim2.new(1, -1, 0, 0),
                BackgroundColor3 = Theme.BorderLight,
                BorderSizePixel = 0,
                ZIndex = 11,
            }),

            TopBar = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = Theme.TopbarBG,
                BorderSizePixel = 0,
                ZIndex = 11,
            }, {

                BottomLine = Roact.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 1),
                    Position = UDim2.new(0, 0, 1, 0),
                    BackgroundColor3 = Theme.Separator,
                    BorderSizePixel = 0,
                    ZIndex = 11,
                }),

                CreationButton = Roact.createElement("TextButton", {
                    Size = UDim2.fromOffset(100, 22),
                    Position = UDim2.fromOffset(6, 5),
                    Text = "+ Track",
                    FontFace = Theme.FontNormal,
                    TextSize = 15,
                    TextColor3 = Theme.TextMain,
                    BackgroundColor3 = Theme.Accent,
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    ZIndex = 12,
                    [Roact.Event.Activated] = function()
                        local selection = game:GetService("Selection"):Get()
                        if #selection > 0 then
                            self.props.smartAdd(selection[1], nil)
                        end
                    end,

                    [Roact.Event.MouseEnter] = function(rbx)
                        rbx.BackgroundColor3 = Theme.AccentHover
                    end,
                    [Roact.Event.MouseLeave] = function(rbx)
                        rbx.BackgroundColor3 = Theme.Accent
                    end,
                }, {
                    Corner = Roact.createElement("UICorner", {
                        CornerRadius = UDim.new(0, 2),
                    })
                }),
                GraphButton = Roact.createElement("ImageButton", {
                    Image = Images.Graph,
                    Size = UDim2.fromOffset(22, 22),
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(120, 5),
                    BorderSizePixel = 0,
                    AutoButtonColor = false,
                    ZIndex = 12,
                    [Roact.Event.Activated] = function(rbx)
                        if self.props.mode == "Graph" then
                            self.props.onStateChange("viewport", {mode = "Timeline"})
                        elseif self.props.mode == "Timeline" then
                            self.props.onStateChange("viewport", {mode = "Graph"})
                        end
                       
                    end,
                })

            }),
            Content = Roact.createElement("Frame", {
                [Roact.Ref] = self.sidebarContentRef,
                Size = UDim2.new(1, 0, 0, totalHeight),
                Position = UDim2.fromOffset(0, 32 - (self.props.positionY * totalHeight)),

                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 10,
            }, sidebarItems),
        }),

        LaneViewport = Roact.createElement("Frame", {
            [Roact.Ref] = self.laneViewportRef,
            Size = UDim2.new(1, -350, 1, -32),
            Position = UDim2.fromOffset(350, 32),
            BackgroundColor3 = Theme.EditorBG,
            BorderSizePixel = 0,
            ZIndex = 5,
            ClipsDescendants = true,
            
            [Roact.Event.InputEnded] = function(rbx, input)
                if input.UserInputType == Enum.UserInputType.MouseButton2 then
                    local frame = self.mainFrameRef:getValue()
                    if frame then
                        local screenPos = input.Position

                        local localX = screenPos.X - frame.AbsolutePosition.X
                        local localY = screenPos.Y - frame.AbsolutePosition.Y

                        local menuX = localX - 380
                        local menuY = localY - 32

                        local trackId, propName = self:getMetadataAtMouseY(screenPos.Y)
                        local timeAtClick = (menuX + self.props.positionX) / self.props.pixelsPerSecond

                        timeAtClick = math.floor(timeAtClick / 0.1 + 0.5) * 0.1

                        self.props.triggerContext(
                            Vector2.new(menuX, menuY), 
                            {
                                trackId = trackId,
                                propName = propName,
                                time = timeAtClick
                            }
                        )
                    end
                end
                
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    if self.props.isPanelOpen then
                        self.props.onStateChange("ui", {isPanelOpen = false})
                    end
                end
            end,
            
        }, {
            UIPadding = Roact.createElement("UIPadding", {
                PaddingLeft = UDim.new(0, 40),
            }),

            VerticalLinesLayer = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                BorderSizePixel = 0,
                ZIndex = 6,
                ClipsDescendants = true,
            }, {
                VerticalLinesContainer = Roact.createElement("Frame", {
                    Size = UDim2.new(0, 25 + (self.props.totalSeconds * self.props.pixelsPerSecond), 1, 0),
                    Position = UDim2.new(0, -self.props.positionX + self.props.panX, 0, 0), -- Only horizontal scroll
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                }, {
                    VerticalLinesHolder = Roact.createElement(VerticalLines, {
                        pixelsPerSecond = self.props.pixelsPerSecond,
                        totalSeconds = self.props.totalSeconds,
                    })
                })
            }),

            Content = self.props.mode == "Timeline" and Roact.createElement("Frame", {
                [Roact.Ref] = self.contentRef,
                Size = UDim2.new(
                    0, 25 + (self.props.totalSeconds * self.props.pixelsPerSecond), 
                    0, totalHeight
                ),
                Position = UDim2.fromOffset(
                    -self.props.positionX,
                    -(self.props.positionY * totalHeight)
                ),
                BackgroundTransparency = 1,
                ZIndex = 7,

                [Roact.Event.InputChanged] = function(rbx, input)
                    if input.UserInputType == Enum.UserInputType.MouseWheel then
                        local mouseX = input.Position.X - rbx.AbsolutePosition.X
                        self.props.onZoom(input.Position.Z, mouseX)
                    end
                end,

                [Roact.Event.InputBegan] = function(rbx, input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        
                        local wasHandledByUI = self.props.isInputHandledByUI
                        if wasHandledByUI then
                            self.initialKeyframePositions = getSelectedKeyframesData(self)
                            self:setState({ isDragging = true, isSelecting = false })

                            local startPos = Vector2.new(input.Position.X, input.Position.Y)

                            self.onChangeConnection = rbx.InputChanged:Connect(function(moveInput)
                                if moveInput.UserInputType == Enum.UserInputType.MouseMovement then
                                    local currentPos = Vector2.new(moveInput.Position.X, moveInput.Position.Y)
                                    self:updateDraggingSelection(currentPos, startPos)
                                end
                            end)

                            self.releaseConnection = rbx.InputEnded:Connect(function(upInput)
                                if upInput.UserInputType == Enum.UserInputType.MouseButton1 then
                                    if self.onChangeConnection then self.onChangeConnection:Disconnect() end
                                    if self.releaseConnection then self.releaseConnection:Disconnect() end
                                    self.onChangeConnection = nil
                                    self.releaseConnection = nil

                                    self.props.onStateChange("ui", {isInputHandledByUI = false})
                                    self:setState({isDragging = false})
                                end
                            end)
                            return
                        end

                        self:setState({ isSelecting = true, isDragging = false })

                        local startPos = Vector2.new(input.Position.X, input.Position.Y)
                        local movedDistance = 0

                        self.onChangeConnection = rbx.InputChanged:Connect(function(moveInput)
                            if moveInput.UserInputType == Enum.UserInputType.MouseMovement then
                                moveInput = Vector2.new(moveInput.Position.X, moveInput.Position.Y)
                                movedDistance = (moveInput - startPos).Magnitude

                                if self.state.isDragging then
                                    self:updateDraggingSelection(moveInput, startPos)
                                elseif self.state.isSelecting then
                                    local endPos = Vector2.new(moveInput.X, moveInput.Y)
                                    local delta = (endPos - startPos)
                                    local selectionFrame = self.selectionRef:getValue()
                                    if selectionFrame then
                                        selectionFrame.Visible = true
                                        local rel = startPos - rbx.AbsolutePosition
                                        local moveRel = endPos - rbx.AbsolutePosition
                                        selectionFrame.Position = UDim2.fromOffset(math.min(rel.X, moveRel.X), math.min(rel.Y, moveRel.Y))
                                        selectionFrame.Size = UDim2.fromOffset(math.abs(delta.X), math.abs(delta.Y))
                                    end
                                end
                            end
                        end)

                        self.releaseConnection = rbx.InputEnded:Connect(function(upInput)
                            if upInput.UserInputType == Enum.UserInputType.MouseButton1 then
                                if movedDistance < 3 then
                                    if self.props.onKeyFrameSelection then
                                        self.props.onKeyFrameSelection({}, "Replace")
                                    end
                                elseif self.state.isSelecting then
                                    getBulkKeyFrames(self, startPos, upInput.Position)
                                end

                                if self.onChangeConnection then self.onChangeConnection:Disconnect() end
                                if self.releaseConnection then self.releaseConnection:Disconnect() end
                                self.onChangeConnection = nil
                                self.releaseConnection = nil

                                -- ALWAYS close context menu on click
                                self.props.onStateChange("ui", {isPanelOpen = false})

                                local sf = self.selectionRef:getValue()
                                if sf then sf.Visible = false end
                                self:setState({isSelecting = false})
                            end
                        end)
                    end
                end
            }, {
                ViewContent = Roact.createElement("Frame", {
                    Size = UDim2.new(1, 0, 1, 0),
                    BackgroundTransparency = 1,
                }, laneItems),


                SelectionBox = Roact.createElement("Frame", {
                    [Roact.Ref] = self.selectionRef,
                    BackgroundColor3 = Theme.SelectionBox,
                    BackgroundTransparency = 0.9,
                    BorderSizePixel = 0,
                    Visible = false,
                    ZIndex = 200,
                }, {
                    UIStroke = Roact.createElement("UIStroke", {
                        Color = Theme.SelectionBoxStroke,
                        Thickness = 1,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                    })
                }),
            }) or nil,

            GraphLayer = self.props.mode == "Graph" and Roact.createElement(GraphCanvas, {
                positionX = self.props.positionX,
                valueOffset = self.props.valueOffset,
                pixelsPerSecond = self.props.pixelsPerSecond,
                totalSeconds = self.props.totalSeconds,
                vps = self.props.vps or 100,
                tracks = self.props.tracks,
                findKeyframeById = self.props.findKeyframeById,
                canvasWidth = self.laneViewportRef:getValue() and self.laneViewportRef:getValue().AbsoluteSize.X,
                canvasHeight = self.laneViewportRef:getValue() and self.laneViewportRef:getValue().AbsoluteSize.Y or 300,
                currentTime = self.props.currentTime,
                selection = self.props.selection,
                onStateChange = self.props.onStateChange,
                panX = self.props.panX or 0,
                panY = self.props.panY or 0,
                
                zoomY = self.props.zoomY,
                
                onKeyframeUpdate = self.props.onKeyframeUpdate,
                getExpandedTracksForGraph = self.props.getExpandedTracksForGraph,
                onKeyframeUpdateFromGraph = self.props.onKeyframeUpdateFromGraph,

                onKeyFrameSelection = self.props.onKeyFrameSelection,
                
                onHandleUpdate = self.props.onHandleUpdate,
                
                onGraphZoom = self.props.onGraphZoom,
                onZoomX = self.props.onZoom,
            }) or nil,

            ContextMenus = Roact.createFragment(menuElements),
        }),
        
        Test = Roact.createElement("Frame", {
            Size = UDim2.new(1, -350, 1, 0),
            Position = UDim2.fromOffset(350, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ZIndex = 99999,
            ClipsDescendants = true,
        }, {
            PlayHead = Roact.createElement(PlayHeadComponent, {
                currentTime = self.props.currentTime,
                pixelsPerSecond = self.props.pixelsPerSecond,
                position = self.props.positionX - (self.props.panX or 0) - 40,
                locks = self.props.locks,

                totalSeconds = self.props.totalSeconds,
                onStateChange = self.props.onStateChange,
            }),
        })
    })
end

return GridLayer