--[[
    This controls all properties related to widgets
    
    Read-Only property is there for future-proof
]]

return {
    Metadata = {
        ProjectName = {title = "Project Name", type = "Text", ReadOnly = false},
        FramesPerSecond = {title = "Frames Per Second", type = "Text", ReadOnly = false},
        Duration = {title = "Total Duration", type = "Text", ReadOnly = false},
    },

    View = {
        Grid = {title = "Grid", type = "Toggle", ReadOnly = false},
        Letterbox = {title = "Letterbox", type = "Toggle", ReadOnly = false}
    },
}