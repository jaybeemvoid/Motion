local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local RowTrack = Roact.Component:extend("RowTrack")
local Selection = game:GetService("Selection")

local Images = require(script.Parent.Parent.Parent.Assets.UI.Images)
local PropertyPicker = require(script.Parent.Parent.Widgets.PropertyPicker)

local PropertyTypes = require(script.Parent.Parent.Parent.Store.PropertyRegistery)

function RowTrack:init()
    self.textBoxRef = Roact.createRef()

    self:setState({
        showPropertyPicker = false
    })
end

local function getCurrentChannelValue(trackData, parentPropName, channelName, currentTime, keyframes)
    local currentValue = nil
    local valueType = nil

    for _, kf in ipairs(keyframes) do
        if math.abs(kf.time - currentTime) < 0.0001 then
            currentValue = kf.value
            valueType = type(kf.value)
            return currentValue, valueType
        end
    end

    if #keyframes > 0 then
        local kf0, kf1
        for i = 1, #keyframes do
            if keyframes[i].time <= currentTime then
                kf0 = keyframes[i]
                if i < #keyframes and keyframes[i + 1].time > currentTime then
                    kf1 = keyframes[i + 1]
                    break
                end
            else
                break
            end
        end

        if kf0 then
            valueType = type(kf0.value)
            if valueType == "boolean" or valueType == "string" then
                currentValue = kf0.value
            elseif kf1 and valueType == "number" then
                local alpha = (currentTime - kf0.time) / (kf1.time - kf0.time)
                currentValue = kf0.value + (kf1.value - kf0.value) * alpha
            else
                currentValue = kf0.value
            end
            return currentValue, valueType
        elseif keyframes[1] then
            currentValue = keyframes[1].value
            valueType = type(keyframes[1].value)
            return currentValue, valueType
        end
    end

    if trackData.instance then
        local success, fullValue = pcall(function()
            return trackData.instance[parentPropName]
        end)

        if success and fullValue ~= nil then
            local extractedValue = PropertyTypes.extractChannel(fullValue, channelName)
            if extractedValue ~= nil then
                currentValue = extractedValue
                valueType = type(currentValue)
                return currentValue, valueType
            end
        end
    end

    return nil, nil
end

function RowTrack:renderChannelInput(trackData, parentPropName, channelName, channelData, currentTime)
    local currentValue, valueType = getCurrentChannelValue(
        trackData, 
        parentPropName, 
        channelName, 
        currentTime, 
        channelData.keyframes or {}
    )

    if valueType == nil and trackData.instance then
        local success, fullValue = pcall(function()
            return trackData.instance[parentPropName]
        end)
        if success and fullValue ~= nil then
            local extractedValue = PropertyTypes.extractChannel(fullValue, channelName)
            if extractedValue ~= nil then
                currentValue = extractedValue
                valueType = type(extractedValue)
            end
        end
    end

    if valueType == "boolean" then
        if currentValue == nil then
            currentValue = false
        end

        return {
            PropertyText = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, -90, 1, 0),
                Position = UDim2.new(0, 0, 0, 0),
                Text = channelName,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            CheckboxButton = Roact.createElement("TextButton", {
                Size = UDim2.new(0, 60, 0, 18),
                Position = UDim2.new(1, -90, 0, 1),
                Text = tostring(currentValue),
                TextColor3 = currentValue and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100),
                BackgroundColor3 = Color3.fromRGB(40, 40, 40),
                BorderColor3 = Color3.fromRGB(80, 80, 80),
                BorderSizePixel = 1,
                TextSize = 11,
                Font = Enum.Font.Roboto,

                [Roact.Event.Activated] = function()
                    local latestValue, _ = getCurrentChannelValue(
                        trackData, 
                        parentPropName, 
                        channelName, 
                        currentTime, 
                        channelData.keyframes or {}
                    )

                    if latestValue == nil and trackData.instance then
                        local success, fullValue = pcall(function()
                            return trackData.instance[parentPropName]
                        end)
                        if success and fullValue ~= nil then
                            latestValue = PropertyTypes.extractChannel(fullValue, channelName)
                        end
                    end

                    if latestValue == nil then
                        latestValue = false
                    end

                    local newVal = not latestValue

                    self.props.createKeyFrame(
                        trackData.id, 
                        parentPropName, 
                        currentTime, 
                        newVal, 
                        channelName
                    )
                end,
            }),
            AddButton = Roact.createElement("TextButton", {
                Size = UDim2.new(0, 25, 0, 18),
                Position = UDim2.new(1, -25, 0, 1),
                Text = "+",
                TextColor3 = Color3.fromRGB(100, 200, 255),
                BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                BorderColor3 = Color3.fromRGB(80, 80, 80),
                BorderSizePixel = 1,
                TextSize = 14,
                Font = Enum.Font.SourceSansBold,

                [Roact.Event.Activated] = function()
                    local valueToAdd = currentValue

                    if trackData.instance then
                        local success, fullValue = pcall(function()
                            return trackData.instance[parentPropName]
                        end)
                        if success and fullValue ~= nil then
                            valueToAdd = PropertyTypes.extractChannel(fullValue, channelName)
                        end
                    end

                    if valueToAdd == nil then
                        valueToAdd = false
                    end

                    self.props.createKeyFrame(
                        trackData.id, 
                        parentPropName, 
                        currentTime, 
                        valueToAdd, 
                        channelName
                    )
                end,
            }),
        }
    end

    if valueType == "string" then
        local displayValue = tostring(currentValue or "")

        return {
            PropertyText = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, -90, 1, 0),
                Position = UDim2.new(0, 0, 0, 0),
                Text = channelName,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            ValueBox = Roact.createElement("TextBox", {
                Size = UDim2.new(0, 60, 0, 18),
                Position = UDim2.new(1, -90, 0, 1),
                Text = displayValue,
                TextColor3 = Color3.fromRGB(255, 255, 150),
                BackgroundColor3 = Color3.fromRGB(40, 40, 40),
                BorderColor3 = Color3.fromRGB(80, 80, 80),
                BorderSizePixel = 1,
                TextSize = 11,
                Font = Enum.Font.Code,
                ClearTextOnFocus = false,
                TextTruncate = Enum.TextTruncate.AtEnd,
                [Roact.Ref] = self.textBoxRef,

                [Roact.Event.FocusLost] = function(rbx, enterPressed)
                    if enterPressed then
                        local newValue = rbx.Text
                        self.props.createKeyFrame(
                            trackData.id, 
                            parentPropName, 
                            currentTime, 
                            newValue, 
                            channelName
                        )
                    else
                        rbx.Text = displayValue
                    end
                end,
            }),
            AddButton = Roact.createElement("TextButton", {
                Size = UDim2.new(0, 25, 0, 18),
                Position = UDim2.new(1, -25, 0, 1),
                Text = "+",
                TextColor3 = Color3.fromRGB(100, 200, 255),
                BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                BorderColor3 = Color3.fromRGB(80, 80, 80),
                BorderSizePixel = 1,
                TextSize = 14,
                Font = Enum.Font.SourceSansBold,

                [Roact.Event.Activated] = function()
                    local valueToAdd = currentValue or ""

                    if trackData.instance then
                        local success, fullValue = pcall(function()
                            return trackData.instance[parentPropName]
                        end)
                        if success and fullValue ~= nil then
                            valueToAdd = PropertyTypes.extractChannel(fullValue, channelName)
                        end
                    end

                    self.props.createKeyFrame(
                        trackData.id, 
                        parentPropName, 
                        currentTime, 
                        valueToAdd, 
                        channelName
                    )
                end,
            }),
        }
    end

    if currentValue == nil then
        currentValue = 0
    end

    local displayValue = typeof(currentValue) == "number" 
        and string.format("%.3f", currentValue) 
        or tostring(currentValue)

    return {
        PropertyText = Roact.createElement("TextLabel", {
            Size = UDim2.new(1, -90, 1, 0),
            Position = UDim2.new(0, 0, 0, 0),
            Text = channelName,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            TextXAlignment = Enum.TextXAlignment.Left,
        }),
        ValueBox = Roact.createElement("TextBox", {
            Size = UDim2.new(0, 60, 0, 18),
            Position = UDim2.new(1, -90, 0, 1),
            Text = displayValue,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundColor3 = Color3.fromRGB(40, 40, 40),
            BorderColor3 = Color3.fromRGB(80, 80, 80),
            BorderSizePixel = 1,
            TextSize = 12,
            Font = Enum.Font.Code,
            ClearTextOnFocus = false,
            [Roact.Ref] = self.textBoxRef,

            [Roact.Event.FocusLost] = function(rbx, enterPressed)
                if enterPressed then
                    local newValue = tonumber(rbx.Text)
                    if newValue then
                        self.props.createKeyFrame(
                            trackData.id, 
                            parentPropName, 
                            currentTime, 
                            newValue, 
                            channelName
                        )
                    else
                        rbx.Text = displayValue
                    end
                end
            end,
        }),
        AddButton = Roact.createElement("TextButton", {
            Size = UDim2.new(0, 25, 0, 18),
            Position = UDim2.new(1, -25, 0, 1),
            Text = "+",
            TextColor3 = Color3.fromRGB(100, 200, 255),
            BackgroundColor3 = Color3.fromRGB(50, 50, 50),
            BorderColor3 = Color3.fromRGB(80, 80, 80),
            BorderSizePixel = 1,
            TextSize = 14,
            Font = Enum.Font.SourceSansBold,

            [Roact.Event.Activated] = function()
                local valueToAdd = currentValue

                if trackData.instance then
                    local success, fullValue = pcall(function()
                        return trackData.instance[parentPropName]
                    end)
                    if success and fullValue ~= nil then
                        valueToAdd = PropertyTypes.extractChannel(fullValue, channelName)
                    end
                end

                self.props.createKeyFrame(
                    trackData.id, 
                    parentPropName, 
                    currentTime, 
                    valueToAdd, 
                    channelName
                )
            end,
        }),
    }
end

function RowTrack:render()
    local trackData = self.props.trackData
    local rowType = self.props.rowType

    local frameProps = {
        Size = self.props.Size or UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = (rowType == "header" or rowType == "director") and 0.7 or 1,
        BackgroundColor3 = (rowType == "header" or rowType == "director") and Color3.fromRGB(61, 61, 62) or nil,
        BorderSizePixel = 0,
    }

    if self.props.Position then
        frameProps.Position = self.props.Position
    end

    if self.props.layoutOrder then
        frameProps.LayoutOrder = self.props.layoutOrder
    end

    if rowType == "header" then
        return Roact.createElement("Frame", frameProps, {
            UIPadding = Roact.createElement("UIPadding", {
                PaddingLeft = UDim.new(0, self.props.indent),
            }),
            ExpandBtn = Roact.createElement("TextButton", {
                Size = UDim2.new(0, 30, 0, 20),
                Text = trackData.dataOpen and "v" or ">",
                TextColor3 = Color3.fromRGB(100, 200, 255),
                BackgroundTransparency = 1,
                [Roact.Event.Activated] = function()
                    self.props.toggleTrackExpansion(self.props.index, "dataOpen")
                end,
            }),
            Label = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, -30, 1, 0),
                Position = UDim2.new(0, 30, 0, 0),
                Text = trackData.name,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        })

    elseif rowType == "dataFolder" then
        return Roact.createElement("Frame", frameProps, {
            UIPadding = Roact.createElement("UIPadding", {
                PaddingLeft = UDim.new(0, self.props.indent),
            }),
            ExpandBtn = Roact.createElement("TextButton", {
                Size = UDim2.new(0, 30, 0, 20),
                Text = trackData.propertyListOpen and "v" or "<",
                TextColor3 = Color3.fromRGB(100, 200, 255),
                BackgroundTransparency = 1,
                [Roact.Event.Activated] = function()
                    self.props.toggleTrackExpansion(self.props.index, "propertyListOpen")
                end,
            }),
            AddProperty = Roact.createElement("TextButton", {
                Size = UDim2.fromOffset(20, 20),
                Position = UDim2.new(1, -25, 0, 0),
                Text = "+",
                TextColor3 = Color3.fromRGB(100, 200, 255),
                BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                BorderColor3 = Color3.fromRGB(80, 80, 80),
                BorderSizePixel = 1,
                TextSize = 14,
                Font = Enum.Font.Roboto,
                
                [Roact.Event.Activated] = function(rbx)
                    local absPos = rbx.AbsolutePosition
                    local absSize = rbx.AbsoluteSize

                    if self.props.openPropertyPicker then
                        self.props.openPropertyPicker({trackId = trackData.id})
                    end
                end
            }),
            PropertyPicker = self.state.showPropertyPicker and Roact.createElement(PropertyPicker, {
                track = trackData,
                onPropertySelected = function(propertyName)
                    local instance = trackData.instance
                    if not instance then return end

                    local success, value = pcall(function()
                        return instance[propertyName]
                    end)

                    if success then
                        self.props.createKeyFrame(
                            trackData.id,
                            propertyName,
                            self.props.currentTime,
                            value,
                            nil
                        )
                    end
                end,

            }),
            Label = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, -30, 1, 0),
                Position = UDim2.new(0, 30, 0, 0),
                Text = "Data",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        })

    elseif rowType == "property" then
        local prop = self.props.propertyData

        return Roact.createElement("Frame", frameProps, {
            UIPadding = Roact.createElement("UIPadding", {
                PaddingLeft = UDim.new(0, self.props.indent),
            }),
            ExpandBtn = Roact.createElement("TextButton", {
                Size = UDim2.new(0, 30, 0, 20),
                Text = prop.isExpanded and "<" or "v",
                TextColor3 = Color3.fromRGB(100, 200, 255),
                BackgroundTransparency = 1,
                [Roact.Event.Activated] = function()
                    self.props.onPropertyUiChange(self.props.trackData.id, prop.name, not prop.isExpanded)
                end,
            }),
            PropertyText = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, -60, 1, 0),
                Position = UDim2.new(0, 30, 0, 0),
                Text = prop.name,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        })

    elseif rowType == "channel" then
        local children = self:renderChannelInput(
            trackData,
            self.props.property,
            self.props.channelName,
            self.props.channelData,
            self.props.currentTime
        )

        return Roact.createElement("Frame", frameProps, {
            UIPadding = Roact.createElement("UIPadding", {
                PaddingLeft = UDim.new(0, self.props.indent),
            }),
            PropertyText = children.PropertyText,
            ValueBox = children.ValueBox,
            CheckboxButton = children.CheckboxButton,
            AddButton = children.AddButton,
        })
    elseif rowType == "director" then
        local director = self.props.trackData

        return Roact.createElement("Frame", frameProps, {
            UIPadding = Roact.createElement("UIPadding", {
                PaddingLeft = UDim.new(0, 5),
            }),
            ExpandBtn = Roact.createElement("TextButton", {
                Size = UDim2.new(0, 20, 0, 20),
                Position = UDim2.new(0, 0, 0, 0),
                Text = director.isExpanded and "v" or ">",
                TextColor3 = Color3.fromRGB(100, 200, 255),
                BackgroundTransparency = 1,
                [Roact.Event.Activated] = function()
                    self.props.toggleDirectorExpansion()
                end,
            }),
            Icon = Roact.createElement("ImageLabel", {
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.new(0, 25, 0.5, -8),
                Image = "rbxassetid://6034287525",
                BackgroundTransparency = 1,
            }),
            PreviewToggle = Roact.createElement("ImageButton", {
                Size = UDim2.fromOffset(16, 16),
                Position = UDim2.new(1, -40, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Image = Images.Eye,
                BackgroundTransparency = 1,

                [Roact.Event.Activated] = function()
                    self.props.toggleCameraPreview(not self.props.cameraPreviewActive)
                end,
            }, {
                Line = not self.props.cameraPreviewActive and Roact.createElement("Frame", {
                    Size = UDim2.new(0, 2, 1, 0),
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.fromScale(0.5, 0.5),
                    BorderSizePixel = 0,
                    BackgroundColor3 = Color3.fromRGB(255, 85, 70),
                    Rotation = 45,
                })    
            }),
            Label = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, -110, 1, 0),
                Position = UDim2.new(0, 45, 0, 0),
                Text = "Director",
                Font = Enum.Font.Roboto,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            AddClipBtn = Roact.createElement("TextButton", {
                Size = UDim2.fromOffset(20, 20),
                Position = UDim2.new(1, -25, 0.5, -10),
                Text = "+",
                TextColor3 = Color3.fromRGB(100, 200, 255),
                BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                BorderColor3 = Color3.fromRGB(80, 80, 80),
                BorderSizePixel = 1,
                TextSize = 14,
                Font = Enum.Font.Roboto,

                [Roact.Event.Activated] = function()
                    local duration = 2
                    local selectedObjects = game:GetService("Selection"):Get()
                    local activeCam = nil

                    for _, obj in ipairs(selectedObjects) do
                        if obj:IsA("BasePart") then
                            activeCam = obj
                            break
                        end
                    end

                    self.props.onAddClip(self.props.currentTime, self.props.currentTime + duration, activeCam)
                end,
            }),
        })

    elseif rowType == "directorProperty" then
        local prop = self.props.propertyData

        return Roact.createElement("Frame", frameProps, {
            UIPadding = Roact.createElement("UIPadding", {
                PaddingLeft = UDim.new(0, self.props.indent or 30),
            }),
            ExpandBtn = Roact.createElement("TextButton", {
                Size = UDim2.new(0, 30, 0, 20),
                Text = prop.expanded and "v" or ">",
                TextColor3 = Color3.fromRGB(100, 200, 255),
                BackgroundTransparency = 1,
                [Roact.Event.Activated] = function()
                    self.props.toggleDirectorProperty(self.props.clipId, self.props.propertyName)
                end,
            }),
            PropertyText = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, -30, 1, 0),
                Position = UDim2.new(0, 30, 0, 0),
                Text = self.props.propertyName,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
        })

    elseif rowType == "directorKeyframe" then
        local keyframe = self.props.keyframeData
        local clipStartTime = self.props.clipStartTime or 0
        local relativeTime = self.props.currentTime - clipStartTime

        local currentValue = keyframe.value
        local keyframes = self.props.allKeyframes or {}

        for i, kf in ipairs(keyframes) do
            if math.abs(kf.time - relativeTime) < 0.0001 then
                currentValue = kf.value
                break
            end
        end

        if #keyframes > 0 then
            local kf0, kf1
            for i = 1, #keyframes do
                if keyframes[i].time <= relativeTime then
                    kf0 = keyframes[i]
                    if i < #keyframes and keyframes[i + 1].time > relativeTime then
                        kf1 = keyframes[i + 1]
                        break
                    end
                end
            end

            if kf0 and kf1 then
                local alpha = (relativeTime - kf0.time) / (kf1.time - kf0.time)
                currentValue = kf0.value + (kf1.value - kf0.value) * alpha
            elseif kf0 then
                currentValue = kf0.value
            end
        end

        local displayValue = string.format("%.3f", currentValue or 0)

        return Roact.createElement("Frame", frameProps, {
            UIPadding = Roact.createElement("UIPadding", {
                PaddingLeft = UDim.new(0, self.props.indent or 45),
            }),
            PropertyText = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, -90, 1, 0),
                Position = UDim2.new(0, 0, 0, 0),
                Text = "Value",
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left,
            }),
            ValueBox = Roact.createElement("TextBox", {
                Size = UDim2.new(0, 60, 0, 18),
                Position = UDim2.new(1, -90, 0, 1),
                Text = displayValue,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundColor3 = Color3.fromRGB(40, 40, 40),
                BorderColor3 = Color3.fromRGB(80, 80, 80),
                BorderSizePixel = 1,
                TextSize = 12,
                Font = Enum.Font.Code,
                ClearTextOnFocus = false,

                [Roact.Event.FocusLost] = function(rbx, enterPressed)
                    if enterPressed then
                        local newValue = tonumber(rbx.Text)
                        if newValue and self.props.onDirectorKeyframeUpdate then
                            self.props.onDirectorKeyframeUpdate(
                                self.props.clipId,
                                self.props.propertyName,
                                relativeTime,
                                newValue
                            )
                        else
                            rbx.Text = displayValue
                        end
                    end
                end,
            }),
            AddButton = Roact.createElement("TextButton", {
                Size = UDim2.new(0, 25, 0, 18),
                Position = UDim2.new(1, -25, 0, 1),
                Text = "+",
                TextColor3 = Color3.fromRGB(100, 200, 255),
                BackgroundColor3 = Color3.fromRGB(50, 50, 50),
                BorderColor3 = Color3.fromRGB(80, 80, 80),
                BorderSizePixel = 1,
                TextSize = 14,
                Font = Enum.Font.SourceSansBold,

                [Roact.Event.Activated] = function()
                    if self.props.onDirectorKeyframeUpdate then
                        self.props.onDirectorKeyframeUpdate(
                            self.props.clipId,
                            self.props.propertyName,
                            relativeTime,
                            currentValue or 0
                        )
                    end
                end,
            }),
        })
    end
end

return RowTrack