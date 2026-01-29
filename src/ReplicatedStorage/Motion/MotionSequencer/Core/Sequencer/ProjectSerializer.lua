local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local Encoder, Decoder = require(script.Parent.Parent.Serialization.Encode), require(script.Parent.Parent.Serialization.Decode)

local ProjectSerializer = {}

-- Helper to get a string path from an instance
local function getInstancePath(instance)
    if not instance then return nil end
    return instance:GetFullName()
end

-- Helper to find an instance from a string path
local function getInstanceFromPath(path)
    if not path then return nil end
    local segments = string.split(path, ".")
    local current = game

    for _, name in ipairs(segments) do
        current = current:FindFirstChild(name)
        if not current then return nil end
    end
    return current
end

local function getOrQueryResultTag(instance)
    if not instance then return nil end

    -- Look for an existing ID tag we've given this object before
    local tags = CollectionService:GetTags(instance)
    for _, tag in ipairs(tags) do
        if string.match(tag, "^MC_ID_") then -- "MotionCore ID"
            return tag
        end
    end

    -- If no tag exists, create a new unique one
    local newTag = "MC_ID_" .. string.gsub(HttpService:GenerateGUID(false), "-", "")
    CollectionService:AddTag(instance, newTag)
    return newTag
end

function ProjectSerializer.save(projectName, trackState, trackOrderState, duration, fps)
    local tracksToSave = {}

    for id, track in pairs(trackState) do
        local trackCopy = table.clone(track)

        -- 1. Store Path (Legacy/Fast lookup)
        trackCopy.instancePath = getInstancePath(track.instance)

        -- 2. Store Unique Tag (The "Unbreakable" link)
        trackCopy.uniqueId = getOrQueryResultTag(track.instance)

        trackCopy.instance = nil
        tracksToSave[id] = trackCopy
    end

    local projectFiles = {
        name = projectName,
        version = "1.0.0",
        updated = os.time(),
        tracks = tracksToSave,
        trackOrder = trackOrderState,
        duration = duration,
        fps = fps,
    }

    local jsonStr = Encoder(projectFiles)

    local container = game.ReplicatedStorage:FindFirstChild("MotionCore").Sequences
    if not container then return -1 end

    local saveObject = container:FindFirstChild(projectName) or Instance.new("StringValue")
    saveObject.Name = projectName
    saveObject.Value = jsonStr
    
    saveObject:SetAttribute("LastSaved", projectFiles.updated)
    
    saveObject.Parent = container

    print("Project '" .. projectName .. "' saved successfully to " .. container.Name)
end

function ProjectSerializer.load(jsonStr)
    local projectData = Decoder(jsonStr)
    if not projectData then return nil end

    for id, track in pairs(projectData.tracks) do
        -- Step 1: Try finding by Path
        local foundInstance = getInstanceFromPath(track.instancePath)

        -- Step 2: If path failed, try finding by Unique ID
        if not foundInstance and track.uniqueId then
            local taggedObjects = CollectionService:GetTagged(track.uniqueId)
            foundInstance = taggedObjects[1] -- Grab the first (and only) match

            if foundInstance then
                print("Fixed broken link for track: " .. track.name .. " using Unique ID.")
            end
        end

        track.instance = foundInstance

        if not track.instance then
            warn("Could not find object for track: " .. track.name)
        end
    end

    return projectData
end

return ProjectSerializer