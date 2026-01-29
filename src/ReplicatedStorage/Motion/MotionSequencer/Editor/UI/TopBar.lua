local Roact = require(script.Parent.Parent.Parent.Roact)
local TopBar = Roact.Component:extend("TopBar")
local Images = require(script.Parent.Parent.Assets.UI.Images)

local dropDownComponent = require(script.Parent.Parent.Components.Timeline.Dropdown)

local Menus = require(script.Parent.Parent.Store.Menus)

local Themes = require(script.Parent.Parent.Themes.Theme)

local function formatTime(seconds, fps)
    local totalFrames = math.floor((seconds * fps) + 0.0001)

    local mins = math.floor(totalFrames / (60 * 24))
    local secs = math.floor(totalFrames / fps) % 60
    local frames = totalFrames % fps

    return string.format("%02d:%02d:%02d", mins, secs, frames)
end

function TopBar:init()
    self.state = {
        activeMenu = nil,
    }
    self.menuButtonRefs = {}
    self.hoverTimer = nil
end

function TopBar:closeMenu()
    if self.hoverTimer then
        task.cancel(self.hoverTimer)
        self.hoverTimer = nil
    end
    self:setState({ activeMenu = Roact.None })
end

function TopBar:openMenu(menuName)
    if self.hoverTimer then
        task.cancel(self.hoverTimer)
        self.hoverTimer = nil
    end
    self:setState({ activeMenu = menuName })
end

function TopBar:scheduleClose()
    if self.hoverTimer then
        task.cancel(self.hoverTimer)
    end

    self.hoverTimer = task.delay(0.2, function()
        if self.hoverTimer then
            self.hoverTimer = nil
            task.spawn(function()
                self:setState({ activeMenu = nil })
            end)
        end
    end)
end

function TopBar:cancelClose()
    if self.hoverTimer then
        task.cancel(self.hoverTimer)
        self.hoverTimer = nil
    end
end

function TopBar:renderDropdown(name, options)
    local children = {
        Layout = Roact.createElement("UIListLayout", {
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
    }

    for i, option in ipairs(options) do
        children[option.Text .. i] = Roact.createElement(dropDownComponent, {
            Option = option,
            LayoutOrder = i * 2,
            OnActivated = function()
                task.defer(function()
                    self:closeMenu()
                end)
            end
        })

        if i < #options and options[i + 1].Divider then
            children["Divider" .. i] = Roact.createElement("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Themes.BorderLight,
                BorderSizePixel = 0,
                LayoutOrder = (i * 2) + 1,
            })
        end
    end

    local xPos = 0
    local buttonRef = self.menuButtonRefs[name]
    if buttonRef then
        xPos = buttonRef.AbsolutePosition.X - buttonRef.Parent.AbsolutePosition.X
    end

    return Roact.createElement("Frame", {
        Position = UDim2.fromOffset(xPos, 32),
        Size = UDim2.fromOffset(200, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Themes.ModalBG,
        BorderSizePixel = 1,
        BorderColor3 = Themes.BorderDark,
        ZIndex = 1000,
        [Roact.Event.MouseEnter] = function()
            self:cancelClose()
        end,
        [Roact.Event.MouseLeave] = function()
            self:scheduleClose()
        end,
    }, children)
end

function TopBar:renderMenuButton(text, menuName, layoutOrder)
    local isActive = self.state.activeMenu == menuName

    return Roact.createElement("TextButton", {
        Text = text,
        Size = UDim2.fromOffset(50, 32),
        TextColor3 = isActive and Themes.TextMain or Themes.TextDim,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        FontFace = Themes.FontNormal,
        TextSize = 14,
        AutoButtonColor = false,
        LayoutOrder = layoutOrder,
        [Roact.Event.MouseEnter] = function()
            if self.state.activeMenu == nil then
                self:openMenu(menuName)
            elseif self.state.activeMenu ~= menuName then
                self:openMenu(menuName)
            else
                self:cancelClose()
            end
        end,
        [Roact.Event.MouseLeave] = function()
            self:scheduleClose()
        end,
        [Roact.Event.Activated] = function()
            if self.state.activeMenu == menuName then
                self:closeMenu()
            else
                self:openMenu(menuName)
            end
        end,
        [Roact.Ref] = function(rbx)
            if rbx then self.menuButtonRefs[menuName] = rbx end
        end,
    })
end

function TopBar:renderIconButton(imageName, callback, size, layoutOrder)
    size = size or 24

    return Roact.createElement("ImageButton", {
        Image = Images[imageName] or "",
        Size = UDim2.fromOffset(size, size),
        BackgroundTransparency = 1,
        ImageColor3 = Themes.TextMain,
        AutoButtonColor = false,
        LayoutOrder = layoutOrder,
        [Roact.Event.MouseEnter] = function(rbx)
            rbx.ImageColor3 = Themes.Accent
        end,
        [Roact.Event.MouseLeave] = function(rbx)
            rbx.ImageColor3 = Themes.TextMain
        end,
        [Roact.Event.Activated] = callback
    })
end

function TopBar:render()
    local menus = Menus(self.props)
    local isDirty = self.props.isDirty 
    local projectName = self.props.projectName or "Untitled"
    local activeMenu = self.state.activeMenu

    return Roact.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Themes.TopbarBG,
        BorderSizePixel = 0,
        ZIndex = 100,
        ClipsDescendants = false,
    }, {
        Handler = activeMenu and Roact.createElement("TextButton", {
            Size = UDim2.new(10, 0, 10, 0),
            Position = UDim2.fromScale(0.5, 0.5),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 99,
            [Roact.Event.Activated] = function()
                task.defer(function()
                    self:closeMenu()
                end)
            end,
        }),

        BottomBorder = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            Position = UDim2.new(0, 0, 1, -1),
            BackgroundColor3 = Themes.BorderLight,
            BorderSizePixel = 0,
        }),

        LeftContainer = Roact.createElement("Frame", {
            Size = UDim2.fromOffset(200, 32),
            BackgroundTransparency = 1,
            ClipsDescendants = false,
            ZIndex = 101,
        }, {
            Layout = Roact.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),

            FileBtn = self:renderMenuButton("File", "File", 1),
            EditBtn = self:renderMenuButton("Edit", "Edit", 2),
            ViewBtn = self:renderMenuButton("View", "View", 3),
            HelpBtn = self:renderMenuButton("Help", "Help", 5),
        }),

        DropdownContainer = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 1, 500),
            Position = UDim2.fromOffset(0, 0),
            BackgroundTransparency = 1,
            ZIndex = 1001,
            ClipsDescendants = false,
        }, {
            ActiveMenu = activeMenu and self:renderDropdown(activeMenu, 
                activeMenu == "File" and menus.File 
                    or activeMenu == "Edit" and menus.Edit 
                    or activeMenu == "View" and menus.View
                    or activeMenu == "Help" and menus.Help
            ) or nil
        }),

        CenterContainer = Roact.createElement("Frame", {
            Size = UDim2.fromScale(0.5, 1),
            Position = UDim2.fromScale(0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundTransparency = 1,
        }, {
            Layout = Roact.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 16),
            }),

            ProjectName = Roact.createElement("TextLabel", {
                Size = UDim2.fromOffset(150, 20),
                Text = projectName .. (isDirty and " •" or ""),
                TextColor3 = Themes.TextMain,
                Font = Enum.Font.SourceSans,
                TextSize = 14,
                BackgroundTransparency = 1,
                TextTruncate = Enum.TextTruncate.AtEnd,
            }),

            Separator = Roact.createElement("Frame", {
                Size = UDim2.fromOffset(1, 20),
                BackgroundColor3 = Themes.Separator,
                BorderSizePixel = 0,
            }),

            Controls = Roact.createElement("Frame", {
                Size = UDim2.fromOffset(100, 32),
                BackgroundTransparency = 1,
            }, {
                Layout = Roact.createElement("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Padding = UDim.new(0, 8),
                }),

                ToStart = self:renderIconButton("ToStart", function() 
                    if self.props.onStateChange and not self.props.isPlaying then
                        self.props.onStateChange("playback", {currentTime = 0})
                        self.props.playbackController:setTime(0)
                    end
                end, 20, 2),

                Play = self:renderIconButton(
                    self.props.isPlaying and "Pause" or "Play",
                    function()
                        if self.props.onStateChange then
                            self.props.onStateChange("playback", {isPlaying = not self.props.isPlaying})
                        end
                    end,
                    20,
                    1
                ),

                ToEnd = self:renderIconButton("ToEnd", function() 
                    if self.props.onStateChange and not self.props.isPlaying then
                        self.props.onStateChange("playback", {currentTime= self.props.totalSeconds})
                        self.props.playbackController:setTime(self.props.totalSeconds)
                    end
                end, 20, 3),
            })
        }),

        RightContainer = Roact.createElement("Frame", {
            Size = UDim2.fromOffset(300, 32),
            Position = UDim2.new(1, -8, 0, 0),
            AnchorPoint = Vector2.new(1, 0),
            BackgroundTransparency = 1,
        }, {
            Layout = Roact.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Horizontal,
                HorizontalAlignment = Enum.HorizontalAlignment.Right,
                VerticalAlignment = Enum.VerticalAlignment.Center,
                Padding = UDim.new(0, 12),
            }),

            TimeLabel = Roact.createElement("TextLabel", {
                Size = UDim2.fromOffset(85, 20),
                Text = formatTime(self.props.currentTime or 0, self.props.fps or 60),
                TextColor3 = Themes.TextMain,
                BackgroundTransparency = 1,
                Font = Enum.Font.Code,
                TextSize = 14,
            }),

            Separator1 = Roact.createElement("Frame", {
                Size = UDim2.fromOffset(1, 20),
                BackgroundColor3 = Themes.Separator,
                BorderSizePixel = 0,
            }),

            SnapToggle = Roact.createElement("ImageButton", {
                Image = Images.Magnet or "",
                Size = UDim2.fromOffset(20, 20),
                BackgroundTransparency = 1,
                ImageColor3 = self.props.snapEnabled and Themes.Accent or Themes.TextDim,
                AutoButtonColor = false,
                [Roact.Event.MouseEnter] = function(rbx)
                    rbx.ImageColor3 = Themes.Accent
                end,
                [Roact.Event.MouseLeave] = function(rbx)
                    rbx.ImageColor3 = self.props.snapEnabled and Themes.Accent or Themes.TextDim
                end,
                [Roact.Event.Activated] = function()
                    if self.props.onStateChange then
                        self.props.onStateChange("snapEnabled", not self.props.snapEnabled)
                    end
                end
            }),

            Separator2 = Roact.createElement("Frame", {
                Size = UDim2.fromOffset(1, 20),
                BackgroundColor3 = Themes.Border,
                BorderSizePixel = 0,
            }),

            AutoKey = Roact.createElement("TextButton", {
                Text = "",
                Size = UDim2.fromOffset(60, 24),
                BackgroundColor3 = self.props.autoKeyEnabled and Themes.Accent or Themes.BackgroundDark,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                [Roact.Event.MouseEnter] = function(rbx)
                    rbx.BackgroundColor3 = Themes.ItemHover
                end,
                [Roact.Event.MouseLeave] = function(rbx)
                    rbx.BackgroundColor3 = self.props.autoKeyEnabled and Themes.Accent or Themes.BackgroundDark
                end,
                [Roact.Event.Activated] = function()
                    if self.props.onStateChange then
                        self.props.onStateChange("world", {autoKeyEnabled = not self.props.autoKeyEnabled})
                    end
                end
            }, {
                Layout = Roact.createElement("UIListLayout", {
                    FillDirection = Enum.FillDirection.Horizontal,
                    HorizontalAlignment = Enum.HorizontalAlignment.Center,
                    VerticalAlignment = Enum.VerticalAlignment.Center,
                    Padding = UDim.new(0, 4),
                }),
                Dot = Roact.createElement("TextLabel", {
                    Size = UDim2.fromOffset(8, 8),
                    Text = "●",
                    TextColor3 = Themes.TextMain,
                    BackgroundTransparency = 1,
                    FontFace = Themes.FontNormal,
                    TextSize = 12,
                }),
                Label = Roact.createElement("TextLabel", {
                    Size = UDim2.fromOffset(32, 20),
                    Text = "Auto",
                    TextColor3 = Themes.TextMain,
                    BackgroundTransparency = 1,
                    FontFace = Themes.FontNormal,
                    TextSize = 12,
                })
            }),
        })
    })
end

return TopBar