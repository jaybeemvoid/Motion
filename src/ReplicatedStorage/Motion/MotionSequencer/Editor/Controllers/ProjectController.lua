local ProjectController = {}

local ProjectSerializer = require(script.Parent.Parent.Parent.Core.Sequencer.ProjectSerializer)

function ProjectController.createNew(name, fps, duration)
    local initialState = {
        name = name or "Untitled",
        fps = tonumber(fps) or 60,
        duration = tonumber(duration) or 5,
        tracks = {},
        trackOrder = {},
        currentTime = 0,
    }

    print("Initializing New Project: " .. name)
    return initialState
end

function ProjectController.loadExisting(sequenceValue)
    local projectData = ProjectSerializer.load(sequenceValue.Value)

    if projectData then
        print("Loaded Project: " .. projectData.name)
        return projectData
    else
        warn("Failed to decode project data!")
        return nil
    end
end

return ProjectController
