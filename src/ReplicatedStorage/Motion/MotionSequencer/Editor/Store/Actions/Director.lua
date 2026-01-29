local director = {}
director.__index = director

local function checkOverlap(clips, start, finish)
    for _, clip in ipairs(clips) do
        if start < clip.endTime and finish > clip.startTime then
            return true
        end
    end
    return false
end

function director.new(layout)
    local self = setmetatable({}, director)
    self.layout = layout
    return self
end

function director:toggleExpansion()
    -- NEW: Director is now in state.tracks.director
    local state = self.layout.state
    local directorTrack = state.tracks.director

    if directorTrack then
        local newTracks = table.clone(state.tracks)
        newTracks.director = table.clone(directorTrack)
        newTracks.director.isExpanded = not directorTrack.isExpanded

        self.layout:setState({ tracks = newTracks })
    end
end

function director:togglePropertyExpansion(clipId, propertyName)
    local state = self.layout.state
    local directorTrack = state.tracks.director

    if not directorTrack or not directorTrack.clips then return end

    local newTracks = table.clone(state.tracks)
    local newDirector = table.clone(directorTrack)
    newDirector.clips = table.clone(directorTrack.clips)

    for i, clip in ipairs(newDirector.clips) do
        if clip.id == clipId and clip.properties and clip.properties[propertyName] then
            local clipCopy = table.clone(clip)
            clipCopy.properties = table.clone(clip.properties)

            local propCopy = table.clone(clipCopy.properties[propertyName])
            propCopy.expanded = not propCopy.expanded

            clipCopy.properties[propertyName] = propCopy
            newDirector.clips[i] = clipCopy

            newTracks.director = newDirector
            self.layout:setState({ tracks = newTracks })
            return
        end
    end
end

function director:updateKeyframe(clipId, propertyName, relativeTime, value)
    local state = self.layout.state
    local directorTrack = state.tracks.director

    if not directorTrack or not directorTrack.clips then return end

    local newTracks = table.clone(state.tracks)
    local newDirector = table.clone(directorTrack)
    newDirector.clips = table.clone(directorTrack.clips)

    for i, clip in ipairs(newDirector.clips) do
        if clip.id == clipId and clip.properties and clip.properties[propertyName] then
            local clipCopy = table.clone(clip)
            clipCopy.properties = table.clone(clip.properties)

            local propCopy = table.clone(clipCopy.properties[propertyName])
            propCopy.keyframes = table.clone(propCopy.keyframes)

            local existingIndex = nil
            for idx, kf in ipairs(propCopy.keyframes) do
                if math.abs(kf.time - relativeTime) < 0.0001 then
                    existingIndex = idx
                    break
                end
            end

            if existingIndex then
                local kfCopy = table.clone(propCopy.keyframes[existingIndex])
                kfCopy.value = value
                propCopy.keyframes[existingIndex] = kfCopy
            else
                table.insert(propCopy.keyframes, {
                    id = "dkf_" .. game:GetService("HttpService"):GenerateGUID(),
                    time = relativeTime,
                    value = value,
                    easing = "Quad",
                    direction = "InOut"
                })

                table.sort(propCopy.keyframes, function(a, b)
                    return a.time < b.time
                end)
            end

            clipCopy.properties[propertyName] = propCopy
            newDirector.clips[i] = clipCopy

            newTracks.director = newDirector
            self.layout:setState({ tracks = newTracks })
            return
        end
    end
end

function director:selectClip(clipId, isMulti)
    -- NEW: Use selection.clips
    local state = self.layout.state
    local newClipSelection = {}

    if isMulti then
        newClipSelection = table.clone(state.selection.clips or {})

        if newClipSelection[clipId] then
            newClipSelection[clipId] = nil
        else
            newClipSelection[clipId] = true
        end
    else
        newClipSelection[clipId] = true
    end

    self.layout:setState({
        selection = {
            clips = newClipSelection,
            keyframes = state.selection.keyframes,
            tracks = state.selection.tracks,
        }
    })
end

function director:moveClip(clipId, newStartTime, newEndTime)
    local state = self.layout.state
    local directorTrack = state.tracks.director

    if not directorTrack or not directorTrack.clips then return end

    local newTracks = table.clone(state.tracks)
    local newDirector = table.clone(directorTrack)
    newDirector.clips = table.clone(directorTrack.clips)

    for i, clip in ipairs(newDirector.clips) do
        if clip.id == clipId then
            local clipCopy = table.clone(clip)
            clipCopy.startTime = newStartTime
            clipCopy.endTime = newEndTime
            newDirector.clips[i] = clipCopy
            break
        end
    end

    newTracks.director = newDirector
    self.layout:setState({ tracks = newTracks })
end

function director:resizeClip(clipId, edge, newTime)
    local state = self.layout.state
    local directorTrack = state.tracks.director

    if not directorTrack or not directorTrack.clips then return end

    local newTracks = table.clone(state.tracks)
    local newDirector = table.clone(directorTrack)
    newDirector.clips = table.clone(directorTrack.clips)

    for i, clip in ipairs(newDirector.clips) do
        if clip.id == clipId then
            local clipCopy = table.clone(clip)

            if edge == "start" then
                local timeDelta = newTime - clip.startTime
                clipCopy.startTime = newTime

                if clipCopy.properties then
                    clipCopy.properties = table.clone(clipCopy.properties)

                    for propName, propData in pairs(clipCopy.properties) do
                        local propCopy = table.clone(propData)
                        propCopy.keyframes = table.clone(propData.keyframes)

                        for kfIdx, kf in ipairs(propCopy.keyframes) do
                            local kfCopy = table.clone(kf)
                            kfCopy.time = kf.time - timeDelta
                            propCopy.keyframes[kfIdx] = kfCopy
                        end
                        clipCopy.properties[propName] = propCopy
                    end
                end

            elseif edge == "end" then
                clipCopy.endTime = newTime
            end

            newDirector.clips[i] = clipCopy
            break
        end
    end

    newTracks.director = newDirector
    self.layout:setState({ tracks = newTracks })
end

function director:addClip(startTime, endTime, cameraInstance)
    local state = self.layout.state
    local directorTrack = state.tracks.director or { clips = {} }

    if checkOverlap(directorTrack.clips or {}, startTime, endTime) then
        warn("Cannot add clip: overlap detected.")
        return nil 
    end

    local newClip = {
        id = "shot_" .. game:GetService("HttpService"):GenerateGUID(false),
        startTime = startTime,
        endTime = endTime,
        duration = endTime - startTime,
        cameraName = cameraInstance and cameraInstance.Name or "Camera_Shot",
        cameraInstance = cameraInstance,
        properties = {
            FOV = {
                keyframes = {
                    { id = "dkf_" .. game:GetService("HttpService"):GenerateGUID(false), time = 0, value = 70, easing = "Quad", direction = "InOut" }
                },
                expanded = false
            },
            Roll = {
                keyframes = {
                    { id = "dkf_" .. game:GetService("HttpService"):GenerateGUID(false), time = 0, value = 0, easing = "Quad", direction = "InOut" }
                },
                expanded = false
            }
        },
        color = Color3.fromHSV(math.random(), 0.6, 0.8)
    }

    local newTracks = table.clone(state.tracks)
    local newDirector = table.clone(directorTrack)
    newDirector.clips = table.clone(directorTrack.clips or {})

    table.insert(newDirector.clips, newClip)

    table.sort(newDirector.clips, function(a, b)
        return a.startTime < b.startTime
    end)

    newTracks.director = newDirector
    self.layout:setState({ tracks = newTracks })

    return newClip.id
end

function director:deleteSelectedClips()
    local state = self.layout.state
    local directorTrack = state.tracks.director
    local selection = state.selection.clips

    if not directorTrack or not directorTrack.clips or not selection then return end

    local newClips = {}
    for _, clip in ipairs(directorTrack.clips) do
        if not selection[clip.id] then
            table.insert(newClips, clip)
        end
    end

    local newTracks = table.clone(state.tracks)
    local newDirector = table.clone(directorTrack)
    newDirector.clips = newClips

    newTracks.director = newDirector

    self.layout:setState({ 
        tracks = newTracks,
        selection = {
            clips = {},
            keyframes = state.selection.keyframes,
            tracks = state.selection.tracks,
        }
    })
end

function director:toggleCameraPreview(enabled)
    local state = self.layout.state
    
    self.layout.Actions.utils:setState("ui", {cameraPreviewActive = enabled})

    if not enabled then
        workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end
end

function director:getActiveClipAtTime(time)
    local directorTrack = self.layout.state.tracks.director
    if not directorTrack or not directorTrack.clips then return nil end

    for _, clip in ipairs(directorTrack.clips) do
        if time >= clip.startTime and time < clip.endTime then
            return clip
        end
    end

    return nil
end

return director