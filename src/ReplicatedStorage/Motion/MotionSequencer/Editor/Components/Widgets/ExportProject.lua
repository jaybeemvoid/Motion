local cs = game:GetService("CollectionService")
local Roact = require(script.Parent.Parent.Parent.Parent.Roact)

local Export = Roact.Component:extend("Export")

local ExportData = require(script.Parent.Parent.Parent.Store.Widgets.Export)

local Theme = require(script.Parent.Parent.Parent.Themes.Theme)

function Export:init()
    self.state = {
        localViewSettings = self.props.SharedState.viewSettings or {},
        localActiveProject = self.props.SharedState.activeProject or {},
        localExportSettings = {
            fileName = "MyAnimation",
            exportDirectory = "Workspace",
            includeMetadata = true,
            includeDirectorTrack = true,
            includeAnimationTracks = true,
            exportDirector = "ReplicatedStorage",
            rootMotion = false,
        },
        isExporting = false,
        exportStatus = "",
        exportSuccess = false,
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

function Export:willUnmount()
    if self.syncConnection then
        self.syncConnection:Disconnect()
    end
end

function Export:toggleExportSetting(settingName)
    local currentValue = self.state.localExportSettings[settingName] or false

    self:setState(function(state)
        local newSettings = {}
        for k, v in pairs(state.localExportSettings) do
            newSettings[k] = v
        end
        newSettings[settingName] = not currentValue

        return {
            localExportSettings = newSettings
        }
    end)
end

function Export:updateProjectSetting(settingName, value)
    if not self.props.UpdateSharedState then
        warn("UpdateSharedState callback not provided")
        return
    end

    local updates = {}
    if self.state.localActiveProject then
        for k, v in pairs(self.state.localActiveProject) do
            updates[k] = v
        end
    end

    updates[settingName] = value

    self.props.UpdateSharedState({
        activeProject = updates
    })
end

function Export:updateExportSetting(settingName, value)
    self:setState(function(state)
        local newSettings = {}
        for k, v in pairs(state.localExportSettings) do
            newSettings[k] = v
        end
        newSettings[settingName] = value

        return {
            localExportSettings = newSettings
        }
    end)
end

function Export:performExport()
    self:setState({
        isExporting = true,
        exportStatus = "Preparing export...",
        exportSuccess = false,
    })

    task.spawn(function()
        local state = self.props.SharedState
        if not state or not state.activeProject then
            self:setState({
                isExporting = false,
                exportStatus = "Error: No active project",
                exportSuccess = false,
            })
            return
        end

        -- Calculate time range
        local startTime = self.state.localExportSettings.useCustomRange 
            and (self.state.localExportSettings.startTime or 0) 
            or 0
        local endTime = self.state.localExportSettings.useCustomRange 
            and (self.state.localExportSettings.endTime or state.activeProject.duration or 5)
            or (state.activeProject.duration or 5)

        local exportData = {
            Tracks = {}
        }

        -- Add metadata if enabled
        if self.state.localExportSettings.includeMetadata then
            exportData.Metadata = {
                Name = state.activeProject.name or "Untitled",
                Duration = endTime - startTime,
                FPS = state.activeProject.fps or 60,
                ExportedAt = os.time(),
                TimeRange = self.state.localExportSettings.useCustomRange and {
                    Start = startTime,
                    End = endTime
                } or nil
            }
        end

        -- EXPORT DIRECTOR CLIPS
        if self.state.localExportSettings.includeDirectorTrack and state.tracks and state.tracks.director and state.tracks.director.clips then
            self:setState({exportStatus = "Exporting director track..."})

            local directorExport = {Clips = {}}

            for _, clip in ipairs(state.tracks.director.clips) do
                -- Skip clips outside time range
                if self.state.localExportSettings.useCustomRange then
                    if clip.endTime < startTime or clip.startTime > endTime then
                        continue
                    end
                end

                local clipExport = {
                    id = clip.id,
                    t0 = math.max(clip.startTime, startTime) - startTime,
                    t1 = math.min(clip.endTime, endTime) - startTime,
                    camId = nil,
                    fov = 70,
                    roll = 0,
                    properties = {}
                }

                if clip.cameraInstance then
                    local tags = cs:GetTags(clip.cameraInstance)
                    for _, tag in ipairs(tags) do
                        if string.find(tag, "MId_") then
                            clipExport.camId = tag
                            break
                        end
                    end
                    if not clipExport.camId then
                        clipExport.camId = clip.cameraInstance.Name
                    end
                end

                if clip.properties then
                    for propName, propData in pairs(clip.properties) do
                        local propExport = {
                            type = "number",
                            keyframes = {}
                        }

                        for _, kf in ipairs(propData.keyframes) do
                            -- Skip keyframes outside time range
                            if self.state.localExportSettings.useCustomRange then
                                if kf.time < startTime or kf.time > endTime then
                                    continue
                                end
                            end

                            table.insert(propExport.keyframes, {
                                t = kf.time - startTime,
                                v = kf.value,
                                e = kf.easing or "Linear",
                                d = kf.direction or "In"
                            })
                        end

                        table.sort(propExport.keyframes, function(a, b) return a.t < b.t end)
                        clipExport.properties[propName] = propExport

                        if #propExport.keyframes > 0 then
                            if propName == "FOV" then
                                clipExport.fov = propExport.keyframes[1].v
                            elseif propName == "Roll" then
                                clipExport.roll = propExport.keyframes[1].v
                            end
                        end
                    end
                end

                table.insert(directorExport.Clips, clipExport)
            end

            exportData.Tracks["_DIRECTOR_"] = directorExport
        end

        if self.state.localExportSettings.includeAnimationTracks and state.tracks then
            self:setState({exportStatus = "Exporting animation tracks..."})

            for trackId, track in pairs(state.tracks) do
                if track.type == "director" then continue end

                local trackInstance = track.instance
                local motionId = "Unknown"

                if trackInstance then
                    local tags = cs:GetTags(trackInstance)
                    for _, tag in ipairs(tags) do
                        if string.find(tag, "MId_") then
                            motionId = tag
                            break
                        end
                    end
                end

                exportData.Tracks[motionId] = {}

                if track.properties then
                    for propName, propData in pairs(track.properties) do
                        local cleanPropName = propData.name
                        local propertyExport = {
                            Type = propData.type or "number",
                            Channels = {}
                        }

                        if propData.channels then
                            for channelName, channelData in pairs(propData.channels) do
                                if channelData.keyframes and #channelData.keyframes > 0 then
                                    local channelKFs = {}

                                    for _, kf in ipairs(channelData.keyframes) do
                                        if self.state.localExportSettings.useCustomRange then
                                            if kf.time < startTime or kf.time > endTime then
                                                continue
                                            end
                                        end

                                        local kfData = {
                                            t = kf.time - startTime,
                                            v = kf.value,
                                            e = kf.interpolation or "Linear",
                                            d = kf.interpolationDirection or "In",
                                        }

                                        if kfData.e == "Bezier" then
                                            local hr = kf.handleRight or {x = 0.3, y = 0}
                                            local hl = kf.handleLeft or {x = 0.3, y = 0}

                                            kfData.hrx = hr.x
                                            kfData.hry = hr.y
                                            kfData.hlx = hl.x
                                            kfData.hly = hl.y
                                        end

                                        table.insert(channelKFs, kfData)
                                    end

                                    table.sort(channelKFs, function(a, b) return a.t < b.t end)
                                    propertyExport.Channels[channelName] = channelKFs
                                end
                            end
                        end

                        exportData.Tracks[motionId][cleanPropName] = propertyExport
                    end
                end
            end
        end

        if not self.state.localExportSettings.includeMetadata then
            exportData.Metadata = nil
        end
        
        if self.state.localExportSettings.rootMotion then
            exportData.RootMotion = true
        else
            exportData.RootMotion = false
        end

        self:setState({exportStatus = "Generating module script..."})

        local success, result = pcall(function()
            local function tableToLuaString(tbl, indent, prettyPrint)
                indent = indent or ""

                local s = "{\n"
                for k, v in pairs(tbl) do
                    local formatting = indent .. "  "
                    if type(k) == "string" then
                        formatting = formatting .. '["' .. k .. '"] = '
                    end

                    if type(v) == "table" then
                        s = s .. formatting .. tableToLuaString(v, indent .. "  ", prettyPrint) .. ",\n"
                    elseif type(v) == "string" then
                        s = s .. formatting .. '"' .. v .. '",\n'
                    elseif type(v) == "boolean" or type(v) == "number" then
                        s = s .. formatting .. tostring(v) .. ",\n"
                    elseif typeof(v) == "CFrame" then
                        s = s .. formatting .. "CFrame.new(" .. tostring(v) .. "),\n"
                    elseif typeof(v) == "Color3" then
                        s = s .. formatting .. "Color3.new(" .. tostring(v) .. "),\n"
                    elseif typeof(v) == "Vector3" or typeof(v) == "Vector2" then
                        s = s .. formatting .. "vector.create(" .. tostring(v) .. "),\n"
                    end
                end
                return s .. indent .. "}"
            end

            local usePrettyPrint = self.state.localExportSettings.prettyPrint
            local moduleContent = "-- Generated Motion Sequence\n-- Exported: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\nreturn " .. tableToLuaString(exportData, "", usePrettyPrint)

            local newModule = Instance.new("ModuleScript")
            newModule.Name = (self.state.localExportSettings.fileName or "MyAnimation")
            newModule.Source = moduleContent

            local targetService = game:GetService(self.state.localExportSettings.exportDirectory)
            newModule.Parent = targetService

            return newModule
        end)

        if success then
            self:setState({
                isExporting = false,
                exportStatus = "Export successful: " .. result.Name,
                exportSuccess = true,
            })
        else
            self:setState({
                isExporting = false,
                exportStatus = "Export failed: " .. tostring(result),
                exportSuccess = false,
            })
        end
    end)
end

function Export:renderDropdown(propKey, data, currentValue)
    local options = data.options or {}

    local optionElements = {
        Layout = Roact.createElement("UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 5),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    }

    for i, option in ipairs(options) do
        local isSelected = currentValue == option

        optionElements["Option" .. i] = Roact.createElement("TextButton", {
            Size = UDim2.new(1 / #options, -5, 0, 30),
            BackgroundColor3 = isSelected and Theme.ToggleOn or Theme.InputBG,
            BorderColor3 = isSelected and Theme.ToggleOn or Theme.BorderLight,
            BorderSizePixel = 1,
            Text = option,
            TextColor3 = isSelected and Theme.TextMain or Theme.TextMuted,
            FontFace = Theme.FontNormal,
            TextSize = 13,
            LayoutOrder = i,
            [Roact.Event.Activated] = function()
                if propKey == "ExportDirectory" then
                    self:updateExportSetting("exportDirectory", option)
                end
            end,
        }, {
            Corner = Roact.createElement("UICorner", {
                CornerRadius = UDim.new(0, 4),
            }),
        })
    end

    return Roact.createElement("Frame", {
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundTransparency = 1,
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
        OptionsContainer = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundTransparency = 1,
            LayoutOrder = 2,
        }, optionElements)
    })
end

function Export:renderSettingsPanel()
    local Interface = {}
    local categoryOrder = 1

    for categoryName, category in pairs(ExportData) do
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
                local currentValue = ""
                local settingKey = ""

                if propKey == "ProjectName" then
                    currentValue = self.state.localActiveProject.name or "Untitled"
                    settingKey = "name"
                elseif propKey == "FramesPerSecond" then
                    currentValue = tostring(self.state.localActiveProject.fps or 60)
                    settingKey = "fps"
                elseif propKey == "Duration" then
                    currentValue = tostring(self.state.localActiveProject.duration or 5)
                    settingKey = "duration"
                elseif propKey == "FileName" then
                    currentValue = self.state.localExportSettings.fileName or "MyAnimation"
                    settingKey = "fileName"
                elseif propKey == "ExportDirectory" then
                    currentValue = self.state.localExportSettings.fileName or "game.ReplicatedStorage"
                    settingKey = "ExportDirector"
                
                end

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
                        FontFace = Theme.FontNormal,
                        TextSize = 13,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Text = currentValue,
                        PlaceholderText = data.placeholder or "",
                        LayoutOrder = 2,
                        [Roact.Event.FocusLost] = function(rbx)
                            local value = rbx.Text

                            if propKey == "ProjectName" then
                                self:updateProjectSetting("name", value)
                            elseif propKey == "FramesPerSecond" then
                                local fps = tonumber(value)
                                if fps and fps > 0 then
                                    self:updateProjectSetting("fps", fps)
                                else
                                    rbx.Text = tostring(self.state.localActiveProject.fps or 60)
                                end
                            elseif propKey == "Duration" then
                                local duration = tonumber(value)
                                if duration and duration > 0 then
                                    self:updateProjectSetting("duration", duration)
                                else
                                    rbx.Text = tostring(self.state.localActiveProject.duration or 5)
                                end
                            elseif propKey == "FileName" then
                                self:updateExportSetting("fileName", value)
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
            elseif data.type == "Dropdown" then
                local currentValue = ""

                if propKey == "ExportDirectory" then
                    currentValue = self.state.localExportSettings.exportDirectory or "Workspace"
                end

                categoryChildren[propKey .. "Dropdown"] = self:renderDropdown(propKey, data, currentValue)
                categoryChildren[propKey .. "Dropdown"].LayoutOrder = propertyOrder

            elseif data.type == "Toggle" then
                local isEnabled = false
                local settingKey = ""

                if propKey == "IncludeMetadata" then
                    settingKey = "includeMetadata"
                    isEnabled = self.state.localExportSettings.includeMetadata or false
                elseif propKey == "IncludeDirectorTrack" then
                    settingKey = "includeDirectorTrack"
                    isEnabled = self.state.localExportSettings.includeDirectorTrack or false
                elseif propKey == "IncludeAnimationTracks" then
                    settingKey = "includeAnimationTracks"
                    isEnabled = self.state.localExportSettings.includeAnimationTracks or false
                elseif propKey == "ApplyRootMotion" then
                    settingKey = "rootMotion"
                    isEnabled = self.state.localExportSettings.rootMotion or false
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
                            self:toggleExportSetting(settingKey)
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

function Export:render()
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

        Header = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundTransparency = 1,
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 1,
        }, {
            Layout = Roact.createElement("UIListLayout", {
                FillDirection = Enum.FillDirection.Vertical,
                Padding = UDim.new(0, 4),
                SortOrder = Enum.SortOrder.LayoutOrder,
            }),
            Title = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 40),
                BackgroundTransparency = 1,
                Text = "Export Configuration",
                TextColor3 = Theme.TextMain,
                FontFace = Theme.FontSemi,
                TextSize = 18,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
            }),
            Subtitle = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 18),
                BackgroundTransparency = 1,
                Text = "Configure and export your motion sequence to a module script",
                TextColor3 = Theme.TextDim,
                FontFace = Theme.FontNormal,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 2,
            }),
        }),

        Sections = Roact.createFragment(interface),

        ExportSection = Roact.createElement("Frame", {
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Theme.PanelBG,
            BorderSizePixel = 0,
            AutomaticSize = Enum.AutomaticSize.Y,
            LayoutOrder = 999,
        }, {
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
            Header = Roact.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,
                Text = "Export",
                TextColor3 = Theme.TextMain,
                FontFace = Theme.FontMedium,
                TextSize = 16,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = 1,
            }),
            StatusText = self.state.exportStatus ~= "" and Roact.createElement("TextLabel", {
                Size = UDim2.new(1, 0, 0, 20),
                BackgroundTransparency = 1,
                Text = self.state.exportStatus,
                TextColor3 = self.state.exportSuccess and Theme.ToggleOn or (self.state.isExporting and Theme.TextDim or Color3.fromRGB(255, 100, 100)),
                FontFace = Theme.FontNormal,
                TextSize = 12,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                LayoutOrder = 2,
            }),
            ExportButton = Roact.createElement("TextButton", {
                Size = UDim2.new(1, 0, 0, 35),
                BackgroundColor3 = self.state.isExporting and Theme.TextDim or Theme.ToggleOn,
                BorderSizePixel = 0,
                Text = self.state.isExporting and "Exporting..." or "Export to Module",
                TextColor3 = Theme.TextMain,
                FontFace = Theme.FontMedium,
                TextSize = 14,
                LayoutOrder = 3,
                AutoButtonColor = not self.state.isExporting,
                [Roact.Event.Activated] = function()
                    if not self.state.isExporting then
                        self:performExport()
                    end
                end,
            }, {
                Corner = Roact.createElement("UICorner", {
                    CornerRadius = UDim.new(0, 4),
                }),
            })
        })
    })
end

return Export