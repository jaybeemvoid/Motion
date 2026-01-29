local cs = game:GetService("CollectionService")

local Roact = require(script.Parent.Parent.Roact)
local Engine = require(script.Parent.Parent.Core.Sequencer.Previewer)
local GizmoSystem = require(script.Parent.Parent.Core.Tools.Gizmo)
local Bootstrap = require(script.Parent.Controllers.FilesController)

local layout = Roact.Component:extend("Layout")
local tabs = {
    StartScreen = require(script.Parent.UI.Start),
    TopBar = require(script.Parent.UI.TopBar),
    ViewportTimeline = require(script.Parent.UI.ViewportTimeline),
}

local Actions = require(script.Parent.Store.Actions)
local State = require(script.Parent.Store.State)

local PlaybackController = require(script.Parent.Controllers.PlaybackController)
local Keyboard = require(script.Parent.Input.Keyboard)

local ProjectSerializer = require(script.Parent.Parent.Core.Sequencer.ProjectSerializer)

local DeepCopy = require(script.Parent.Parent.Util.DeepCopy)

function layout:init()
    self.state = {
        project = {
            name = "Untitled",
            fps = 60,
            duration = 5,
            createdAt = os.time(),
        },

        playback = {
            currentTime = 0,
            isPlaying = false,
            playDirection = 1,
        },
        
        tracks = {
            director = {
                type = "director",
                name = "Director",
                clips = {},
                isExpanded = false,
                order = 0,
            },
        },
        trackOrder = {"director"},

        selection = {
            clips = {},
            keyframes = {},
            tracks = {},
        },
        clipboard = {
            clips = {},
            keyframes = {},
            type = nil,
        },

        viewport = {
            mode = "Start",
            positionX = 0,
            positionY = 0,
            offsetY = 0,
            panX = 0,
            panY = 0,
            zoomX = 50,
            zoomY = 1,
            verticalPixelsPerSecond = 20,
        },
        
        ui = {
            expandedTracks = {},
            openMenus = {},
            mousePos = UDim2.fromOffset(0, 0),
            canScroll = true,
            isInputHandledByUI = false,
            isPanelOpen = false,
            propertyPickerTrackId = nil,
            cameraPreviewActive = false,
            viewSettings = {
                showGrid = false,
                showLetterbox = false,
            },
        },
        
        world = {
            autoKeyEnabled = true,
        },

        history = {
            past = {},
            future = {},
            maxSize = 50,
        },

        debug = false,
    }

    self.stateSync = self.props.SyncSignal
    self.locks = { isInternalUpdate = false }

    Bootstrap()

    local actions = {
        utils = Actions.Utils.new(self),
        history = Actions.History.new(self),
        context = Actions.Context.new(self),
        keyframe = Actions.Keyframe.new(self),
        track = Actions.Track.new(self),
        director = Actions.Director.new(self),
    }

    self.Actions = actions
    self.playbackController = PlaybackController.new(self)
    self.keyboard = Keyboard.new(self, self.props.Bind)
    
    self.activeGizmo = GizmoSystem.new(self.props.Plugin, nil, self.locks, function(instance, propertyName, changedChannels)  -- ✅ Add changedChannels parameter
        local trackId = nil
        for id, track in pairs(self.state.tracks) do
            if track.instance == instance then
                trackId = id
                break
            end
        end

        if not trackId then
            warn("No track found for instance:", instance.Name)
            return
        end

        local actualPropertyName = instance:IsA("Motor6D") and "C0" or propertyName

        self.Actions.keyframe:captureKeyframe(
            trackId,
            actualPropertyName,
            self.state.playback.currentTime,
            changedChannels
        )
    end)

    if self.stateSync then
        self.syncConnection = self.stateSync.Event:Connect(function(updates)
            self:handleExternalUpdate(updates)
        end)
    end
end

function layout:handleExternalUpdate(updates)
    if not self.locks.isInternalUpdate then
        local stateUpdate = {}

        if updates.cameraPreviewActive ~= nil then
            stateUpdate.ui = stateUpdate.ui or {}
            stateUpdate.ui.cameraPreviewActive = updates.cameraPreviewActive
        end

        if updates.viewSettings then
            stateUpdate.ui = stateUpdate.ui or {}
            stateUpdate.ui.viewSettings = updates.viewSettings
        end

        if updates.activeProject then
            stateUpdate.project = {}
            for n, v in pairs(updates.activeProject) do
                stateUpdate.project[n] = v
            end
        end

        if updates.currentTime ~= nil then
            stateUpdate.playback = stateUpdate.playback or {}
            stateUpdate.playback.currentTime = updates.currentTime
        end

        if updates.isPlaying ~= nil then
            stateUpdate.playback = stateUpdate.playback or {}
            stateUpdate.playback.isPlaying = updates.isPlaying
        end

        if updates.tracks then
            stateUpdate.tracks = updates.tracks
        end

        if next(stateUpdate) then
            self:setState(stateUpdate)
        end
    end
end

function layout:broadcastStateUpdate(updates)
    if self.props.UpdateSharedState then
        self.locks.isInternalUpdate = true
        self.props.UpdateSharedState(updates)
        task.wait()
        self.locks.isInternalUpdate = false
    end
end

function layout:didUpdate(prevProps, prevState)
    if not self.state.playback.isPlaying then
        if self.state.playback.currentTime and prevState.playback.currentTime ~= self.state.playback.currentTime then
            if self.state.tracks then

                Engine.update(
                    self.state.tracks, 
                    self.state.playback.currentTime, 
                    self.state.ui.cameraPreviewActive, 
                    self.locks
                )
            end
        end
    end

    local updates = {}

    if prevState.ui.cameraPreviewActive ~= self.state.ui.cameraPreviewActive then
        updates.cameraPreviewActive = self.state.ui.cameraPreviewActive
    end

    if prevState.ui.viewSettings ~= self.state.ui.viewSettings then
        updates.viewSettings = self.state.ui.viewSettings
    end

    if prevState.playback.currentTime ~= self.state.playback.currentTime then
        updates.currentTime = self.state.playback.currentTime
    end

    if prevState.playback.isPlaying ~= self.state.playback.isPlaying then
        updates.isPlaying = self.state.playback.isPlaying
    end

    if prevState.tracks ~= self.state.tracks then
        updates.tracks = self.state.tracks
    end

    if prevState.project ~= self.state.project then
        updates.activeProject = {}
        for n, v in pairs(self.state.project) do
            updates.activeProject[n] = v
        end
    end

    if next(updates) then
        self:broadcastStateUpdate(updates)
    end
end

function layout:didMount()
    self.playbackController:start()
    self.keyboard:connect()

    self:broadcastStateUpdate({
        cameraPreviewActive = self.state.ui.cameraPreviewActive,
        viewSettings = self.state.ui.viewSettings,
        currentTime = self.state.playback.currentTime,
        isPlaying = self.state.playback.isPlaying,
        tracks = self.state.tracks,
        activeProject = {
            name = self.state.project.name,
            fps = self.state.project.fps,
            duration = self.state.project.duration,
        }
    })
end

function layout:render()
    local pps = self.state.viewport.zoomX
    local totalSecs = self.state.project.duration
    local totalPixelWidth = totalSecs * pps
    local viewportWidth = 300 
    local maxScrollPixels = math.max(0, totalPixelWidth - viewportWidth)
    local scrollOffsetPixels = math.clamp((self.state.viewport.positionX or 0) * maxScrollPixels, 0, maxScrollPixels)

    return Roact.createElement("Frame", {
        Style = {
            s = UDim2.fromScale(1, 1),
            z = 0,
            bg = "primary"
        }
    }, {
        StartScreen = self.state.viewport.mode == "Start" and Roact.createElement(tabs.StartScreen, {
            onOpenProject = function(sequenceValue)
                local savedData = ProjectSerializer.load(sequenceValue.Value)
                if savedData and savedData.tracks then
                    self.Actions.history:lock()
                    self.props.OnProjectLoaded(savedData)
                    self.Actions.history:unlock()
                    self.Actions.history:clear()
                    self.Actions.history:pushHistory()
                end
            end,

            onCreate = function(name, fps, duration)
                self:setState({
                    viewport = {
                        mode = "Timeline",
                        positionX = 0,
                        positionY = 0,
                        offsetY = 0,
                        panX = 0,
                        panY = 0,
                        zoomX = math.clamp(1200 / duration, 15, 100),
                        zoomY = 1,
                        verticalPixelsPerSecond = 20,
                    },
                    project = {
                        name = name,
                        fps = fps,
                        duration = duration,
                        createdAt = os.time(),
                    },
                    tracks = {
                        director = {
                            type = "director",
                            name = "Director",
                            clips = {},
                            isExpanded = false,
                            order = 0,
                        },
                    },
                    trackOrder = {"director"},
                    selection = {
                        clips = {},
                        keyframes = {},
                        tracks = {},
                    },
                    clipboard = {
                        clips = {},
                        keyframes = {},
                        type = nil,
                    },
                    ui = {
                        expandedTracks = {},
                        openMenus = {},
                        mousePos = UDim2.fromOffset(0, 0),
                        canScroll = true,
                        isInputHandledByUI = false,
                        isPanelOpen = false,
                        maxScrollY = 0,
                        canvasHeight = 0,
                        propertyPickerTrackId = nil,
                        cameraPreviewActive = false,
                        viewSettings = {
                            showGrid = false,
                            showLetterbox = false,
                        },
                    },
                    history = {
                        past = {},
                        future = {},
                        maxSize = 50,
                    },
                })
            end,
        }),

        TopBar = self.state.viewport.mode ~= "Start" and Roact.createElement(tabs.TopBar, {
            currentTime = self.state.playback.currentTime,
            fps = self.state.project.fps,
            isPlaying = self.state.playback.isPlaying,
            autoKeyEnabled = self.state.world.autoKeyEnabled,
            projectName = self.state.project.name,

            playbackController = self.playbackController,

            onStateChange = function(state, value) 
                self.Actions.utils:setState(state, value) 
            end,

            openSettings = self.props.WidgetControls.openSettings,

            totalSeconds = totalSecs,

            onKeyFrameDeletion = function()
                self.Actions.keyframe:deleteSelectedKeyFrame()
            end,

            onUndo = function()
                self.Actions.history:undo()
            end,

            onRedo = function()
                self.Actions.history:redo()
            end,

            onCopy = function()
                self.Actions.keyframe:onAction("Action", "CopyKeyFrame")
            end,

            onCut = function()
                self.Actions.keyframe:onAction("Action", "CutKeyFrame")
            end,

            onPaste = function()
                self.Actions.keyframe:onAction("Action", "PasteKeyFrame")
            end,

            onDuplicate = function()
                self.Actions.keyframe:onAction("Action", "DuplicateKeyFrame")
            end,

            onSelectAll = function()
                self.Actions.keyframe:select(nil, "All")
            end,

            onDeselectAll = function()
                self.Actions.keyframe:select(nil, "None")
            end,

            onTimelineSwitch = function()
                self:setState(function(state)
                    return {
                        viewport = {
                            mode = "Timeline",
                            positionX = state.viewport.positionX,
                            positionY = state.viewport.positionY,
                            offsetY = state.viewport.offsetY,
                            panX = state.viewport.panX,
                            panY = state.viewport.panY,
                            zoomX = state.viewport.zoomX,
                            zoomY = state.viewport.zoomY,
                            verticalPixelsPerSecond = state.viewport.verticalPixelsPerSecond,
                        }
                    }
                end)
            end,

            onGraphSwitch = function()
                self:setState(function(state)
                    return {
                        viewport = {
                            mode = "Graph",
                            positionX = state.viewport.positionX,
                            positionY = state.viewport.positionY,
                            offsetY = state.viewport.offsetY,
                            panX = state.viewport.panX,
                            panY = state.viewport.panY,
                            zoomX = state.viewport.zoomX,
                            zoomY = state.viewport.zoomY,
                            verticalPixelsPerSecond = state.viewport.verticalPixelsPerSecond,
                        }
                    }
                end)
            end,

            createKeyFrame = function()
                self.Actions.keyframe:create()
            end,

            onNewProject = function()
                self:setState(function(state)
                    return {
                        viewport = {
                            mode = "Start",
                            positionX = state.viewport.positionX,
                            positionY = state.viewport.positionY,
                            offsetY = state.viewport.offsetY,
                            panX = state.viewport.panX,
                            panY = state.viewport.panY,
                            zoomX = state.viewport.zoomX,
                            zoomY = state.viewport.zoomY,
                            verticalPixelsPerSecond = state.viewport.verticalPixelsPerSecond,
                        }
                    }
                end)
                self.Actions.history:clear()
            end,

            onSave = function()
                local projectName = self.state.project.name or "Untitled"
                -- Filter out director track for animation tracks
                local animTracks = {}
                for id, track in pairs(self.state.tracks) do
                    if track.type ~= "director" then
                        animTracks[id] = track
                    end
                end
                ProjectSerializer.save(projectName, animTracks, self.state.trackOrder)
            end,

            onOpenProject = function()
                local savedData = ProjectSerializer.load(game.ReplicatedStorage.MotionCore.Sequences.Untitled.Value)

                if savedData and savedData.tracks then
                    self.Actions.history:lock()

                    self:setState({
                        viewport = {
                            mode = "Timeline",
                            positionX = 0,
                            positionY = 0,
                            offsetY = 0,
                            panX = 0,
                            panY = 0,
                            zoomX = math.clamp(1200 / (savedData.duration or 5), 15, 100),
                            zoomY = 1,
                            verticalPixelsPerSecond = 20,
                        },
                        project = {
                            name = savedData.name or "Untitled",
                            fps = savedData.fps or 60,
                            duration = savedData.duration or 10,
                            createdAt = os.time(),
                        },
                        tracks = {
                            director = {
                                type = "director",
                                name = "Director",
                                clips = {},
                                isExpanded = false,
                                order = 0,
                            },
                        },
                        trackOrder = {"director"},
                        selection = {
                            clips = {},
                            keyframes = {},
                            tracks = {},
                        },
                        clipboard = {
                            clips = {},
                            keyframes = {},
                            type = nil,
                        },
                        ui = {
                            expandedTracks = {},
                            openMenus = {},
                            mousePos = UDim2.fromOffset(0, 0),
                            canScroll = true,
                            isInputHandledByUI = false,
                            isPanelOpen = false,
                            propertyPickerTrackId = nil,
                            cameraPreviewActive = false,
                            viewSettings = {
                                showGrid = false,
                                showLetterbox = false,
                            },
                        },
                        history = {
                            past = {},
                            future = {},
                            maxSize = 50,
                        },
                    })

                    for _, id in ipairs(savedData.trackOrder or {}) do
                        local data = savedData.tracks[id]
                        if data and data.instance then
                            self.Actions.track:create(
                                data.name, 
                                data.instance, 
                                data.properties, 
                                data.parentId
                            )
                        end
                    end

                    self.Actions.history:unlock()
                    self.Actions.history:clear()
                    self.Actions.history:pushHistory()
                end
            end,

            exportProject = function()
                self.props.WidgetControls.openExport()
                --[[local state = self.state
                if not state.project then return end

                local exportData = {
                    Metadata = {
                        Name = state.project.name,
                        Duration = state.project.duration,
                        FPS = state.project.fps,
                        ExportedAt = os.time()
                    },
                    Tracks = {}
                }

                local directorExport = {}

                -- EXPORT DIRECTOR CLIPS
                if state.tracks.director and state.tracks.director.clips then
                    local clipsExport = {}

                    for _, clip in ipairs(state.tracks.director.clips) do
                        local clipExport = {
                            id = clip.id,
                            t0 = clip.startTime,
                            t1 = clip.endTime,
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
                                    table.insert(propExport.keyframes, {
                                        t = kf.time,
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

                        table.insert(clipsExport, clipExport)
                    end

                    directorExport.Clips = clipsExport
                end

                exportData.Tracks["_DIRECTOR_"] = directorExport

                -- EXPORT OBJECT TRACKS (exclude director)
                if state.tracks then
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
                                                local kfData = {
                                                    t = kf.time,
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

                local success, result = pcall(function()
                    local function tableToLuaString(tbl, indent)
                        indent = indent or ""
                        local s = "{\n"
                        for k, v in pairs(tbl) do
                            local formatting = indent .. "  "
                            if type(k) == "string" then
                                formatting = formatting .. '["' .. k .. '"] = '
                            end

                            if type(v) == "table" then
                                s = s .. formatting .. tableToLuaString(v, indent .. "  ") .. ",\n"
                            elseif type(v) == "string" then
                                s = s .. formatting .. '"' .. v .. '",\n'
                            elseif type(v) == "boolean" or type(v) == "number" then
                                s = s .. formatting .. tostring(v) .. ",\n"
                            elseif typeof(v) == "CFrame" then
                                s = s .. formatting .. "CFrame.new(" .. tostring(v) .. "),\n"
                            elseif typeof(v) == "Color3" then
                                s = s .. formatting .. "Color3.new(" .. tostring(v) .. "),\n"
                            elseif typeof(v) == "Vector3" then
                                s = s .. formatting .. "Vector3.new(" .. tostring(v) .. "),\n"
                            end
                        end
                        return s .. indent .. "}"
                    end

                    local moduleContent = "-- Generated Cinematic Sequence\nreturn " .. tableToLuaString(exportData)

                    local newModule = Instance.new("ModuleScript")
                    newModule.Name = state.project.name .. ".motion"
                    newModule.Source = moduleContent
                    newModule.Parent = game:GetService("Workspace")

                    return newModule
                end)

                if success then
                    warn("Project Exported Successfully to Workspace: " .. result.Name)
                else
                    warn("Export Failed: " .. tostring(result))
                end--]]
            end,

            onToggleSetting = function(settingName)
                if settingName == "showGrid" then
                    self:setState(function(state)
                        return {
                            ui = {
                                expandedTracks = state.ui.expandedTracks,
                                openMenus = state.ui.openMenus,
                                mousePos = state.ui.mousePos,
                                canScroll = state.ui.canScroll,
                                isInputHandledByUI = state.ui.isInputHandledByUI,
                                isPanelOpen = state.ui.isPanelOpen,
                                propertyPickerTrackId = state.ui.propertyPickerTrackId,
                                cameraPreviewActive = state.ui.cameraPreviewActive,
                                viewSettings = {
                                    showGrid = not state.ui.viewSettings.showGrid,
                                    showLetterbox = state.ui.viewSettings.showLetterbox,
                                }
                            }
                        }
                    end)
                elseif settingName == "showLetterbox" then
                    self:setState(function(state)
                        return {
                            ui = {
                                expandedTracks = state.ui.expandedTracks,
                                openMenus = state.ui.openMenus,
                                mousePos = state.ui.mousePos,
                                canScroll = state.ui.canScroll,
                                isInputHandledByUI = state.ui.isInputHandledByUI,
                                isPanelOpen = state.ui.isPanelOpen,
                                propertyPickerTrackId = state.ui.propertyPickerTrackId,
                                cameraPreviewActive = state.ui.cameraPreviewActive,
                                viewSettings = {
                                    showGrid = state.ui.viewSettings.showGrid,
                                    showLetterbox = not state.ui.viewSettings.showLetterbox,
                                }
                            }
                        }
                    end)
                end
            end
        }),

        Timeline = self.state.viewport.mode ~= "Start" and Roact.createElement(tabs.ViewportTimeline, {
            context = self,

            propertyPickerTrackId = self.state.ui.propertyPickerTrackId,
            tracks = self.state.tracks,

            positionX = scrollOffsetPixels,
            scrollPercentX = self.state.viewport.positionX, 
            maxScrollX = maxScrollPixels,
            positionY = self.state.viewport.positionY,
            fps = self.state.project.fps,
            offsetY = self.state.viewport.offsetY,
            canScroll = self.state.ui.canScroll,
            totalSeconds = self.state.project.duration,
            pixelsPerSecond = pps,
            currentTime = self.state.playback.currentTime,
            cameraPreviewActive = self.state.ui.cameraPreviewActive,
            director = self.state.tracks.director,

            isInputHandledByUI = self.state.ui.isInputHandledByUI,
            selection = self.state.selection,
            trackOrder = self.state.trackOrder,
            isPanelOpen = self.state.ui.isPanelOpen,
            mousePos = self.state.ui.mousePos,
            openMenus = self.state.ui.openMenus,
            locks = self.locks,
            vps = self.state.viewport.verticalPixelsPerSecond,
            mode = self.state.viewport.mode,
            panX = self.state.viewport.panX,
            panY = self.state.viewport.panY,
            zoomY = self.state.viewport.zoomY,
            Plugin = self.props.Plugin,

            clipSelection = self.state.selection.clips,

            openPropertyPicker = function(params)
                local trackId = params.trackId

                self.props.WidgetControls.openPropertyPicker({
                    trackId = trackId,
                    onPropertySelected = function(propertyName)
                        self.Actions.track:addProperty(trackId, propertyName)
                    end
                })
            end,

            toggleDirectorExpansion = function()
                self.Actions.director:toggleExpansion()
            end,

            toggleDirectorProperty = function(clipId, propertyName)
                self.Actions.director:togglePropertyExpansion(clipId, propertyName)
            end,

            onDirectorKeyframeUpdate = function(clipId, propertyName, relativeTime, value)
                self.Actions.director:updateKeyframe(clipId, propertyName, relativeTime, value)
            end,

            selectClip = function(clipId, isMulti)
                self.Actions.director:selectClip(clipId, isMulti)
            end,

            onClipMove = function(clipId, startTime, endTime)
                self.Actions.director:moveClip(clipId, startTime, endTime)
            end,

            onClipResize = function(clipId, edge, newTime)
                self.Actions.director:resizeClip(clipId, edge, newTime)
            end,

            onAddClip = function(startTime, endTime, cameraInstance)
                self.Actions.director:addClip(startTime, endTime, cameraInstance)
            end,

            onStateChange = function(state, newState) 
                self.Actions.utils:setState(state, newState) 
            end,

            toggleTrackExpansion = function(trackId, field)
                self.Actions.track:toggleExpansion(trackId, field)
            end,

            onKeyFrameSelection = function(keyframeId, multi)
                self.Actions.keyframe:select(keyframeId, multi)
            end,

            createKeyFrame = function(trackId, propertyName, time, value, channelName)
                self.Actions.keyframe:create(trackId, propertyName, time, value, channelName)
            end,

            onKeyframeMove = function(updates)
                self.Actions.keyframe:move(updates)
            end,

            onKeyframeUpdate = function(keyframeId, newData)
                self.Actions.keyframe:update(keyframeId, newData)
            end,

            onKeyframeUpdateFromGraph = function(kfId, newData, propertyName, channelName)
                self.Actions.keyframe:KeyframeUpdateFromGraph(kfId, newData, propertyName, channelName)
            end,

            onHandleUpdate = function(kfId, side, newHandle, propertyName, channelName)
                self.Actions.keyframe:updateHandle(kfId, side, newHandle, propertyName, channelName)
            end,

            triggerContext = function(position, context)
                self.Actions.context:trigger(position, context)
            end,

            onAction = function(action, value)
                self.Actions.keyframe:onAction(action, value)
            end,

            onHoverSubMenu = function(level, itemConfig, itemOffset)
                self.Actions.utils:onHoverSubMenu(level, itemConfig, itemOffset)
            end,

            onPropertyUiChange = function(trackId, property, value)
                self.Actions.track:onPropertyUiChange(trackId, property, value)
            end,

            onZoom = function(wheelDelta, mouseX)
                self.Actions.utils:zoom(wheelDelta, mouseX)
            end,

            onGraphZoom = function(wheelDelta, mouseX)
                self.Actions.utils:graphZoom(wheelDelta, mouseX)
            end,

            Recomposition = self.Actions.utils.Recomposition,

            smartAdd = function(...)
                return self.Actions.track:smartAdd(...)
            end,

            getLinearRegistry = function()
                return self.Actions.utils:getLinearRegistry()
            end,

            toggleCameraPreview = function(enabled)
                self.Actions.director:toggleCameraPreview(enabled)
            end,

            playbackController = self.playbackController,
        }),
    })
end

function layout:willUnmount()
    if self.activeGizmo then
        self.activeGizmo:destroy()
        self.activeGizmo = nil
    end
    if self.Actions then
        self.Actions.track:destroy()
        self.Actions.keyframe:destroy()
    end

    if self.keyboard then
        self.keyboard:destroy()
    end

    if self.playbackController then
        self.playbackController:destroy()
    end

    if self.state.tracks then
        for _, track in pairs(self.state.tracks) do
            if typeof(track) ~= "table" or track.type == "director" then continue end

            local instance = track.instance

            if instance and instance.Parent then
                self.locks.isInternalUpdate = true
                for _, propData in ipairs(track.properties) do
                    pcall(function()
                        instance[propData.name] = propData.defaultValue
                    end)
                end
            end
        end
        self.locks.isInternalUpdate = false
    end
end

return layout