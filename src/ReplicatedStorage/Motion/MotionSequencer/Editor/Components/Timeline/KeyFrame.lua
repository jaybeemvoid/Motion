local RunService = game:GetService("RunService")
local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local KeyFrame = Roact.Component:extend("KeyFrame")


local Theme = require(script.Parent.Parent.Parent.Themes.Theme)

function KeyFrame:init()
    self.alpha, self.setAlpha = Roact.createBinding(0)
    self.time, self.setTime = Roact.createBinding(self.props.time)
    self.currentAlpha = 0
    self.moveConn, self.releaseConn = nil
end

function KeyFrame:animateTo(target)
    if self.conn then self.conn:Disconnect() end
    self.conn = RunService.RenderStepped:Connect(function(dt)
        local step = dt * 20
        local diff = target - self.currentAlpha
        if math.abs(diff) < 0.01 then
            self.currentAlpha = target
            self.setAlpha(target)
            self.conn:Disconnect()
            self.conn = nil
        else
            self.currentAlpha = self.currentAlpha + (diff * step)
            self.setAlpha(self.currentAlpha)
        end
    end)
end

function KeyFrame:didUpdate(prevProps)
    if prevProps.isSelected ~= self.props.isSelected then
        self:animateTo(self.props.isSelected and 1 or 0)
    end
    if prevProps.time ~= self.props.time then
        self.setTime(self.props.time)
    end
end

function KeyFrame:render()
    local pps = self.props.pps
    local isSelected = self.props.isSelected

    local baseColor = Theme.KeyframeBase
    local selectedColor = Theme.KeyframeSelected 
    local borderBase = Theme.BorderLight
    local borderSelected = Theme.Accent

    local diamondColor = self.alpha:map(function(a)
        return baseColor:Lerp(selectedColor, a)
    end)

    local borderColor = self.alpha:map(function(a)
        return borderBase:Lerp(borderSelected, a)
    end)

    local borderThickness = self.alpha:map(function(a)
        return 1 + (a * 0.5)
    end)

    local diamondSize = self.alpha:map(function(a)
        return 8 + (a * 1)
    end)

    local position = self.time:map(function(a)
        return UDim2.new(0, math.floor(a * pps), 0.5, 0)
    end)

    return Roact.createElement("Frame", {
        Size = diamondSize:map(function(s) return UDim2.fromOffset(s, s) end),
        Position = position,
        BackgroundColor3 = diamondColor,
        ZIndex = isSelected and 75 or 50,
        Rotation = 45,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Active = true,
        BorderSizePixel = 0,

        [Roact.Event.MouseEnter] = function(rbx)
            if not isSelected then self:animateTo(0.5) end
        end,
        [Roact.Event.MouseLeave] = function(rbx)
            if not isSelected then self:animateTo(0) end
        end,

        [Roact.Event.InputBegan] = function(rbx, input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                if self.props.onStateChange then
                    self.props.onStateChange("ui", {isInputHandledByUI = true})
                end

                local UserInputService = game:GetService("UserInputService")
                local isShiftHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
                local isCtrlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) 
                    or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

                local isAlreadySelected = self.props.isSelected

                if self.props.onKeyFrameSelection then
                    if isAlreadySelected and not isShiftHeld and not isCtrlHeld then
                    elseif isShiftHeld then
                        self.props.onKeyFrameSelection({[self.props.id] = true}, "Add")
                    elseif isCtrlHeld then
                        if isAlreadySelected then 
                            local newSelection = {}
                            for kfId, _ in pairs(self.props.selection or {}) do
                                if kfId ~= self.props.id then
                                    newSelection[kfId] = true
                                end
                            end
                            self.props.onKeyFrameSelection(newSelection, "Replace")
                        else
                            self.props.onKeyFrameSelection({[self.props.id] = true}, "Add")
                        end
                    else
                        self.props.onKeyFrameSelection({[self.props.id] = true}, "Replace")
                    end
                end
            end
        end,
    }, {
        UIStroke = Roact.createElement("UIStroke", {
            Color = borderColor,
            Thickness = borderThickness,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }),

        UICorner = Roact.createElement("UICorner", {
            CornerRadius = UDim.new(0, 1),
        }),

        InnerCore = isSelected and Roact.createElement("Frame", {
            Size = UDim2.new(0.45, 0, 0.45, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            ZIndex = isSelected and 76 or 51,
        }, {
            UICorner = Roact.createElement("UICorner", {
                CornerRadius = UDim.new(0, 1),
            })
        }) or nil,
    })
end

function KeyFrame:shouldUpdate(nextProps)
    return nextProps.isSelected ~= self.props.isSelected 
        or nextProps.time ~= self.props.time
        or nextProps.pps ~= self.props.pps
end

function KeyFrame:willUnmount()
    if self.conn then self.conn:Disconnect() end
end

return KeyFrame