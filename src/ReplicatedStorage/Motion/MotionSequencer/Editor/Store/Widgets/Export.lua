return {
    Metadata = {
        ProjectName = {title = "Project Name", type = "Text", ReadOnly = false},
        FramesPerSecond = {title = "Frames Per Second", type = "Text", ReadOnly = false},
        Duration = {title = "Total Duration (seconds)", type = "Text", ReadOnly = false},
    },
    ExportSettings = {
        FileName = {title = "Export File Name", type = "Text", ReadOnly = false, placeholder = "MyAnimation"},
        IncludeMetadata = {title = "Include Metadata", type = "Toggle", ReadOnly = false},
        ExportDirectory = {title = "Export Directory", type = "Dropdown", ReadOnly = false, options = {"ReplicatedStorage", "ServerStorage"}},
    },
    Advanced = {
        ApplyRootMotion = {title = "Apply Root Motion", type = "Toggle", ReadOnly = false},
        IncludeDirectorTrack = {title = "Include Director Track", type = "Toggle", ReadOnly = false},
        IncludeAnimationTracks = {title = "Include Animation Tracks", type = "Toggle", ReadOnly = false},
    },
}

--[[

Metadata = {
        ProjectName = {title = "Project Name", type = "Text", ReadOnly = false},
        FramesPerSecond = {title = "Frames Per Second", type = "Text", ReadOnly = false},
        Duration = {title = "Total Duration (seconds)", type = "Text", ReadOnly = false},
    },
    ExportSettings = {
        FileName = {title = "Export File Name", type = "Text", ReadOnly = false, placeholder = "MyAnimation"},
        ExportFormat = {title = "Export Format", type = "Text", ReadOnly = true, placeholder = "Motion Sequence (.motion)"},
        ExportDirectory = {title = "Export Directory", type = "Dropdown", ReadOnly = false, options = {"Workspace", "ReplicatedStorage", "ServerStorage"}},
    },
    RangeSettings = {
        UseCustomRange = {title = "Custom Time Range", type = "Toggle", ReadOnly = false},
        StartTime = {title = "Start Time (seconds)", type = "Text", ReadOnly = false, placeholder = "0"},
        EndTime = {title = "End Time (seconds)", type = "Text", ReadOnly = false, placeholder = "Auto"},
    },
    ExportOptions = {
        IncludeMetadata = {title = "Include Metadata", type = "Toggle", ReadOnly = false},
        IncludeDirectorTrack = {title = "Include Director Track", type = "Toggle", ReadOnly = false},
        IncludeAnimationTracks = {title = "Include Animation Tracks", type = "Toggle", ReadOnly = false},
        OptimizeKeyframes = {title = "Optimize Keyframes", type = "Toggle", ReadOnly = false},
        PrettyPrint = {title = "Pretty Print Output", type = "Toggle", ReadOnly = false},
    },
    
    ]]