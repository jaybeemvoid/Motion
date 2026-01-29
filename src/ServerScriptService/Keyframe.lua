local maid = require(script.Parent.Parent.Parent.Parent.Util.Maid)
local RQuat = require(script.Parent.Parent.Parent.Parent.Core.Math.RQuat)
local gen = game:GetService("HttpService")

local DynamicProperties = require(script.Parent.Parent.DynamicProperties)
local PropertyTypes = require(script.Parent.Parent.PropertyRegistery)

local function parseDirectorKeyframeId(kfId)
    local parts = kfId:split("::") -- Use the unique separator
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

function keyframe.new(context) -- types later
    local self = setmetatable({}, keyframe)

    self.context = context

    self.maid = maid.new()

    self.autoKeyConnections = {}

    return self
end

function keyframe:create(trackId, propertyName, time, value, specificChannel)
    self.context:setState(function(prevState)
        local fps = prevState.activeProject.fps or 60 
        local snappedTime = math.round(time * fps) / fps

        local nextTracks = table.clone(prevState.tracks)
        local track = nextTracks[trackId]
        if not track then return end

        -- Ensure property exists
        local hasProperty, existingProp = DynamicProperties.hasProperty(track, propertyName)
        if not hasProperty then
            track = DynamicProperties.addPropertyToTrack(track, propertyName, track.instance)
            nextTracks[trackId] = track
        end

        local nextProperties = table.clone(track.properties)

        -- Decompose value using unified system
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

                    -- Check for existing keyframe at this time
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
    local selection = self.context.state.selection
    local tracks = self.context.state.tracks
    local found = {}

    if not next(selection) then return found end

    for trackId, track in pairs(tracks) do
        for _, prop in ipairs(track.properties) do
            for channelName, channel in pairs(prop.channels) do
                for _, kf in ipairs(channel.keyframes) do
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

    -- Initialize euler tracking for CFrames
    if typeof(lastKnownValue) == "CFrame" then
        local quat = RQuat.fromCFrame(lastKnownValue)
        local rx, ry, rz = quat:toEulerAngles()
        lastEuler = {
            rx = math.deg(rx),
            ry = math.deg(ry),
            rz = math.deg(rz)
        }
    end

    self.autoKeyConnections[connectionKey] = instance:GetPropertyChangedSignal(propertyName):Connect(function()
        if self.context.locks.isInternalUpdate then return end
        if self.context.state.isPlaying then return end

        local track = self.context.state.tracks[trackId]
        if not track then
            self.autoKeyConnections[connectionKey]:Disconnect()
            return
        end

        local newValue = instance[propertyName]
        local changedChannels = {}

        local POS_THRESHOLD = 0.001
        local ROT_THRESHOLD_DEG = 0.1

        if typeof(newValue) == "CFrame" then
            local currentRotation = instance.Rotation -- Vector3 in degrees [[NIL]]

            local newEuler = {
                rx = currentRotation.X,
                ry = currentRotation.Y,
                rz = currentRotation.Z
            }

            if lastEuler then
                -- Use the unwrapAngle to prevent 0 -> 360 snaps
                newEuler.rx = unwrapAngle(newEuler.rx, lastEuler.rx)
                newEuler.ry = unwrapAngle(newEuler.ry, lastEuler.ry)
                newEuler.rz = unwrapAngle(newEuler.rz, lastEuler.rz)

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

        elseif typeof(newValue) == "Vector3" then
            if (newValue - lastKnownValue).Magnitude > 0.001 then
                if math.abs(newValue.X - lastKnownValue.X) > 0.001 then
                    changedChannels.X = newValue.X
                end
                if math.abs(newValue.Y - lastKnownValue.Y) > 0.001 then
                    changedChannels.Y = newValue.Y
                end
                if math.abs(newValue.Z - lastKnownValue.Z) > 0.001 then
                    changedChannels.Z = newValue.Z
                end
            end

        elseif typeof(newValue) == "Color3" then
            local isDifferent = false
            if typeof(lastKnownValue) ~= "Color3" then
                isDifferent = true
            elseif (Vector3.new(newValue.R, newValue.G, newValue.B) - 
                Vector3.new(lastKnownValue.R, lastKnownValue.G, lastKnownValue.B)).Magnitude > 0.001 then
                isDifferent = true
            end

            if isDifferent then
                changedChannels.R = newValue.R
                changedChannels.G = newValue.G
                changedChannels.B = newValue.B
            end
        else
            if newValue ~= lastKnownValue then
                changedChannels.Value = newValue
            end
        end

        if next(changedChannels) then
            for channelName, channelValue in pairs(changedChannels) do
                self:create(
                    trackId,
                    propertyName,
                    self.context.state.currentTime,
                    channelValue,
                    channelName
                )
            end
        end

        lastKnownValue = newValue
    end)
    self.maid:GiveTask(self.autoKeyConnections[connectionKey])
end

function keyframe:captureKeyframe(trackId, propertyName, kTime)
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

        for i, prop in ipairs(nextProperties) do
            if prop.name == propertyName then
                local nextProp = table.clone(prop)
                nextProp.channels = nextProp.channels or {}

                for channelName, val in pairs(components) do
                    nextProp.channels[channelName] = nextProp.channels[channelName] or { keyframes = {} }

                    local channel = nextProp.channels[channelName]
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
        local newSelection = {}

        if not kfs and mode == "All" then
            -- Regular keyframes
            for _, track in pairs(prevState.tracks) do
                for _, prop in ipairs(track.properties) do
                    if prop.channels then
                        for _, channel in pairs(prop.channels) do
                            for _, kf in ipairs(channel.keyframes) do
                                newSelection[kf.id] = true
                            end
                        end
                    end
                end
            end

            -- Director keyframes
            if prevState.director and prevState.director.clips then
                for _, clip in ipairs(prevState.director.clips) do
                    if clip.properties then
                        for propName, propData in pairs(clip.properties) do
                            if propData.keyframes then
                                for _, kf in ipairs(propData.keyframes) do
                                    -- USE THE ACTUAL KF ID, NOT THE INDEX
                                    if kf.id then
                                        newSelection[kf.id] = true
                                    end
                                end
                            end
                        end
                    end
                end
            end

            return { selection = newSelection }
        end

        if not kfs and mode == "None" then
            return { selection = {} }
        end

        if mode == "Add" then
            newSelection = table.clone(prevState.selection)
        end

        if typeof(kfs) == "table" then
            for kId, _ in pairs(kfs) do
                newSelection[kId] = true
            end
        elseif typeof(kfs) == "string" then
            newSelection[kfs] = true
        end

        return { selection = newSelection }
    end)
end

function keyframe:move(updates)
    self.context:setState(function(prevState)
        local nextTracks = table.clone(prevState.tracks)
        local nextDirector = prevState.director and table.clone(prevState.director)
        local anyChanges = false

        for kfId, newTime in pairs(updates) do
            for trackId, track in pairs(nextTracks) do
                for propIdx, prop in ipairs(track.properties) do
                    if prop.channels then
                        for chanName, chanData in pairs(prop.channels) do
                            for kfIdx, kf in ipairs(chanData.keyframes) do
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

        if nextDirector and nextDirector.clips then
            nextDirector.clips = table.clone(nextDirector.clips)

            for kfId, newAbsoluteTime in pairs(updates) do
                for clipIdx, clip in ipairs(nextDirector.clips) do
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
                                        nextDirector.clips[clipIdx] = clipCopy
                                        anyChanges = true
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end

        if anyChanges then
            return {
                tracks = nextTracks,
                director = nextDirector
            }
        end
    end)
end

function keyframe:deleteSelectedKeyFrame()
    self.context:setState(function(prevState)
        local nextTracks = table.clone(prevState.tracks)
        local nextDirector = prevState.director and table.clone(prevState.director) or nil
        local selection = prevState.selection
        local anyChanges = false

        -- 1. Handle Director Keyframe Deletion
        if nextDirector and nextDirector.clips then
            local directorChanged = false
            -- Shallow clone the clips array
            nextDirector.clips = table.clone(nextDirector.clips)

            for clipIdx, clip in ipairs(nextDirector.clips) do
                local clipCopy = nil
                local clipChangedInThisLoop = false

                for propName, propData in pairs(clip.properties) do
                    if propData.keyframes then
                        local originalCount = #propData.keyframes
                        local filteredKeyframes = {}

                        -- Filter based on the STABLE kf.id
                        for _, kf in ipairs(propData.keyframes) do
                            if not selection[kf.id] then
                                table.insert(filteredKeyframes, kf)
                            end
                        end

                        -- If the counts differ, something was deleted
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
                    nextDirector.clips[clipIdx] = clipCopy
                end
            end

            if directorChanged then
                anyChanges = true
            end
        end

        -- 2. Handle Regular Track Keyframe Deletion
        for trackId, track in pairs(nextTracks) do
            local nextTrack = nil
            local trackChanged = false

            for i, prop in ipairs(track.properties) do
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

        -- 3. Return updated state only if changes occurred
        if anyChanges then
            return {
                tracks = nextTracks,
                director = nextDirector,
                selection = {} -- Clear selection so we don't try to move deleted keys
            }
        end

        return nil -- No state update if nothing was deleted
    end)

    -- Only push to history if we actually deleted something
    -- (You might want to wrap this in a check if you have a way to know if setState ran)
    self.context.Actions.history:pushHistory()
end

function keyframe:update(kfId, newData)
    self.context.locks.isInternalUpdate = true

    self.context:setState(function(prevState)
        local nextTracks = table.clone(prevState.tracks)
        local anyChanges = false

        local realId = kfId:split("_")[1]

        for trackId, track in pairs(nextTracks) do
            local nextProperties = table.clone(track.properties)
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

        for kfId, _ in pairs(prevState.selection) do
            for trackId, track in pairs(newTracks) do
                local nextTrack = table.clone(track)
                local nextProperties = table.clone(nextTrack.properties)
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

        return { 
            tracks = newTracks,
            isPanelOpen = false,
            openMenus = {}
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
            if not track then continue end

            -- Clone the properties array
            local nextProperties = table.move(track.properties, 1, #track.properties, 1, {})

            for i, prop in ipairs(nextProperties) do
                if prop.name == ref.propName then
                    local nextProp = table.clone(prop)
                    local channel = nextProp.channels[ref.channelName]
                    if not channel then continue end

                    -- Clone the keyframes array
                    local nextKfs = table.move(channel.keyframes, 1, #channel.keyframes, 1, {})

                    for kIdx, kf in ipairs(nextKfs) do
                        if kf.id == ref.kf.id then
                            local updatedKf = table.clone(kf)
                            updatedKf.tangentMode = value -- "Mirrored", "Aligned", or "Free"

                            -- FORCE ALIGNMENT: 
                            -- If switching to a locked mode, snap handles into a line immediately
                            if value == "Mirrored" or value == "Aligned" then
                                local hr = updatedKf.handleRight
                                local hl = updatedKf.handleLeft

                                -- Master angle comes from the Right handle
                                local angle = math.atan2(hr.y, hr.x)
                                local targetAngle = angle + math.pi -- 180 degrees opposite

                                local leftMag = (value == "Mirrored") 
                                    and math.sqrt(hr.x^2 + hr.y^2) -- Match right length
                                    or math.sqrt(hl.x^2 + hl.y^2)  -- Keep own length

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

    -- Save to undo history if you have it
    if self.context.Actions.history then
        self.context.Actions.history:pushHistory()
    end
end

function keyframe:onAction(action, value)
    if not (action and value) then return end

    local menuEntry = self.context.state.openMenus[1] --["context"]
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
        local selected = self.context.state.selection
        local tracks = self.context.state.tracks
        local newClipboard = {}

        for _, track in pairs(tracks) do
            for _, prop in ipairs(track.properties) do
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
                                        offsetTime = math.abs(kf.time - self.context.state.currentTime),
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
        self.context:setState({ clipboard = newClipboard })
    elseif action == "Action" and value == "CutKeyFrame" then
        local selected = self.context.state.selection
        local tracks = self.context.state.tracks
        local newClipboard = {}

        for _, track in pairs(tracks) do
            for _, prop in ipairs(track.properties) do
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
                                        offsetTime = math.abs(kf.time - self.context.state.currentTime),
                                    })
                                    self:deleteSelectedKeyFrame()
                                end
                            end
                        end
                    end
                end
            end
        end
        self.context:setState({ clipboard = newClipboard })
    elseif action == "Action" and value == "PasteKeyFrame" then
        local clipboard = self.context.state.clipboard
        if clipboard then
            self.context.locks.isInternalUpdate = true 

            for _, v in ipairs(clipboard) do
                self:create(
                    v.trackId, 
                    v.propertyName, 
                    self.context.state.currentTime,
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
        local selection = self.context.state.selection
        local tracks = self.context.state.tracks
        local offset = 0.1 -- Small time offset so they don't perfectly overlap

        self.context:setState(function(prevState)
            local nextTracks = table.clone(prevState.tracks)
            local newSelection = {}
            for trackId, track in pairs(nextTracks) do
                local trackChanged = false
                local nextProperties = table.clone(track.properties)

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
                selection = newSelection
            }
        end)

        self.context.Actions.history:pushHistory()
    end
    self.context:setState({isPanelOpen = false})
end

function keyframe:updateHandle(kfId, side, newHandle, propertyName, channelName)
    self.context:setState(function(prevState)
        local nextTracks = table.clone(prevState.tracks)

        for trackId, track in pairs(nextTracks) do
            local nextProperties = table.clone(track.properties)

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