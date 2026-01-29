local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local LaneComponent = Roact.Component:extend("LaneComponent")
local KeyFrame = require(script.Parent.KeyFrame)

--[[Helpers]]
local function getUniqueKeyframeTimes(propertyData)
    local uniqueTimes = {}

    if propertyData.channels then
        for _, channel in pairs(propertyData.channels) do
            if channel.keyframes then
                for _, kf in ipairs(channel.keyframes) do
                    uniqueTimes[kf.time] = true
                end
            end
        end
    end

    return uniqueTimes
end

function LaneComponent:render()
    local rowType = self.props.rowType
    local pixelsPerSecond = self.props.pixelsPerSecond or 50
    local totalSeconds = self.props.totalSeconds or 30
    local totalWidth = totalSeconds * pixelsPerSecond

    local yPosition = self.props.yPosition or 0
    local height = self.props.height or 20

    if rowType == "header" then
        return Roact.createElement("Frame", {
            Size = UDim2.new(0, totalWidth, 0, height),
            Position = UDim2.new(0, 0, 0, yPosition),
            BackgroundTransparency = 1,
        })

    elseif rowType == "dataFolder" then
        return Roact.createElement("Frame", {
            Size = UDim2.new(0, totalWidth, 0, height),
            Position = UDim2.new(0, 0, 0, yPosition),
            BackgroundTransparency = 0.7,
            BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        })

    elseif rowType == "property" then
        local summaryDots = {}
        local propertyData = self.props.propertyData

        local uniqueTimes = getUniqueKeyframeTimes(self.props.propertyData)

        for time, _ in pairs(uniqueTimes) do
            local key = "Summary_" .. time
            summaryDots[key] = Roact.createElement("Frame", {
                Position = UDim2.new(0, time * self.props.pixelsPerSecond, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(8, 8),
                Rotation = 45,
                BackgroundColor3 = Color3.fromRGB(200, 200, 200),
                BorderSizePixel = 0,
            }, {
                Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 2) })
            })
        end

        return Roact.createElement("Frame", {
            Size = UDim2.new(0, totalWidth, 0, height),
            Position = UDim2.new(0, 0, 0, yPosition),
            BackgroundTransparency = 1,
        }, {
            HorizontalLine = Roact.createElement("Frame", {
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 0.9,
                BorderSizePixel = 0,
                ZIndex = 0,
            }),
            KeyFrames = not propertyData.isExpanded and Roact.createFragment(summaryDots) or nil
        })

    elseif rowType == "channel" then
        local prop = self.props.propertyData
        local channelName = self.props.channelName
        local keyFrameComponents = {}

        local targetChannel = prop.channels and prop.channels[channelName]
        local selectionTable = self.props.selection.keyframes or {}

        if targetChannel and targetChannel.keyframes then
            for _, kf in ipairs(targetChannel.keyframes) do
                local isSelected = selectionTable[kf.id] ~= nil

                keyFrameComponents[kf.id] = Roact.createElement(KeyFrame, {
                    time = kf.time,
                    pps = pixelsPerSecond,
                    isSelected = isSelected,
                    onKeyFrameSelection = self.props.onKeyFrameSelection,
                    onKeyframeMove = self.props.onKeyframeMove,
                    id = kf.id,
                    selection = selectionTable,
                    isInputHandledByUI = self.props.isInputHandledByUI,
                    onStateChange = self.props.onStateChange,
                })
            end
        end

        return Roact.createElement("Frame", {
            Size = UDim2.new(0, totalWidth, 0, height),
            Position = UDim2.new(0, 0, 0, yPosition),
            BackgroundTransparency = 1,
        }, {
            HorizontalLine = Roact.createElement("Frame", {
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 0.9,
                BorderSizePixel = 0,
                ZIndex = 0,
            }),
            KeyFrames = Roact.createFragment(keyFrameComponents)
        })
    elseif rowType == "director" then
        local clipComponents = {}
        local directorData = self.props.directorData
        local clipSelection = self.props.clipSelection or {}

        if directorData and directorData.clips then
            for _, clip in ipairs(directorData.clips) do
                local startX = clip.startTime * pixelsPerSecond
                local durationWidth = (clip.endTime - clip.startTime) * pixelsPerSecond
                local isSelected = clipSelection[clip.id] ~= nil

                clipComponents[clip.id] = Roact.createElement("Frame", {
                    Position = UDim2.new(0, startX, 0, 2),
                    Size = UDim2.new(0, durationWidth, 1, -4),
                    BackgroundColor3 = clip.color or Color3.fromRGB(70, 100, 150),
                    BorderSizePixel = isSelected and 2 or 1,
                    BorderColor3 = isSelected and Color3.fromRGB(100, 200, 255) or Color3.new(1, 1, 1),
                    ZIndex = isSelected and 10 or 5,

                    [Roact.Event.InputBegan] = function(rbx, input)
                        if input.UserInputType == Enum.UserInputType.MouseButton1 then
                            if self.props.onStateChange then
                                    self.props.onStateChange("ui", {isInputHandledByUI = true})
                            end

                            local isShiftHeld = game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftShift)
                            local startMouseX = input.Position.X
                            local clipStartX = rbx.AbsolutePosition.X
                            local clipEndX = clipStartX + rbx.AbsoluteSize.X

                            local edgeThreshold = 12
                            
                            local distanceFromLeft = math.abs(startMouseX - clipStartX)
                            local distanceFromRight = math.abs(startMouseX - clipEndX)

                            local resizeMode = nil

                            if distanceFromLeft <= edgeThreshold then
                                resizeMode = "left"
                            elseif distanceFromRight <= edgeThreshold then
                                resizeMode = "right"
                            end

                            if self.props.selectClip then
                                self.props.selectClip(clip.id, isShiftHeld)
                            end
                            


                            local initialStartTime = clip.startTime
                            local initialEndTime = clip.endTime
                            local hasMoved = false

                            local moveConnection
                            local releaseConnection
                            
                            self.props.onStateChange("playback", {currentTime = clip.startTime})
                            
                            moveConnection = rbx.InputChanged:Connect(function(input2)
                                if input2.UserInputType == Enum.UserInputType.MouseMovement then
                                    local currentMouseX = input2.Position.X
                                    local deltaX = currentMouseX - startMouseX
                                    local deltaTime = deltaX / pixelsPerSecond

                                    hasMoved = math.abs(deltaX) > 3

                                    if resizeMode == "left" then
                                        local newStartTime = math.max(0, initialStartTime + deltaTime)

                                        if (initialEndTime - newStartTime) >= 0.1 then
                                            if self.props.onClipResize then
                                                self.props.onClipResize(clip.id, "start", newStartTime)
                                            end
                                        end

                                    elseif resizeMode == "right" then
                                        local newEndTime = math.max(initialStartTime + 0.1, initialEndTime + deltaTime)

                                        if self.props.onClipResize then
                                            self.props.onClipResize(clip.id, "end", newEndTime)
                                        end

                                    else
                                        local newStartTime = math.max(0, initialStartTime + deltaTime)
                                        local duration = initialEndTime - initialStartTime
                                        local newEndTime = newStartTime + duration

                                        if self.props.onClipMove then
                                            self.props.onClipMove(clip.id, newStartTime, newEndTime)
                                        end
                                    end
                                end
                            end)

                            releaseConnection = rbx.InputEnded:Connect(function(endInput)
                                if endInput.UserInputType == Enum.UserInputType.MouseButton1 then
                                    if moveConnection then moveConnection:Disconnect() end
                                    if releaseConnection then releaseConnection:Disconnect() end
                                    if self.props.onStateChange then
                                        self.props.onStateChange("ui", {isInputHandledByUI = false})
                                    end
                                end
                            end)
                        end
                    end,

                    [Roact.Event.MouseEnter] = function(rbx)
                        rbx.BackgroundColor3 = Color3.fromRGB(90, 120, 170)
                    end,

                    [Roact.Event.MouseLeave] = function(rbx)
                        rbx.BackgroundColor3 = clip.color or Color3.fromRGB(70, 100, 150)
                    end,
                }, {
                    Corner = Roact.createElement("UICorner", { CornerRadius = UDim.new(0, 4) }),

                    Title = Roact.createElement("TextLabel", {
                        Size = UDim2.new(1, -10, 1, 0),
                        Position = UDim2.new(0, 5, 0, 0),
                        Text = clip.cameraName,
                        TextColor3 = Color3.new(1, 1, 1),
                        TextSize = 13,
                        Font = Enum.Font.Roboto,
                        BackgroundTransparency = 1,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Center,
                        ClipsDescendants = true,
                    }, {
                        UIPadding = Roact.createElement("UIPadding", {
                            PaddingLeft = UDim.new(0, 7)
                        })    
                    }),

                    LeftHandle = isSelected and Roact.createElement("Frame", {
                        Size = UDim2.new(0, 4, 1, 0),
                        Position = UDim2.new(0, 0, 0, 0),
                        BackgroundColor3 = Color3.fromRGB(100, 200, 255),
                        BorderSizePixel = 0,
                        ZIndex = 11,
                    }) or nil,

                    RightHandle = isSelected and Roact.createElement("Frame", {
                        Size = UDim2.new(0, 4, 1, 0),
                        Position = UDim2.new(1, -4, 0, 0),
                        BackgroundColor3 = Color3.fromRGB(100, 200, 255),
                        BorderSizePixel = 0,
                        ZIndex = 11,
                    }) or nil,
                })
            end
        end

        return Roact.createElement("Frame", {
            Size = UDim2.new(0, totalWidth, 0, height),
            Position = UDim2.new(0, 0, 0, yPosition),
            BackgroundTransparency = 0.9,
            BackgroundColor3 = Color3.fromRGB(30, 30, 35),
            BorderSizePixel = 0,
        }, clipComponents)
    elseif rowType == "directorProperty" then
        return Roact.createElement("Frame", {
            Size = UDim2.new(0, totalWidth, 0, height),
            Position = UDim2.new(0, 0, 0, yPosition),
            BackgroundTransparency = 0.95,
            BackgroundColor3 = Color3.fromRGB(35, 35, 38),
        }, {
            HorizontalLine = Roact.createElement("Frame", {
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 0.9,
                BorderSizePixel = 0,
                ZIndex = 0,
            }),
        })

    elseif rowType == "directorKeyframe" then
        local propertyData = self.props.propertyData
        local clipStartTime = self.props.clipStartTime or 0
        local clipEndTime = self.props.clipEndTime or 0
        local keyFrameComponents = {}
        
        local selectionTable = self.props.selection or {}

        if propertyData and propertyData.keyframes then
            for _, kf in ipairs(propertyData.keyframes) do
                local absoluteTime = clipStartTime + kf.time

                if kf.time >= 0 and kf.time <= (clipEndTime - clipStartTime) then
                    local isSelected = selectionTable[kf.id] ~= nil

                    keyFrameComponents[kf.id] = Roact.createElement(KeyFrame, {
                        time = absoluteTime,
                        pps = pixelsPerSecond,
                        isSelected = isSelected,
                        onKeyFrameSelection = self.props.onKeyFrameSelection,
                        onKeyframeMove = self.props.onKeyframeMove,
                        id = kf.id,
                        selection = selectionTable,
                        isInputHandledByUI = self.props.isInputHandledByUI,
                        onStateChange = self.props.onStateChange,
                    })
                end
            end
        end

        return Roact.createElement("Frame", {
            Size = UDim2.new(0, totalWidth, 0, height),
            Position = UDim2.new(0, 0, 0, yPosition),
            BackgroundTransparency = 1,
        }, {
            HorizontalLine = Roact.createElement("Frame", {
                Position = UDim2.new(0, 0, 0.5, 0),
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 0.9,
                BorderSizePixel = 0,
                ZIndex = 0,
            }),
            KeyFrames = Roact.createFragment(keyFrameComponents)
        })
    end
end

return LaneComponent