local UserInputService = game:GetService("UserInputService")
local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local Ruler = Roact.Component:extend("Ruler")

local Theme = require(script.Parent.Parent.Parent.Themes.Theme)

function Ruler:init()
    self.state = {
        dragging = false,
    }

    self.viewportRef = Roact.createRef()
    self.contentRef = Roact.createRef()

    self.viewportWidth = 0
    self.contentWidth = 0
end

function Ruler:didMount()
    task.defer(function()
        local viewport = self.viewportRef:getValue()
        local content = self.contentRef:getValue()

        if viewport and content then
            self.viewportWidth = viewport.AbsoluteSize.X
            self.contentWidth = content.AbsoluteSize.X

            viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                self.viewportWidth = viewport.AbsoluteSize.X
            end)
            content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
                self.contentWidth = content.AbsoluteSize.X
            end)
        end
    end)
end

function Ruler:render()
    local divs = {}
    local PADDING_LEFT = 40
    local pps = self.props.pixelsPerSecond
    local fps = self.props.fps or 60
    
    local scrollPos = self.props.position
    local viewportWidth = self.viewportWidth

    -- [[ PERFORMANCE CULLING ]]
    local startTime = math.max(0, scrollPos / pps)
    local endTime = (scrollPos + viewportWidth) / pps

    local tickStep, labelInterval

    if pps > 200 then
        tickStep = 0.1
        labelInterval = 0.5
    elseif pps > 100 then
        tickStep = 0.1
        labelInterval = 1.0
    elseif pps > 60 then
        tickStep = 0.5
        labelInterval = 1.0 
    elseif pps > 30 then
        tickStep = 1
        labelInterval = 1
    elseif pps > 15 then
        tickStep = 2
        labelInterval = 2
    else
        tickStep = 5
        labelInterval = 5
    end

    local loopStart = math.floor(startTime / tickStep) * tickStep
    local loopEnd = math.min(self.props.totalSeconds, endTime + tickStep)

    local tickCount = 0
    for i = loopStart, loopEnd, tickStep do
        local isFullSecond = math.abs(i - math.floor(i + 0.5)) < 0.0001
        local posX = UDim2.new(0, i * pps - 1, 0, 0)

        local keyStr = tostring(math.floor(i * 1000)) 

        divs["tick_" .. keyStr] = Roact.createElement("Frame", {
            Size = UDim2.new(0, 1, 0, isFullSecond and 12 or 6),
            Position = posX,
            BackgroundColor3 = isFullSecond and Theme.GridMajor or Theme.RulerTick,
            ZIndex = 2,
        })

        local isLabelPoint = math.abs(i % labelInterval) < 0.0001

        if isLabelPoint then
            local frameNumber = math.floor(i * fps + 0.5)
            local labelText

            if pps > 100 then
                labelText = string.format("f%d", frameNumber)
            elseif pps > 50 then
                labelText = string.format("%.1fs", i)
            else
                labelText = string.format("%ds", math.floor(i))
            end

            divs["label_" .. keyStr] = Roact.createElement("TextLabel", {
                TextColor3 = Theme.TextMuted,
                ZIndex = 2,
                Position = UDim2.new(0, i * pps + 4, 0, 12),
                TextSize = 8,
                Text = labelText,
                Size = UDim2.new(0, 40, 0, 12),
                BackgroundTransparency = 1,
                TextXAlignment = Enum.TextXAlignment.Left
            })
        end
    end

    return Roact.createElement("Frame", {
        [Roact.Ref] = self.viewportRef,
        Name = "Viewport",
        Style = {
            s = UDim2.new(1, -350, 0, 30),
            ps = UDim2.new(0, 350, 0, 0),
            bg = Theme.RulerBG,
            z = 999,
            clip = true,
        },
        BorderSizePixel = 0,
        [Roact.Event.InputBegan] = function(rbx, input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                self.props.locks.isInternalUpdate = true
                self:setState({ dragging = true })

                local rulerAbsolutePosX = rbx.AbsolutePosition.X
                local relative = ((input.Position.X - rulerAbsolutePosX - PADDING_LEFT) + self.props.position) / self.props.pixelsPerSecond

                local moveConn, releaseConn
                local lastSnappedTime = nil

                moveConn = rbx.InputChanged:Connect(function(input2)
                    if input2.UserInputType == Enum.UserInputType.MouseMovement then
                        local currentPosition = input2.Position.X

                        local fps = self.props.fps or 60
                        local frameDuration = 1 / fps

                        local timeAtMouse = ((currentPosition - rulerAbsolutePosX - PADDING_LEFT) + self.props.position) / self.props.pixelsPerSecond
                        local clampedTime = math.clamp(timeAtMouse, 0, self.props.totalSeconds)

                        local snappedTime = math.floor(clampedTime / frameDuration + 0.5) * frameDuration

                        if snappedTime ~= lastSnappedTime then
                            lastSnappedTime = snappedTime
                            -- Lock is already set, safe to update
                            self.props.playbackController:setTime(snappedTime)
                            self.props.onStateChange("playback", {currentTime = snappedTime})
                        end
                    end
                end)

                releaseConn = rbx.InputEnded:Connect(function(input3)
                    if input3.UserInputType == Enum.UserInputType.MouseButton1 then
                        self:setState({ dragging = false })
                        moveConn:Disconnect()
                        releaseConn:Disconnect()

                        -- RELEASE THE LOCK AFTER SCRUBBING ENDS
                        task.defer(function()
                            self.props.locks.isInternalUpdate = false
                        end)
                    end
                end)

                -- Initial time set (lock already active)
                self.props.playbackController:setTime(relative)
                self.props.onStateChange("playback", {currentTime = relative})
            end            
        end
    }, {
        Content = Roact.createElement("Frame", {
            [Roact.Ref] = self.contentRef,
            Style = {
                s = UDim2.new(0, self.props.totalSeconds * self.props.pixelsPerSecond, 1, 0),
                opacity = 1,
                ps = UDim2.new(0, -self.props.position, 0, 0)
            }
        }, {
            Divs = Roact.createFragment(divs),
        }),

        BottomLine = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = Theme.BorderLight,
            BorderSizePixel = 0,
            ZIndex = 11,
        }),

        UIPadding = Roact.createElement("UIPadding", {
            PaddingLeft = UDim.new(0, PADDING_LEFT),
        })
    })
end

return Ruler