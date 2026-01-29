local maid = require(script.Parent.Parent.Parent.Parent.Util.Maid)
local RQuat = require(script.Parent.Parent.Parent.Parent.Core.Math.RQuat)
local gen = game:GetService("HttpService")

local DynamicProperties = require(script.Parent.Parent.DynamicProperties)
local PropertyTypes = require(script.Parent.Parent.PropertyRegistery)

local function parseDirectorKeyframeId(kfId)
    local parts = kfId:split("::")
    if parts[1] == "director" and #parts >= 4 then
        return {
            isDirector = true,
            clipId = parts[2],
            propertyName = parts[3],
            index = tonumber(parts[4])
        }
    end
    return { isDirector = false }
end

local function decomposeValue(value)
    return PropertyTypes.decompose(value)
end

local function unwrapAngle(angle, reference)
    local diff = angle - reference
    while diff > 180 do
        angle = angle - 360
        diff = diff - 360
    end
    while diff < -180 do
        angle = angle + 360
        diff = diff + 360
    end
    return angle
end

local keyframe = {}
keyframe.__index = keyframe

function keyframe.new(context)
    local self = setmetatable({}, keyframe)
    self.context = context
    self.maid = maid.new()
    self.autoKeyConnections = {}
    return self
end

function keyframe:create(trackId, propertyName, time, value, specificChannel)
    self.context:setState(function(prevState)
        local fps = prevState.project.fps or 60
        local snappedTime = math.round(time * fps) / fps

        local nextTracks = table.clone(prevState.tracks)
        local track = nextTracks[trackId]
        if not track then return end

        local hasProperty, existingProp = DynamicProperties.hasProperty(track, propertyName)
        if not hasProperty then
            track = DynamicProperties.addPropertyToTrack(track, propertyName, track.instance)
            nextTracks[trackId] = track
        end

        local nextProperties = table.clone(track.properties)
        
        local components = {}
        if specificChannel then
            components[specificChannel] = value
        else
            components = decomposeValue(value)
        end

        for i, prop in ipairs(nextProperties) do
            if prop.name == propertyName then
                local nextProp = table.clone(prop)
                nextProp.channels = nextProp.channels or {}

                for channelName, val in pairs(components) do
                    nextProp.channels[channelName] = nextProp.channels[channelName] or { keyframes = {} }

                    local channel = table.clone(nextProp.channels[channelName])
                    local nextKeyframes = table.clone(channel.keyframes)
                    
                    local existingIndex = nil
                    for j, kf in ipairs(nextKeyframes) do
                        if math.abs(kf.time - snappedTime) < 0.0001 then
                            existingIndex = j
                            break
                        end
                    end

                    if existingIndex then
                        local updatedKf = table.clone(nextKeyframes[existingIndex])
                        updatedKf.value = val
                        nextKeyframes[existingIndex] = updatedKf
                    else
                        table.insert(nextKeyframes, {
                            id = gen:GenerateGUID(false),
                            time = snappedTime,
                            value = val,
                            interpolation = "Linear",
                            interpolationDirection = "In",
                            tangentMode = "Free",
                            handleRight = {x = 0.3, y = 0},
                            handleLeft = {x = 0.3, y = 0}
                        })
                    end

                    table.sort(nextKeyframes, function(a, b) return a.time < b.time end)
                    channel.keyframes = nextKeyframes
                    nextProp.channels[channelName] = channel
                end

                nextProperties[i] = nextProp
                break
            end
        end

        local nextTrack = table.clone(track)
        nextTrack.properties = nextProperties
        nextTracks[trackId] = nextTrack

        return { tracks = nextTracks }
    end)

    self.context.Actions.history:pushHistory()
end

function keyframe:getSelectedReferences()
    local selection = self.context.state.selection.keyframes or {}
    local tracks = self.context.state.tracks
    local found = {}

    if not next(selection) then return found end

    for trackId, track in pairs(tracks) do
        if track.type == "director" then continue end

        for _, prop in ipairs(track.properties or {}) do
            for channelName, channel in pairs(prop.channels or {}) do
                for _, kf in ipairs(channel.keyframes or {}) do
                    if selection[kf.id] then
                        table.insert(found, {
                            kf = kf,
                            trackId = trackId,
                            propName = prop.name,
                            channelName = channelName
                        })
                    end
                end
            end
        end
    end
    return found
end

function keyframe:setupSmartAutoKey(trackId, instance, propertyName)
    local connectionKey = trackId .. "_" .. propertyName

    if self.autoKeyConnections[connectionKey] then
        self.autoKeyConnections[connectionKey]:Disconnect()
    end

    local lastKnownValue = instance[propertyName]
    local lastEuler = nil

    if typeof(lastKnownValue) == "CFrame" then
        if instance:IsA("Motor6D") and propertyName == "C0" then
            -- Extract euler from C0's rotation
            local _, _, _, m11, m12, m13, m21, m22, m23, m31, m32, m33 = lastKnownValue:GetComponents()
            local rx, ry, rz = CFrame.new(0, 0, 0, m11, m12, m13, m21, m22, m23, m31, m32, m33):ToEulerAnglesXYZ()
            lastEuler = {
                rx = math.deg(rx),
                ry = math.deg(ry),
                rz = math.deg(rz)
            }
        else
            -- For regular parts, use Rotation property
            lastEuler = {
                rx = instance.Rotation.X,
                ry = instance.Rotation.Y,
                rz = instance.Rotation.Z
            }
        end
    end

    local lastRecordedTime = -1

    self.autoKeyConnections[connectionKey] = instance:GetPropertyChangedSignal(propertyName):Connect(function()
        if self.context.locks.isInternalUpdate then 
            lastKnownValue = instance[propertyName]
            if typeof(lastKnownValue) == "CFrame" then
                if instance:IsA("Motor6D") and propertyName == "C0" then
                    local _, _, _, m11, m12, m13, m21, m22, m23, m31, m32, m33 = lastKnownValue:GetComponents()
                    local rx, ry, rz = CFrame.new(0, 0, 0, m11, m12, m13, m21, m22, m23, m31, m32, m33):ToEulerAnglesXYZ()
                    lastEuler = {
                        rx = math.deg(rx),
                        ry = math.deg(ry),
                        rz = math.deg(rz)
                    }
                else
                    lastEuler = {
                        rx = instance.Rotation.X,
                        ry = instance.Rotation.Y,
                        rz = instance.Rotation.Z
                    }
                end
            end
            return 
        end
    end)
    
    local newValue = instance[propertyName]
    local changedChannels = {}

    local POS_THRESHOLD = 0.0001
    local ROT_THRESHOLD_DEG = 0.01

    if typeof(newValue) == "CFrame" then
        local newEuler

        if instance:IsA("Motor6D") and propertyName == "C0" then
            local _, _, _, m11, m12, m13, m21, m22, m23, m31, m32, m33 = newValue:GetComponents()
            local rx, ry, rz = CFrame.new(0, 0, 0, m11, m12, m13, m21, m22, m23, m31, m32, m33):ToEulerAnglesXYZ()
            newEuler = {
                rx = unwrapAngle(math.deg(rx), lastEuler and lastEuler.rx or math.deg(rx)),
                ry = unwrapAngle(math.deg(ry), lastEuler and lastEuler.ry or math.deg(ry)),
                rz = unwrapAngle(math.deg(rz), lastEuler and lastEuler.rz or math.deg(rz))
            }
        else
            local currentRotation = instance.Rotation
            newEuler = {
                rx = unwrapAngle(currentRotation.X, lastEuler and lastEuler.rx or currentRotation.X),
                ry = unwrapAngle(currentRotation.Y, lastEuler and lastEuler.ry or currentRotation.Y),
                rz = unwrapAngle(currentRotation.Z, lastEuler and lastEuler.rz or currentRotation.Z)
            }
        end

        if (newValue.Position - lastKnownValue.Position).Magnitude > POS_THRESHOLD then
            changedChannels.X = newValue.X
            changedChannels.Y = newValue.Y
            changedChannels.Z = newValue.Z
        end

        if lastEuler then
            if math.abs(newEuler.rx - lastEuler.rx) > ROT_THRESHOLD_DEG then 
                changedChannels.RX = newEuler.rx 
            end
            if math.abs(newEuler.ry - lastEuler.ry) > ROT_THRESHOLD_DEG then 
                changedChannels.RY = newEuler.ry 
            end
            if math.abs(newEuler.rz - lastEuler.rz) > ROT_THRESHOLD_DEG then 
                changedChannels.RZ = newEuler.rz 
            end
        end
        lastEuler = newEuler
    end

    self.maid:GiveTask(self.autoKeyConnections[connectionKey])
end

function keyframe:captureKeyframe(trackId, propertyName, kTime, changedChannels)
    local snap = 0.05
    local snappedTime = math.round(kTime / snap) * snap

    self.context:setState(function(prevState)
        local targetTrack = prevState.tracks[trackId]
        if not targetTrack then return end

        local nextTracks = table.clone(prevState.tracks)
        local nextTrack = table.clone(targetTrack)
        local nextProperties = table.clone(nextTrack.properties)

        local instance = targetTrack.instance
        if not instance then return end

        local success, rawValue = pcall(function()
            return instance[propertyName]
        end)

        if not success then return end

        local components = decomposeValue(rawValue)

        for i, prop in nextProperties do
            if prop.name == propertyName then
                local nextProp = table.clone(prop)
                nextProp.channels = nextProp.channels or {}
                for channelName, val in components do
                    
                    if changedChannels and not changedChannels[channelName] then
                        continue
                    end
                    
                    local existingChannel = nextProp.channels[channelName]
                    local hasExistingKeyframes = existingChannel and #existingChannel.keyframes > 0
                    
                    local hasChangedSignificantly = false
                    if existingChannel and #existingChannel.keyframes > 0 then
                        -- Find the most recent keyframe before current time
                        local lastKf = nil
                        for _, kf in ipairs(existingChannel.keyframes) do
                            if kf.time <= snappedTime then
                                if not lastKf or kf.time > lastKf.time then
                                    lastKf = kf
                                end
                            end
                        end

                        if lastKf then
                            local threshold = (channelName == "X" or channelName == "Y" or channelName == "Z") and 0.001 or 0.1
                            hasChangedSignificantly = math.abs(val - lastKf.value) > threshold
                        else
                            hasChangedSignificantly = true -- No previous keyframe to compare
                        end
                    else
                        hasChangedSignificantly = true -- No channel exists yet
                    end

                    -- Only create keyframe if channel has history OR value changed
                    if hasExistingKeyframes or hasChangedSignificantly then
                        nextProp.channels[channelName] = nextProp.channels[channelName] or { keyframes = {} }

                        local channel = table.clone(nextProp.channels[channelName])
                        local nextKeyframes = table.clone(channel.keyframes)

                        local existingIndex = nil
                        for j, kf in ipairs(nextKeyframes) do
                            if math.abs(kf.time - snappedTime) < 0.0001 then
                                existingIndex = j
                                break
                            end
                        end

                        if existingIndex then
                            nextKeyframes[existingIndex] = table.clone(nextKeyframes[existingIndex])
                            nextKeyframes[existingIndex].value = val
                        else
                            table.insert(nextKeyframes, {
                                id = gen:GenerateGUID(false),
                                time = snappedTime,
                                value = val,
                                easing = "Linear"
                            })
                        end

                        table.sort(nextKeyframes, function(a, b) return a.time < b.time end)
                        channel.keyframes = nextKeyframes
                        nextProp.channels[channelName] = channel
                    end
                end

                nextProperties[i] = nextProp
                break
            end
        end

        nextTrack.properties = nextProperties
        nextTracks[trackId] = nextTrack

        return { tracks = nextTracks }
    end)

    self.context.Actions.history:pushHistory()
end

-- mode: "Add", "Replace", "All", "None"
function keyframe:select(kfs, mode)
    mode = mode or "Replace"

    self.context:setState(function(prevState)
        local newKeyframes = {}

        if not kfs and mode == "All" then
            -- Select all regular keyframes
            for _, track in pairs(prevState.tracks) do
                -- Skip director
                if track.type == "director" then continue end

                for _, prop in ipairs(track.properties or {}) do
                    if prop.channels then
                        for _, channel in pairs(prop.channels) do
                            for _, kf in ipairs(channel.keyframes or {}) do
                                newKeyframes[kf.id] = true
                            end
                        end
                    end
                end
            end

            -- Select all director keyframes
            if prevState.tracks.director and prevState.tracks.director.clips then
                for _, clip in ipairs(prevState.tracks.director.clips) do
                    if clip.properties then
                        for propName, propData in pairs(clip.properties) do
                            if propData.keyframes then
                                for _, kf in ipairs(propData.keyframes) do
                                    if kf.id then
                                        newKeyframes[kf.id] = true
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- NEW: Return updated selection structure
            return {
                selection = {
                    clips = prevState.selection.clips,
                    keyframes = newKeyframes,
                    tracks = prevState.selection.tracks,
                }
            }
        end

        if not kfs and mode == "None" then
            return {
                selection = {
                    clips = prevState.selection.clips,
                    keyframes = {},
                    tracks = prevState.selection.tracks,
                }
            }
        end

        if mode == "Add" then
            newKeyframes = table.clone(prevState.selection.keyframes or {})
        end

        if typeof(kfs) == "table" then
            for kId, _ in pairs(kfs) do
                newKeyframes[kId] = true
            end
        elseif typeof(kfs) == "string" then
            newKeyframes[kfs] = true
        end

        return {
            selection = {
                clips = prevState.selection.clips,
                keyframes = newKeyframes,
                tracks = prevState.selection.tracks,
            }
        }
    end)
end

function keyframe:move(updates)
    self.context:setState(function(prevState)
        local nextTracks = table.clone(prevState.tracks)
        local anyChanges = false

        -- Move regular track keyframes
        for kfId, newTime in pairs(updates) do
            for trackId, track in pairs(nextTracks) do
                -- Skip director (handled separately)
                if track.type == "director" then continue end

                for propIdx, prop in ipairs(track.properties or {}) do
                    if prop.channels then
                        for chanName, chanData in pairs(prop.channels) do
                            for kfIdx, kf in ipairs(chanData.keyframes or {}) do
                                if kf.id == kfId then
                                    if not nextTracks[trackId]._cloned then
                                        nextTracks[trackId] = table.clone(track)
                                        nextTracks[trackId].properties = table.clone(track.properties)
                                        nextTracks[trackId]._cloned = true
                                    end

                                    local nextProp = table.clone(prop)
                                    nextProp.channels = table.clone(prop.channels)
                                    local nextChan = table.clone(chanData)
                                    nextChan.keyframes = table.clone(chanData.keyframes)

                                    local kfCopy = table.clone(kf)
                                    kfCopy.time = newTime
                                    nextChan.keyframes[kfIdx] = kfCopy

                                    table.sort(nextChan.keyframes, function(a, b) return a.time < b.time end)
                                    nextProp.channels[chanName] = nextChan
                                    nextTracks[trackId].properties[propIdx] = nextProp
                                    anyChanges = true
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Move director keyframes
        if nextTracks.director and nextTracks.director.clips then
            local directorCopy = table.clone(nextTracks.director)
            directorCopy.clips = table.clone(nextTracks.director.clips)

            for kfId, newAbsoluteTime in pairs(updates) do
                for clipIdx, clip in ipairs(directorCopy.clips) do
                    if clip.properties then
                        for propName, propData in pairs(clip.properties) do
                            if propData.keyframes then
                                for kfIdx, kf in ipairs(propData.keyframes) do
                                    if kf.id == kfId then
                                        local clipCopy = table.clone(clip)
                                        clipCopy.properties = table.clone(clip.properties)
                                        local propCopy = table.clone(propData)
                                        propCopy.keyframes = table.clone(propData.keyframes)

                                        local kfCopy = table.clone(kf)
                                        local relativeTime = newAbsoluteTime - clip.startTime
                                        local duration = clip.endTime - clip.startTime
                                        kfCopy.time = math.clamp(relativeTime, 0, duration)

                                        propCopy.keyframes[kfIdx] = kfCopy
                                        table.sort(propCopy.keyframes, function(a, b) return a.time < b.time end)

                                        clipCopy.properties[propName] = propCopy
                                        directorCopy.clips[clipIdx] = clipCopy
                                        anyChanges = true
                                    end
                                end
                            end
                        end
                    end
                end
            end

            if anyChanges then
                nextTracks.director = directorCopy
            end
        end

        if anyChanges then
            return { tracks = nextTracks }
        end
    end)
end

function keyframe:deleteSelectedKeyFrame()
    self.context:setState(function(prevState)
        local nextTracks = table.clone(prevState.tracks)
        -- NEW: Get keyframe selection from structured selection
        local selection = prevState.selection.keyframes or {}
        local anyChanges = false

        -- 1. Handle Director Keyframe Deletion
        if nextTracks.director and nextTracks.director.clips then
            local directorCopy = table.clone(nextTracks.director)
            local directorChanged = false
            directorCopy.clips = table.clone(nextTracks.director.clips)

            for clipIdx, clip in ipairs(directorCopy.clips) do
                local clipCopy = nil
                local clipChangedInThisLoop = false

                for propName, propData in pairs(clip.properties or {}) do
                    if propData.keyframes then
                        local originalCount = #propData.keyframes
                        local filteredKeyframes = {}

                        for _, kf in ipairs(propData.keyframes) do
                            if not selection[kf.id] then
                                table.insert(filteredKeyframes, kf)
                            end
                        end

                        if #filteredKeyframes ~= originalCount then
                            if not clipCopy then
                                clipCopy = table.clone(clip)
                                clipCopy.properties = table.clone(clip.properties)
                            end

                            local propCopy = table.clone(propData)
                            propCopy.keyframes = filteredKeyframes
                            clipCopy.properties[propName] = propCopy

                            clipChangedInThisLoop = true
                            directorChanged = true
                        end
                    end
                end

                if clipChangedInThisLoop then
                    directorCopy.clips[clipIdx] = clipCopy
                end
            end

            if directorChanged then
                nextTracks.director = directorCopy
                anyChanges = true
            end
        end

        -- 2. Handle Regular Track Keyframe Deletion
        for trackId, track in pairs(nextTracks) do
            -- Skip director
            if track.type == "director" then continue end

            local nextTrack = nil
            local trackChanged = false

            for i, prop in ipairs(track.properties or {}) do
                local nextProp = nil
                local propChanged = false

                if prop.channels then
                    for channelName, channelData in pairs(prop.channels) do
                        local originalCount = #channelData.keyframes
                        local filteredKeyframes = {}

                        for _, kf in ipairs(channelData.keyframes) do
                            if not selection[kf.id] then
                                table.insert(filteredKeyframes, kf)
                            end
                        end

                        if #filteredKeyframes ~= originalCount then
                            if not nextTrack then
                                nextTrack = table.clone(track)
                                nextTrack.properties = table.clone(track.properties)
                            end
                            if not nextProp then
                                nextProp = table.clone(prop)
                                nextProp.channels = table.clone(prop.channels)
                            end

                            local nextChannel = table.clone(channelData)
                            nextChannel.keyframes = filteredKeyframes
                            nextProp.channels[channelName] = nextChannel
                            propChanged = true
                        end
                    end
                end

                if propChanged then
                    nextTrack.properties[i] = nextProp
                    trackChanged = true
                    anyChanges = true
                end
            end

            if trackChanged then
                nextTracks[trackId] = nextTrack
            end
        end

        if anyChanges then
            return {
                tracks = nextTracks,
                selection = {
                    clips = prevState.selection.clips,
                    keyframes = {},
                    tracks = prevState.selection.tracks,
                }
            }
        end

        return nil
    end)

    self.context.Actions.history:pushHistory()
end

-- CONTINUED FROM PART 2...

function keyframe:update(kfId, newData)
    self.context.locks.isInternalUpdate = true

    self.context:setState(function(prevState)
        local nextTracks = table.clone(prevState.tracks)
        local anyChanges = false

        local realId = kfId:split("_")[1]

        for trackId, track in pairs(nextTracks) do
            -- Skip director
            if track.type == "director" then continue end

            local nextProperties = table.clone(track.properties or {})
            local trackChanged = false

            for i, prop in ipairs(nextProperties) do
                if prop.channels then
                    local nextProp = table.clone(prop)
                    nextProp.channels = table.clone(nextProp.channels)
                    local propChanged = false

                    for channelName, channelData in pairs(nextProp.channels) do
                        local nextChannel = table.clone(channelData)
                        local nextKeyframes = table.clone(nextChannel.keyframes)
                        local chanChanged = false

                        for j, kf in ipairs(nextKeyframes) do
                            if kf.id == realId then
                                local updatedKf = table.clone(kf)

                                if newData.time then
                                    updatedKf.time = newData.time
                                end

                                if newData.value ~= nil then
                                    updatedKf.value = newData.value
                                end

                                nextKeyframes[j] = updatedKf
                                chanChanged = true
                                break
                            end
                        end

                        if chanChanged then
                            table.sort(nextKeyframes, function(a, b) return a.time < b.time end)
                            nextChannel.keyframes = nextKeyframes
                            nextProp.channels[channelName] = nextChannel
                            propChanged = true
                        end
                    end

                    if propChanged then
                        nextProperties[i] = nextProp
                        trackChanged = true
                        anyChanges = true
                    end
                end
            end

            if trackChanged then
                local nextTrack = table.clone(track)
                nextTrack.properties = nextProperties
                nextTracks[trackId] = nextTrack
            end
        end

        return anyChanges and { tracks = nextTracks } or nil
    end)

    task.defer(function()
        self.context.locks.isInternalUpdate = false
        self.context.Actions.history:pushHistory()
    end)
end

function keyframe:Recomposition(propertyName, channelValue, instance)
    local success, currentValue = pcall(function()
        return instance[propertyName]
    end)

    if not success then
        return channelValue.Value
    end

    local valueType = typeof(currentValue)
    return PropertyTypes.recompose(channelValue, valueType, instance, propertyName)
end

function keyframe:KeyframeUpdateFromGraph(kfId, newData, propertyName, channelName)
    self:update(kfId, {
        time = newData.time,
        value = newData.value
    })
    return 1
end

function keyframe:getCurrentValueFromInstance(trackId, propertyName)
    local track = self.context.state.tracks[trackId]
    local instance = track and track.instance 

    if not instance then
        warn("No instance found for track: " .. tostring(trackId))
        return 0
    end

    local success, value = pcall(function()
        return instance[propertyName]
    end)

    if success then
        return value
    else
        warn("Could not read property " .. propertyName .. " from " .. instance.Name)
        return 0
    end
end

function keyframe:applyInterpolation(interpolationName)
    self.context:setState(function(prevState)
        local newTracks = table.clone(prevState.tracks)
        -- NEW: Get keyframe selection
        local selection = prevState.selection.keyframes or {}

        for kfId, _ in pairs(selection) do
            for trackId, track in pairs(newTracks) do
                -- Skip director
                if track.type == "director" then continue end

                local nextTrack = table.clone(track)
                local nextProperties = table.clone(nextTrack.properties or {})
                local trackChanged = false

                for i, prop in ipairs(nextProperties) do
                    if prop.channels then
                        local nextProp = table.clone(prop)
                        nextProp.channels = table.clone(nextProp.channels)
                        local propChanged = false

                        for channelName, channelData in pairs(nextProp.channels) do
                            local nextChannel = table.clone(channelData)
                            local nextKeyframes = table.clone(nextChannel.keyframes)
                            local chanChanged = false

                            for j, kf in ipairs(nextKeyframes) do
                                if kf.id == kfId then
                                    local nextKf = table.clone(kf)
                                    nextKf.interpolation = interpolationName
                                    nextKeyframes[j] = nextKf
                                    chanChanged = true
                                end
                            end

                            if chanChanged then
                                nextChannel.keyframes = nextKeyframes
                                nextProp.channels[channelName] = nextChannel
                                propChanged = true
                            end
                        end

                        if propChanged then
                            nextProperties[i] = nextProp
                            trackChanged = true
                        end
                    end
                end

                if trackChanged then
                    nextTrack.properties = nextProperties
                    newTracks[trackId] = nextTrack
                end
            end
        end

        -- NEW: Update ui state separately
        local state = prevState
        return { 
            tracks = newTracks,
            ui = {
                expandedTracks = state.ui.expandedTracks,
                openMenus = {},
                mousePos = state.ui.mousePos,
                canScroll = state.ui.canScroll,
                isInputHandledByUI = state.ui.isInputHandledByUI,
                isPanelOpen = false,
                propertyPickerTrackId = state.ui.propertyPickerTrackId,
                cameraPreviewActive = state.ui.cameraPreviewActive,
                viewSettings = state.ui.viewSettings,
            }
        }
    end)

    self.context.Actions.history:pushHistory()
end

function keyframe:modifyTangentMode(value)
    local selectedRefs = self:getSelectedReferences()
    if #selectedRefs == 0 then return end

    self.context:setState(function(prevState)
        local nextTracks = table.clone(prevState.tracks)

        for _, ref in ipairs(selectedRefs) do
            local track = nextTracks[ref.trackId]
            if not track or track.type == "director" then continue end

            local nextProperties = table.move(track.properties, 1, #track.properties, 1, {})

            for i, prop in ipairs(nextProperties) do
                if prop.name == ref.propName then
                    local nextProp = table.clone(prop)
                    local channel = nextProp.channels[ref.channelName]
                    if not channel then continue end

                    local nextKfs = table.move(channel.keyframes, 1, #channel.keyframes, 1, {})

                    for kIdx, kf in ipairs(nextKfs) do
                        if kf.id == ref.kf.id then
                            local updatedKf = table.clone(kf)
                            updatedKf.tangentMode = value

                            if value == "Mirrored" or value == "Aligned" then
                                local hr = updatedKf.handleRight
                                local hl = updatedKf.handleLeft

                                local angle = math.atan2(hr.y, hr.x)
                                local targetAngle = angle + math.pi

                                local leftMag = (value == "Mirrored") 
                                    and math.sqrt(hr.x^2 + hr.y^2)
                                    or math.sqrt(hl.x^2 + hl.y^2)

                                updatedKf.handleLeft = {
                                    x = math.cos(targetAngle) * leftMag,
                                    y = math.sin(targetAngle) * leftMag
                                }
                            end

                            nextKfs[kIdx] = updatedKf
                            break
                        end
                    end

                    channel.keyframes = nextKfs
                    nextProp.channels[ref.channelName] = channel
                    nextProperties[i] = nextProp
                    break
                end
            end

            track.properties = nextProperties
        end

        return { tracks = nextTracks }
    end)

    if self.context.Actions.history then
        self.context.Actions.history:pushHistory()
    end
end

-- CONTINUED FROM PART 3...

function keyframe:onAction(action, value)
    if not (action and value) then return end

    -- NEW: Get from ui.openMenus
    local menuEntry = self.context.state.ui.openMenus[1]
    local data = menuEntry

    if action == "Interpolation" then
        self:applyInterpolation(value)
    elseif action == "TangentMode" then
        self:modifyTangentMode(value, data)
    elseif action == "Action" and value == "Delete" then
        self:deleteSelectedKeyFrame()
    elseif action == "Action" and value == "CreateKeyframe" then
        if data and data.trackId then
            self:captureKeyframe(data.trackId, data.propName, data.time)
        end
    elseif action == "Action" and value == "CopyKeyFrame" then
        -- NEW: Use selection.keyframes
        local selected = self.context.state.selection.keyframes or {}
        local tracks = self.context.state.tracks
        local newClipboard = {}

        for _, track in pairs(tracks) do
            -- Skip director
            if track.type == "director" then continue end

            for _, prop in ipairs(track.properties or {}) do
                if prop.channels then
                    for channelName, channelData in pairs(prop.channels) do
                        if channelData.keyframes then
                            for _, kf in ipairs(channelData.keyframes) do
                                if selected[kf.id] then
                                    table.insert(newClipboard, {
                                        trackId = track.id,
                                        propertyName = prop.name,
                                        channelName = channelName,
                                        value = kf.value,
                                        easing = kf.easing,
                                        easingDirection = kf.easingDirection,
                                        -- NEW: Use playback.currentTime
                                        offsetTime = math.abs(kf.time - self.context.state.playback.currentTime),
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end

        -- NEW: Update clipboard structure
        self.context:setState({
            clipboard = {
                clips = self.context.state.clipboard.clips,
                keyframes = newClipboard,
                type = "keyframes",
            }
        })
    elseif action == "Action" and value == "CutKeyFrame" then
        local selected = self.context.state.selection.keyframes or {}
        local tracks = self.context.state.tracks
        local newClipboard = {}

        for _, track in pairs(tracks) do
            if track.type == "director" then continue end

            for _, prop in ipairs(track.properties or {}) do
                if prop.channels then
                    for channelName, channelData in pairs(prop.channels) do
                        if channelData.keyframes then
                            for _, kf in ipairs(channelData.keyframes) do
                                if selected[kf.id] then
                                    table.insert(newClipboard, {
                                        trackId = track.id,
                                        propertyName = prop.name,
                                        channelName = channelName,
                                        value = kf.value,
                                        easing = kf.easing,
                                        easingDirection = kf.easingDirection,
                                        offsetTime = math.abs(kf.time - self.context.state.playback.currentTime),
                                    })
                                    self:deleteSelectedKeyFrame()
                                end
                            end
                        end
                    end
                end
            end
        end

        self.context:setState({
            clipboard = {
                clips = self.context.state.clipboard.clips,
                keyframes = newClipboard,
                type = "keyframes",
            }
        })
    elseif action == "Action" and value == "PasteKeyFrame" then
        local clipboard = self.context.state.clipboard.keyframes
        if clipboard then
            self.context.locks.isInternalUpdate = true 

            for _, v in ipairs(clipboard) do
                self:create(
                    v.trackId, 
                    v.propertyName, 
                    self.context.state.playback.currentTime,
                    v.value,
                    v.channelName
                )
            end

            task.defer(function()
                self.context.locks.isInternalUpdate = false
            end)
            self.context.Actions.history:pushHistory()
        end
    elseif action == "Action" and value == "DuplicateKeyFrame" then
        local selection = self.context.state.selection.keyframes or {}
        local tracks = self.context.state.tracks
        local offset = 0.1

        self.context:setState(function(prevState)
            local nextTracks = table.clone(prevState.tracks)
            local newSelection = {}

            for trackId, track in pairs(nextTracks) do
                if track.type == "director" then continue end

                local trackChanged = false
                local nextProperties = table.clone(track.properties or {})

                for i, prop in ipairs(nextProperties) do
                    local propChanged = false
                    if not prop.channels then continue end

                    local nextChannels = table.clone(prop.channels)

                    for channelName, channelData in pairs(nextChannels) do
                        local nextKeyframes = table.clone(channelData.keyframes)
                        local addedAny = false

                        for _, kf in ipairs(channelData.keyframes) do
                            if selection[kf.id] then
                                local newId = gen:GenerateGUID(false)
                                local newKf = table.clone(kf)

                                newKf.id = newId
                                newKf.time = kf.time + offset

                                table.insert(nextKeyframes, newKf)
                                newSelection[newId] = true
                                addedAny = true
                            end
                        end

                        if addedAny then
                            table.sort(nextKeyframes, function(a, b) return a.time < b.time end)
                            local nextChannel = table.clone(channelData)
                            nextChannel.keyframes = nextKeyframes
                            nextChannels[channelName] = nextChannel
                            propChanged = true
                        end
                    end

                    if propChanged then
                        local nextProp = table.clone(prop)
                        nextProp.channels = nextChannels
                        nextProperties[i] = nextProp
                        trackChanged = true
                    end
                end

                if trackChanged then
                    local nextTrack = table.clone(track)
                    nextTrack.properties = nextProperties
                    nextTracks[trackId] = nextTrack
                end
            end

            return {
                tracks = nextTracks,
                selection = {
                    clips = prevState.selection.clips,
                    keyframes = newSelection,
                    tracks = prevState.selection.tracks,
                }
            }
        end)

        self.context.Actions.history:pushHistory()
    end

    -- NEW: Close panel
    local state = self.context.state
    self.context:setState({
        ui = {
            expandedTracks = state.ui.expandedTracks,
            openMenus = state.ui.openMenus,
            mousePos = state.ui.mousePos,
            canScroll = state.ui.canScroll,
            isInputHandledByUI = state.ui.isInputHandledByUI,
            isPanelOpen = false,
            propertyPickerTrackId = state.ui.propertyPickerTrackId,
            cameraPreviewActive = state.ui.cameraPreviewActive,
            viewSettings = state.ui.viewSettings,
        }
    })
end

function keyframe:updateHandle(kfId, side, newHandle, propertyName, channelName)
    self.context:setState(function(prevState)
        local nextTracks = table.clone(prevState.tracks)

        for trackId, track in pairs(nextTracks) do
            if track.type == "director" then continue end

            local nextProperties = table.clone(track.properties or {})

            for i, prop in ipairs(nextProperties) do
                if prop.name == propertyName and prop.channels then
                    local nextProp = table.clone(prop)
                    nextProp.channels = table.clone(nextProp.channels)

                    if nextProp.channels[channelName] then
                        local nextChannel = table.clone(nextProp.channels[channelName])
                        local nextKeyframes = table.clone(nextChannel.keyframes)

                        for j, kf in ipairs(nextKeyframes) do
                            if kf.id == kfId then
                                local nextKf = table.clone(kf)

                                if side == "right" then
                                    nextKf.handleRight = {x = newHandle.x, y = newHandle.y}
                                else
                                    nextKf.handleLeft = {x = newHandle.x, y = newHandle.y}
                                end

                                nextKeyframes[j] = nextKf
                                break
                            end
                        end

                        nextChannel.keyframes = nextKeyframes
                        nextProp.channels[channelName] = nextChannel
                        nextProperties[i] = nextProp
                    end
                end
            end

            local nextTrack = table.clone(track)
            nextTrack.properties = nextProperties
            nextTracks[trackId] = nextTrack
        end

        return { tracks = nextTracks }
    end)
    self.context.Actions.history:pushHistory()
end

function keyframe:destroy()
    self.maid:DoCleaning()
end

return keyframe