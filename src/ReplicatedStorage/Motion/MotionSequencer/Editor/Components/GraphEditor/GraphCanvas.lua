local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local GraphCanvas = Roact.Component:extend("GraphCanvas")
local RBezier = require(script.Parent.Parent.Parent.Parent.Core.Math.RBezier)

--------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------

local Theme = require(script.Parent.Parent.Parent.Themes.Theme)

local SNAP_TIME = 0.1
local SNAP_VALUE = 0.05
local HANDLE_LENGTH = 0.3

local MAX_BEZIER_SEGMENTS = 50 
local MIN_BEZIER_SEGMENTS = 10 

--------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------
local function snapValue(value, snapSize)
    return math.round(value / snapSize) * snapSize
end

local function getChannelColor(channelName : string)
    local cleanName = channelName:match("^%s*(.-)%s*$") 
    local key = "GraphEditor_" .. cleanName

    local Color = Theme[key]

    if Color == nil then 
        Color = Theme.GraphEditor_Value 
    end

    return Color
end

local function getHandleColor(baseColor, mode)
    if mode == "Mirrored" then
        return baseColor:Lerp(Theme.GraphEditor_Mirrored, 0.2) 
    elseif mode == "Aligned" then
        return baseColor:Lerp(Theme.GraphEditor_Aligned, 0.3)
    elseif mode == "Free" then
        return baseColor:Lerp(Theme.GraphEditor_Free, 0.2)
    end
    return baseColor
end

local function isTrackVisible(trackId, tracks)
    local current = tracks[trackId]
    if not current then return false end
    if not current.parentId or current.parentId == "" then return true end
    local parent = tracks[current.parentId]
    if not parent or not parent.dataOpen then return false end
    return isTrackVisible(current.parentId, tracks)
end

local function ensureNumber(value)
    if type(value) == "number" then return value
    elseif typeof(value) == "Vector3" then return value.Magnitude
    elseif typeof(value) == "boolean" then return value and 1 or 0
    else return 0 end
end

local function isNumericChannel(keyframes)
    if not keyframes or #keyframes == 0 then return false end

    for _, kf in ipairs(keyframes) do
        local valType = type(kf.value)
        if valType == "boolean" or valType == "string" or valType == "table" then
            return false
        end
    end

    return true
end

local function processHandleDelta(kf, movedSide, deltaX, deltaY, originalOtherMag)
    local mode = kf.tangentMode or "Free"
    local updates = {
        [movedSide] = {x = deltaX, y = deltaY}
    }

    if mode == "Free" then
        return updates
    end

    local otherSide = (movedSide == "right") and "left" or "right"
    local movedAngle = math.atan2(deltaY, deltaX)
    local targetAngle = movedAngle + math.pi

    if mode == "Mirrored" then
        local mag = math.sqrt(deltaX^2 + deltaY^2)
        updates[otherSide] = {
            x = math.cos(targetAngle) * mag,
            y = math.sin(targetAngle) * mag
        }
    elseif mode == "Aligned" then
        local mag = originalOtherMag or 1.0 
        updates[otherSide] = {
            x = math.cos(targetAngle) * mag,
            y = math.sin(targetAngle) * mag
        }
    end

    return updates
end

--------------------------------------------------------------------
-- COMPONENT
--------------------------------------------------------------------
function GraphCanvas:init()
    self.state = {
        isPanning = false,
        isDraggingKF = false,
        isDraggingHandle = false,
        isSelecting = false,
        dragTargets = {},
        dragHandleData = nil,
        selectionStartPos = Vector2.new(0, 0),
        dragStartMouseWorld = nil,
    }

    self.selectionRef = Roact.createRef()
    self.contentRef = Roact.createRef()
    self.inputService = game:GetService("UserInputService")
end

function GraphCanvas:findKeyframeById(kfId)
    local tracks = self.props.tracks
    if not tracks then return nil end

    for _, track in pairs(tracks) do
        if track.type == "director" then continue end
        for _, prop in ipairs(track.properties) do
            for _, channel in pairs(prop.channels or {}) do
                for _, kf in ipairs(channel.keyframes or {}) do
                    if kf.id == kfId then
                        return kf
                    end
                end
            end
        end
    end
    return nil
end

function GraphCanvas:getTransformData()
    local p = self.props
    local canvasWidth = p.canvasWidth or 1000
    local canvasHeight = p.canvasHeight or 500
    local pps = p.pixelsPerSecond or 50
    local scrollX = p.positionX or 0

    return {
        pps = pps,
        zoomY = p.zoomY or 50,
        panX = p.panX or 0,
        panY = p.panY or 0,
        centerY = canvasHeight / 2,
        totalScrollX = (scrollX * (p.totalSeconds * pps - canvasWidth)),
        canvasWidth = canvasWidth,
        canvasHeight = canvasHeight
    }
end

function GraphCanvas:toScreen(worldX, worldValue, t)
    worldX = tonumber(worldX) or 0
    worldValue = tonumber(worldValue) or 0
    local x = (worldX * t.pps) - t.totalScrollX + t.panX
    local y = (t.centerY + t.panY) - (worldValue * t.zoomY)
    return Vector2.new(x, y)
end

function GraphCanvas:toWorld(screenX, screenY, t)
    local worldX = (screenX + t.totalScrollX - t.panX) / t.pps
    local worldValue = (t.centerY + t.panY - screenY) / t.zoomY
    return worldX, worldValue
end

function GraphCanvas:getKFAtMouse(mousePos, t)
    local threshold = 12
    local tracks = self.props.tracks

    for trackId, track in pairs(tracks or {}) do
        if track.type == "director" then continue end
        if isTrackVisible(trackId, tracks) then
            for _, prop in ipairs(track.properties) do
                for channelName, channel in pairs(prop.channels or {}) do
                    for _, kf in ipairs(channel.keyframes or {}) do
                        local value = ensureNumber(kf.value)
                        local pos = self:toScreen(kf.time, value, t)
                        if (pos - mousePos).Magnitude < threshold then
                            return kf, prop, channelName, trackId, track
                        end
                    end
                end
            end
        end
    end
end

function GraphCanvas:getHandleAtMouse(mousePos, t)
    local threshold = 10
    local tracks = self.props.tracks
    local selection = self.props.selection or {}

    for trackId, track in pairs(tracks or {}) do
        if track.type == "director" then continue end
        if isTrackVisible(trackId, tracks) then
            for _, prop in ipairs(track.properties) do
                for channelName, channel in pairs(prop.channels or {}) do
                    for _, kf in ipairs(channel.keyframes or {}) do
                        if selection.keyframes[kf.id] then
                            local kfPos = self:toScreen(kf.time, ensureNumber(kf.value), t)

                            if kf.handleRight then
                                local handleWorldPos = Vector2.new(
                                    kf.time + kf.handleRight.x,
                                    ensureNumber(kf.value) + kf.handleRight.y
                                )
                                local handleScreenPos = self:toScreen(handleWorldPos.X, handleWorldPos.Y, t)

                                if (handleScreenPos - mousePos).Magnitude < threshold then
                                    return kf, "right", prop, channelName, trackId
                                end
                            end

                            if kf.handleLeft then
                                local handleWorldPos = Vector2.new(
                                    kf.time - kf.handleLeft.x,
                                    ensureNumber(kf.value) + kf.handleLeft.y
                                )
                                local handleScreenPos = self:toScreen(handleWorldPos.X, handleWorldPos.Y, t)

                                if (handleScreenPos - mousePos).Magnitude < threshold then
                                    return kf, "left", prop, channelName, trackId
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function GraphCanvas:getSelectedKeyframes()
    local selected = {}
    local tracks = self.props.tracks
    local selection = self.props.selection or {}

    for trackId, track in pairs(tracks or {}) do
        if track.type == "director" then continue end
        for _, prop in ipairs(track.properties) do
            for channelName, channel in pairs(prop.channels or {}) do
                for _, kf in ipairs(channel.keyframes or {}) do
                    if selection.keyframes[kf.id] then
                        table.insert(selected, {
                            kf = kf,
                            prop = prop,
                            channelName = channelName,
                            trackId = trackId,
                            track = track,
                            originalTime = kf.time,
                            originalValue = ensureNumber(kf.value)
                        })
                    end
                end
            end
        end
    end

    return selected
end

--------------------------------------------------------------------
-- RENDER
--------------------------------------------------------------------
function GraphCanvas:render()
    local props = self.props
    local t = self:getTransformData()
    local elements = {}

    -- PERFORMANCE: Calculate visible time range for culling
    local visibleStartTime, _ = self:toWorld(0, 0, t)
    local visibleEndTime, _ = self:toWorld(t.canvasWidth, 0, t)
    local timeBuffer = (visibleEndTime - visibleStartTime) * 0.1

    -- GRID
    local _, valAtTop = self:toWorld(0, 0, t)
    local _, valAtBottom = self:toWorld(0, t.canvasHeight, t)
    local gridMin = math.min(valAtTop, valAtBottom)
    local gridMax = math.max(valAtTop, valAtBottom)

    local visibleRange = gridMax - gridMin
    local targetLines = 6
    local rawStep = visibleRange / targetLines
    local magnitude = math.pow(10, math.floor(math.log10(rawStep)))
    local relativeStep = rawStep / magnitude

    local cleanStep
    if relativeStep < 1.5 then cleanStep = 1
    elseif relativeStep < 3.5 then cleanStep = 2
    elseif relativeStep < 7.5 then cleanStep = 5
    else cleanStep = 10 end

    local step = cleanStep * magnitude

    local startVal = math.floor(gridMin / step) * step
    for val = startVal, gridMax + step, step do
        local screenY = self:toScreen(0, val, t).Y
        local isZero = math.abs(val) < (step * 0.001)

        if screenY >= -20 and screenY <= t.canvasHeight + 20 then
            elements["Grid_" .. val] = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                Position = UDim2.fromOffset(0, screenY),
                BackgroundColor3 = isZero and Theme.GraphEditor_ZeroLine or Theme.GridMajor,
                BackgroundTransparency = isZero and 0.4 or 0.85,
                BorderSizePixel = 0,
                ZIndex = 1,
            })

            local labelText = string.format("%g", math.round(val * 1000) / 1000)
            elements["Label_" .. val] = Roact.createElement("TextLabel", {
                Size = UDim2.fromOffset(40, 15),
                Position = UDim2.fromOffset(5, screenY - 15),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = isZero and Theme.GraphEditor_ZeroLine or Theme.TextMuted,
                TextSize = 10,
                FontFace = Theme.FontMono,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 5,
            })
        end
    end

    -- CURVES AND KEYFRAMES
    local tracks = props.tracks
    local selection = props.selection.keyframes or {}
    local hasSelection = next(selection) ~= nil

    -- PERFORMANCE: Track which channels have drawn debug dots
    local debugDotsDrawn = {}

    if tracks then
        for trackId, trackData in pairs(tracks) do
            if trackData.type == "director" then continue end
            if isTrackVisible(trackId, tracks) then
                for _, prop in ipairs(trackData.properties) do
                    for channelName, channel in pairs(prop.channels or {}) do
                        local keyframes = channel.keyframes or {}
                        if not isNumericChannel(keyframes) then
                            continue
                        end

                        local color = getChannelColor(channelName)

                        local hasSelectedKF = false
                        if hasSelection then
                            for _, kf in ipairs(keyframes) do
                                if selection[kf.id] then
                                    hasSelectedKF = true
                                    break
                                end
                            end
                        end

                        local curveAlpha = (hasSelection and not hasSelectedKF) and 0.3 or 1.0
                        local dimmedColor = Color3.new(
                            color.R * curveAlpha,
                            color.G * curveAlpha,
                            color.B * curveAlpha
                        )

                        -- CHANNEL LABEL
                        if hasSelectedKF and #keyframes > 0 then
                            local totalY = 0
                            local visibleCount = 0

                            for _, kf in ipairs(keyframes) do
                                local pos = self:toScreen(kf.time, ensureNumber(kf.value), t)
                                if pos.X >= 0 and pos.X <= t.canvasWidth then
                                    totalY = totalY + pos.Y
                                    visibleCount = visibleCount + 1
                                end
                            end

                            if visibleCount > 0 then
                                local avgY = totalY / visibleCount
                                if avgY >= 20 and avgY <= t.canvasHeight - 20 then
                                    elements["ChannelLabel_" .. trackId .. "_" .. prop.name .. "_" .. channelName] = Roact.createElement("TextLabel", {
                                        Size = UDim2.fromOffset(150, 18),
                                        Position = UDim2.fromOffset(50, avgY - 9),
                                        BackgroundColor3 = Theme.ModalBG,
                                        BackgroundTransparency = 0.2,
                                        Text = " " .. trackData.name .. " › " .. prop.name .. " › " .. channelName,
                                        TextColor3 = color,
                                        TextSize = 10,
                                        FontFace = Theme.FontMedium,
                                        TextXAlignment = Enum.TextXAlignment.Left,
                                        TextTruncate = Enum.TextTruncate.AtEnd,
                                        ZIndex = 100,
                                    }, {
                                        Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 3) }),
                                        Roact.createElement("UIStroke", {
                                            Color = color,
                                            Thickness = 1,
                                            Transparency = 0.6
                                        })
                                    })
                                end
                            end
                        end

                        -- PERFORMANCE: Draw curves only for visible segments
                        for i = 1, #keyframes - 1 do
                            local kf = keyframes[i]
                            local nextKf = keyframes[i + 1]

                            -- CULLING: Skip if segment is completely outside visible range
                            if nextKf.time < (visibleStartTime - timeBuffer) or kf.time > (visibleEndTime + timeBuffer) then
                                continue
                            end

                            local mode = kf.interpolation or "Linear"

                            if mode == "Bezier" then
                                if not kf.handleRight then
                                    kf.handleRight = {x = HANDLE_LENGTH, y = 0}
                                end
                                if not nextKf.handleLeft then
                                    nextKf.handleLeft = {x = HANDLE_LENGTH, y = 0}
                                end

                                local val1 = ensureNumber(kf.value)
                                local val2 = ensureNumber(nextKf.value)

                                local p1 = self:toScreen(kf.time, val1, t)
                                local p2 = self:toScreen(nextKf.time, val2, t)

                                -- CULLING: Only draw if visible on screen
                                if (p1.X > -100 or p2.X > -100) and (p1.X < t.canvasWidth + 100 or p2.X < t.canvasWidth + 100) then
                                    local prevPoint = p1

                                    local screenDiff = (p2 - p1).Magnitude
                                    -- PERFORMANCE: Reduced segment count
                                    local adaptiveRes = math.clamp(math.ceil(screenDiff / 8), MIN_BEZIER_SEGMENTS, MAX_BEZIER_SEGMENTS)

                                    for stepIdx = 1, adaptiveRes do
                                        local alpha = stepIdx / adaptiveRes
                                        local worldPoint = RBezier.evaluate(alpha, kf, nextKf, true)
                                        local screenPoint = self:toScreen(worldPoint.X, worldPoint.Y, t)

                                        local diff = screenPoint - prevPoint
                                        local distance = diff.Magnitude
                                        local midpoint = prevPoint:Lerp(screenPoint, 0.5)
                                        local angle = math.deg(math.atan2(diff.Y, diff.X))

                                        elements["Curve_" .. kf.id .. "_" .. stepIdx] = Roact.createElement("Frame", {
                                            Size = UDim2.new(0, distance + 0.5, 0, 1.5),
                                            Position = UDim2.fromOffset(midpoint.X, midpoint.Y),
                                            Rotation = angle,
                                            AnchorPoint = Vector2.new(0.5, 0.5),
                                            BackgroundColor3 = dimmedColor,
                                            BorderSizePixel = 0,
                                            ZIndex = 2,
                                        })

                                        prevPoint = screenPoint
                                    end
                                end
                            else
                                -- Linear interpolation
                                local p1 = self:toScreen(kf.time, kf.value, t)
                                local p2 = self:toScreen(nextKf.time, nextKf.value, t)

                                local diff = p2 - p1
                                local distance = diff.Magnitude
                                local midpoint = p1:Lerp(p2, 0.5) 
                                local angle = math.deg(math.atan2(diff.Y, diff.X))

                                elements["Line_" .. kf.id] = Roact.createElement("Frame", {
                                    Size = UDim2.new(0, distance, 0, 1.5),
                                    Position = UDim2.fromOffset(midpoint.X, midpoint.Y),
                                    Rotation = angle,
                                    AnchorPoint = Vector2.new(0.5, 0.5),
                                    BackgroundColor3 = dimmedColor,
                                    BorderSizePixel = 0,
                                })
                            end
                        end

                        -- KEYFRAMES
                        for _, kf in ipairs(keyframes) do
                            local value = ensureNumber(kf.value)
                            local kfPos = self:toScreen(kf.time, value, t)

                            -- CULLING: Only render visible keyframes
                            if kfPos.X >= -20 and kfPos.X <= t.canvasWidth + 20 and kfPos.Y >= -20 and kfPos.Y <= t.canvasHeight + 20 then
                                local isSelected = selection[kf.id]
                                local isDimmed = hasSelection and not isSelected

                                -- HANDLES (only for selected keyframes)
                                if isSelected and kf.interpolation == "Bezier" then
                                    local mode = kf.tangentMode or "Free"
                                    local handleColor = getHandleColor(color, mode)

                                    local function drawHandle(side, direction)
                                        local handleData = kf["handle" .. side:gsub("^%l", string.upper)]
                                        if not handleData then return end

                                        local handleWorldPos = Vector2.new(
                                            kf.time + (handleData.x * direction),
                                            value + handleData.y
                                        )
                                        local handleScreenPos = self:toScreen(handleWorldPos.X, handleWorldPos.Y, t)

                                        local diff = handleScreenPos - kfPos
                                        local midpoint = kfPos:Lerp(handleScreenPos, 0.5)

                                        elements["HandleLine" .. side .. "_" .. kf.id] = Roact.createElement("Frame", {
                                            Size = UDim2.new(0, diff.Magnitude, 0, 1),
                                            Position = UDim2.fromOffset(midpoint.X, midpoint.Y),
                                            Rotation = math.deg(math.atan2(diff.Y, diff.X)),
                                            AnchorPoint = Vector2.new(0.5, 0.5),
                                            BackgroundColor3 = handleColor,
                                            BackgroundTransparency = 0.4,
                                            BorderSizePixel = 0,
                                            ZIndex = 8,
                                        })

                                        elements["HandlePoint" .. side .. "_" .. kf.id] = Roact.createElement("Frame", {
                                            Size = UDim2.fromOffset(8, 8),
                                            Position = UDim2.fromOffset(handleScreenPos.X, handleScreenPos.Y),
                                            AnchorPoint = Vector2.new(0.5, 0.5),
                                            BackgroundColor3 = Theme.GraphEditor_ZeroLine,
                                            ZIndex = 9,
                                        }, {
                                            Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
                                            Stroke = Roact.createElement("UIStroke", {
                                                Color = handleColor,
                                                Thickness = 1.5,
                                                ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                                            })
                                        })
                                    end

                                    drawHandle("right", 1)
                                    drawHandle("left", -1)
                                end

                                -- Keyframe point
                                elements["KF_" .. kf.id] = Roact.createElement("Frame", {
                                    Size = isSelected and UDim2.fromOffset(10, 10) or UDim2.fromOffset(6, 6),
                                    Position = UDim2.fromOffset(kfPos.X, kfPos.Y),
                                    AnchorPoint = Vector2.new(0.5, 0.5),
                                    BackgroundColor3 = isSelected and Theme.KeyframeSelected or (isDimmed and Theme.KeyframeEmpty or color),
                                    BackgroundTransparency = isDimmed and 0.5 or 0,
                                    ZIndex = isSelected and 15 or 10,
                                }, {
                                    Roact.createElement("UICorner", { CornerRadius = UDim.new(1, 0) }),
                                    isSelected and Roact.createElement("UIStroke", {
                                        Color = color,
                                        Thickness = 2,
                                    })
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    return Roact.createElement("Frame", {
        [Roact.Ref] = self.contentRef,
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.EditorBG,
        ClipsDescendants = true,
        Active = true,

        [Roact.Event.InputBegan] = function(rbx, input)
            local mousePos = Vector2.new(input.Position.X, input.Position.Y) - rbx.AbsolutePosition

            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                local handleKF, handleSide, handleProp, handleChannel, handleTrackId = self:getHandleAtMouse(mousePos, t)

                if handleKF and handleSide then
                    local otherSide = (handleSide == "right") and "left" or "right"
                    local otherHandle = handleKF["handle" .. otherSide:gsub("^%l", string.upper)]
                    local initialOtherMag = 1.0

                    if otherHandle then
                        initialOtherMag = math.sqrt(otherHandle.x^2 + otherHandle.y^2)
                    end

                    local worldX, worldY = self:toWorld(mousePos.X, mousePos.Y, t)
                    self:setState({
                        isDraggingHandle = true,
                        dragHandleData = {
                            kfId = handleKF.id,
                            side = handleSide,
                            propName = handleProp.name,
                            channelName = handleChannel,
                            trackId = handleTrackId,
                            originalHandle = handleSide == "right" and 
                                {x = handleKF.handleRight.x, y = handleKF.handleRight.y} or
                                {x = handleKF.handleLeft.x, y = handleKF.handleLeft.y},
                            kfTime = handleKF.time,
                            kfValue = ensureNumber(handleKF.value),
                            startMouseWorld = Vector2.new(worldX, worldY),
                            initialOtherMag = initialOtherMag
                        }
                    })
                    return
                end

                local kf, prop, channelName, trackId, track = self:getKFAtMouse(mousePos, t)

                if kf and prop then
                    local isShiftHeld = self.inputService:IsKeyDown(Enum.KeyCode.LeftShift) or 
                        self.inputService:IsKeyDown(Enum.KeyCode.RightShift)

                    if not props.selection.keyframes[kf.id] and not isShiftHeld then
                        if props.onKeyFrameSelection then
                            props.onKeyFrameSelection(kf.id, false)
                        end
                    end

                    local selectedKFs = self:getSelectedKeyframes()
                    local worldX, worldY = self:toWorld(mousePos.X, mousePos.Y, t)

                    self:setState({
                        isDraggingKF = true,
                        dragTargets = selectedKFs,
                        dragStartMouseWorld = Vector2.new(worldX, worldY),
                    })

                else
                    self:setState({
                        isSelecting = true,
                        selectionStartPos = Vector2.new(input.Position.X, input.Position.Y)
                    })
                end

            elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                self:setState({ isPanning = true })
            end
        end,

        [Roact.Event.InputChanged] = function(rbx, input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                local mousePos = Vector2.new(input.Position.X, input.Position.Y) - rbx.AbsolutePosition

                if self.state.isDraggingHandle and self.state.dragHandleData then
                    local data = self.state.dragHandleData
                    local curX, curY = self:toWorld(mousePos.X, mousePos.Y, t)

                    local deltaX = curX - data.kfTime
                    local deltaY = curY - data.kfValue

                    local kf = self:findKeyframeById(data.kfId)
                    if not kf then return end

                    local handleUpdates = processHandleDelta(kf, data.side, deltaX, deltaY, data.initialOtherMag)

                    if props.onHandleUpdate then
                        for side, newPos in pairs(handleUpdates) do
                            props.onHandleUpdate(
                                data.kfId,
                                side,
                                newPos,
                                data.propName,
                                data.channelName
                            )
                        end
                    end
                elseif self.state.isDraggingKF and self.state.dragStartMouseWorld then
                    local curX, curY = self:toWorld(mousePos.X, mousePos.Y, t)
                    local deltaX = curX - self.state.dragStartMouseWorld.X
                    local deltaY = curY - self.state.dragStartMouseWorld.Y

                    local isShiftHeld = self.inputService:IsKeyDown(Enum.KeyCode.LeftShift) or 
                        self.inputService:IsKeyDown(Enum.KeyCode.RightShift)

                    for _, target in ipairs(self.state.dragTargets) do
                        local newTime = math.max(0, target.originalTime + deltaX)
                        local newValue = target.originalValue + deltaY

                        if isShiftHeld then
                            newTime = snapValue(newTime, SNAP_TIME)
                            newValue = snapValue(newValue, SNAP_VALUE)
                        end

                        if props.onKeyframeUpdateFromGraph then
                            props.onKeyframeUpdateFromGraph(
                                target.kf.id,
                                { time = newTime, value = newValue },
                                target.prop.name,
                                target.channelName
                            )
                        end
                    end

                elseif self.state.isSelecting then
                    local sf = self.selectionRef:getValue()
                    if sf then
                        local start = self.state.selectionStartPos - rbx.AbsolutePosition
                        local delta = mousePos - start
                        sf.Visible = true
                        sf.Position = UDim2.fromOffset(math.min(start.X, mousePos.X), math.min(start.Y, mousePos.Y))
                        sf.Size = UDim2.fromOffset(math.abs(delta.X), math.abs(delta.Y))
                    end

                elseif self.state.isPanning then
                    local delta = input.Delta
                    local newPanX = (props.panX or 0) + delta.X
                    if (props.positionX - newPanX) < 0 then newPanX = props.positionX end

                    if props.onStateChange then
                        props.onStateChange("viewport", {panX = newPanX})
                        props.onStateChange("viewport", {panY = (props.panY or 0) + delta.Y})
                    end
                end

            elseif input.UserInputType == Enum.UserInputType.MouseWheel then
                local isZoomXArea = (input.Position.Y - rbx.AbsolutePosition.Y) > (t.canvasHeight * 0.8)
                if isZoomXArea then
                    if props.onZoomX then props.onZoomX(input.Position.Z, input.Position.X) end
                else
                    if props.onGraphZoom then props.onGraphZoom(input.Position.Z, input.Position.Y) end
                end
            end
        end,

        [Roact.Event.InputEnded] = function(rbx, input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if self.state.isSelecting then
                    local sf = self.selectionRef:getValue()
                    local newSelection = {}

                    if sf and tracks then
                        local tD = self:getTransformData()
                        local bPos = sf.AbsolutePosition - rbx.AbsolutePosition
                        local bSize = sf.AbsoluteSize

                        for _, track in pairs(tracks) do
                            if track.type == "director" then continue end
                            for _, p in ipairs(track.properties) do
                                for _, channel in pairs(p.channels or {}) do
                                    for _, kf in ipairs(channel.keyframes or {}) do
                                        local value = ensureNumber(kf.value)
                                        local pos = self:toScreen(kf.time, value, tD)

                                        if pos.X >= bPos.X and pos.X <= bPos.X + bSize.X and
                                            pos.Y >= bPos.Y and pos.Y <= bPos.Y + bSize.Y then
                                            newSelection[kf.id] = true
                                        end
                                    end
                                end
                            end
                        end

                        if props.onKeyFrameSelection then
                            props.onKeyFrameSelection(newSelection, true)
                        end
                    end
                end

                local sf = self.selectionRef:getValue()
                if sf then sf.Visible = false end

                self:setState({
                    isDraggingKF = false,
                    isDraggingHandle = false,
                    isSelecting = false,
                    dragTargets = {},
                    dragHandleData = nil,
                    dragStartMouseWorld = nil,
                })

            elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
                self:setState({ isPanning = false })
            end
        end,
    }, {
        SelectionBox = Roact.createElement("Frame", {
            [Roact.Ref] = self.selectionRef,
            BackgroundColor3 = Theme.SelectionBox,
            BackgroundTransparency = 0.8,
            Visible = false,
            ZIndex = 200,
        }, {
            Roact.createElement("UIStroke", {
                Color = Theme.SelectionBoxStroke,
                Thickness = 1,
            })
        }),

        HelpText = Roact.createElement("TextLabel", {
            Size = UDim2.fromOffset(250, 20),
            Position = UDim2.fromOffset(30, t.canvasHeight - 30),
            BackgroundTransparency = 1,
            Text = "SHIFT: Snap | Drag handles to adjust curves",
            TextColor3 = Theme.TextMuted,
            TextSize = 11,
            FontFace = Theme.FontMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 5,
        }),

        Elements = Roact.createFragment(elements)
    })
end

return GraphCanvas