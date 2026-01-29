local Roact = require(script.Parent.Parent.Parent.Parent.Roact)
local Settings = Roact.Component:extend("Settings")

local ProjectConfigurationLayout = require(script.Parent.Parent.Parent.Store.Widgets.ProjectConfiguration)

local Theme = require(script.Parent.Parent.Parent.Themes.Theme)

local mainHeader = Font.new("rbxassetid://12187365364", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal)
local subHeader = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium, Enum.FontStyle.Normal)
local property = Font.new("rbxassetid://12187365364", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

function Settings:init()
    self.state = {
        localViewSettings = self.props.SharedState.viewSettings or {},
        localActiveProject = self.props.SharedState.activeProject or {},
    }

    if self.props.SyncSignal then
        self.syncConnection = self.props.SyncSignal.Event:Connect(function(updates)
            local newState = {}

            if updates.viewSettings then
                newState.localViewSettings = updates.viewSettings
            end

            if updates.activeProject then
                newState.localActiveProject = updates.activeProject
            end

            if next(newState) then
                self:setState(newState)
            end
        end)
    end
end

function Settings:willUnmount()
    if self.syncConnection then
        self.syncConnection:Disconnect()
    end
end

function Settings:toggleSetting(settingName)
    if not self.props.UpdateSharedState then
        warn("UpdateSharedState callback not provided")
        return
    end

    local currentValue = false
    if settingName == "showGrid" then
        currentValue = self.state.localViewSettings.showGrid or false
    elseif settingName == "showLetterbox" then
        currentValue = self.state.localViewSettings.showLetterbox or false
    end

    self.props.UpdateSharedState({
        viewSettings = {
            [settingName] = not currentValue
        }
    })
end

function Settings:updateProjectSetting(settingName, value)
    if not self.props.UpdateSharedState then
        warn("UpdateSharedState callback not provided")
        return
    end

    local updates = {
        activeProject = {}
    }

    if self.state.localActiveProject then
        for k, v in pairs(self.state.localActiveProject) do
            updates.activeProject[k] = v
        end
    end

    updates.activeProject[settingName] = value

    self.props.UpdateSharedState(updates)
end

function Settings:renderSettingsPanel()
    local Interface = {}
    local categoryOrder = 1

    for categoryName, category in pairs(ProjectConfigurationLayout) do
        local categoryChildren = {
            Padding = Roact.createElement("UIPadding", {
                PaddingTop = UDim.new(0, 10),
                PaddingLeft = UDim.new(0, 10),
                PaddingRight = UDim.new(0, 10),
                PaddingBottom = UDim.new(0, 10),
            }),
            Layout = Roact.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 8),
                SortOrder = Enum.SortOrder.LayoutOrder
            }),
            CategoryHeader = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,
                Text = categoryName,
                TextColor3 = Theme.TextMain,
                FontFace = Theme.FontMedium,
                TextSize = 16,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
            }),
        }

        local propertyOrder = 2

        for propKey, data in pairs(category) do
            if data.type == "Text" then
                categoryChildren[propKey .. "Section"] = Roact.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 60),
                    BackgroundTransparency = 1,
                    LayoutOrder = propertyOrder,
                }, {
                    Layout = Roact.createElement("UIListLayout", {
                        FillDirection = Enum.FillDirection.Vertical,
                        Padding = UDim.new(0, 5),
                        SortOrder = Enum.SortOrder.LayoutOrder
                    }),
                    SectionTitle = Roact.createElement("TextLabel", {
                        Size = UDim2.new(1, 0, 0, 20),
                        BackgroundTransparency = 1,
                        Text = data.title,
                        TextColor3 = Theme.TextDim,
                        FontFace = Theme.FontNormal,
                        TextSize = 14,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        LayoutOrder = 1,
                    }),

                    TextBox = Roact.createElement("TextBox", {
                        Size = UDim2.new(1, 0, 0, 30),
                        TextColor3 = Theme.TextMuted,
                        BackgroundColor3 = Theme.InputBG,
                        BorderColor3 = Theme.BorderLight,
                        BorderSizePixel = 1,
                        ClearTextOnFocus = false,
                        FontFace = property,
                        TextSize = 13,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Text = (propKey == "ProjectName" and (self.state.localActiveProject and self.state.localActiveProject.name or "Untitled")) 
                            or (propKey == "FramesPerSecond" and (self.state.localActiveProject and self.state.localActiveProject.fps and tostring(self.state.localActiveProject.fps) or "60"))
                            or (propKey == "Duration" and (self.state.localActiveProject and self.state.localActiveProject.duration and tostring(self.state.localActiveProject.duration) or "5"))
                            or "",
                        LayoutOrder = 2,
                        [Roact.Event.FocusLost] = function(rbx)
                            local value = rbx.Text

                            -- Convert and validate based on property type
                            if propKey == "ProjectName" then
                                self:updateProjectSetting("name", value)
                            elseif propKey == "FramesPerSecond" then
                                local fps = tonumber(value)
                                if fps and fps > 0 then
                                    self:updateProjectSetting("fps", fps)
                                else
                                    warn("Invalid FPS value:", value)
                                    -- Reset to current value
                                    rbx.Text = tostring(self.state.localActiveProject.fps or 60)
                                end
                            elseif propKey == "Duration" then
                                local duration = tonumber(value)
                                if duration and duration > 0 then
                                    self:updateProjectSetting("duration", duration)
                                else
                                    warn("Invalid duration value:", value)
                                    -- Reset to current value
                                    rbx.Text = tostring(self.state.localActiveProject.duration or 5)
                                end
                            end
                        end,
                    }, {
                        Padding = Roact.createElement("UIPadding", {
                            PaddingLeft = UDim.new(0, 8),
                            PaddingRight = UDim.new(0, 8),
                        }),
                        Corner = Roact.createElement("UICorner", {
                            CornerRadius = UDim.new(0, 4),
                        }),
                    }),
                })
            elseif data.type == "Toggle" then
                local isEnabled = false
                local settingKey = ""

                if propKey == "Grid" then
                    settingKey = "showGrid"
                    isEnabled = self.state.localViewSettings.showGrid or false
                elseif propKey == "Letterbox" then
                    settingKey = "showLetterbox"
                    isEnabled = self.state.localViewSettings.showLetterbox or false
                end

                categoryChildren[propKey .. "Toggle"] = Roact.createElement("Frame", {
                    Size = UDim2.new(1, 0, 0, 35),
                    BackgroundTransparency = 1,
                    LayoutOrder = propertyOrder,
                }, {
                    Layout = Roact.createElement("UIListLayout", {
                        FillDirection = Enum.FillDirection.Horizontal,
                        Padding = UDim.new(0, 10),
                        SortOrder = Enum.SortOrder.LayoutOrder,
                        VerticalAlignment = Enum.VerticalAlignment.Center,
                    }),
                    Label = Roact.createElement("TextLabel", {
                        Size = UDim2.new(1, -60, 1, 0),
                        BackgroundTransparency = 1,
                        Text = data.title,
                        TextColor3 = Theme.TextDim,
                        FontFace = Theme.FontNormal,
                        TextSize = 14,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        LayoutOrder = 1,
                    }),
                    ToggleButton = Roact.createElement("TextButton", {
                        Size = UDim2.new(0, 50, 0, 25),
                        BackgroundColor3 = isEnabled and Theme.ToggleOn or Theme.ToggleOff,
                        BorderSizePixel = 0,
                        Text = isEnabled and "ON" or "OFF",
                        TextColor3 = Theme.TextMain,
                        FontFace = Theme.FontNormal,
                        TextSize = 12,
                        LayoutOrder = 2,
                        [Roact.Event.Activated] = function()
                            self:toggleSetting(settingKey)
                        end,
                    }, {
                        Corner = Roact.createElement("UICorner", {
                            CornerRadius = UDim.new(0, 4),
                        }),
                    })
                })
            end

            propertyOrder = propertyOrder + 1
        end

        Interface[categoryName] = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Theme.PanelBG,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = categoryOrder,
        }, categoryChildren)

        categoryOrder = categoryOrder + 1
    end

    return Interface
end

function Settings:render()
    local interface = self:renderSettingsPanel()

    return Roact.createElement("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Theme.EditorBG,
        BorderSizePixel = 0,
        ScrollBarThickness = 6,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, {
        Layout = Roact.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Vertical,
            HorizontalAlignment = Enum.HorizontalAlignment.Left,
            Padding = UDim.new(0, 10),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),

        Padding = Roact.createElement("UIPadding", {
            PaddingTop = UDim.new(0, 10),
            PaddingLeft = UDim.new(0, 10),
            PaddingRight = UDim.new(0, 10),
            PaddingBottom = UDim.new(0, 10),
        }),

        Header = Roact.createElement("TextLabel", {
            Size = UDim2.new(1, 0, 0, 40),
            BackgroundTransparency = 1,
            Text = "Project Configuration",
            TextColor3 = Theme.TextMain,
            FontFace = Theme.FontSemi,
            TextSize = 18,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 1,
        }),

        Sections = Roact.createFragment(interface)
    })
end

return Settings