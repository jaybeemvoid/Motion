return function(props)
    return {
        File = {
            {Text = "New Project", Shortcut = "Ctrl+N", Callback = props.onNewProject},
            {Text = "Open Project", Shortcut = "Ctrl+O", Callback = props.onOpenProject},
            {Text = "Save", Shortcut = "Ctrl+S",Callback = props.onSave},
            {Text = "Export Sequence", Callback = props.exportProject},
            {Text = "Project Settings", Callback = props.openSettings},
            {Text = "Export Runtime Engine", Callback = function()
                local runtimeEngine = script.Parent.Parent.Parent.Motion:Clone()
                runtimeEngine.Parent = game.ReplicatedStorage
            end,}
        },
        Edit = {
            {Text = "Undo", Shortcut = "Ctrl+Shift+Z", Callback = props.onUndo},
            {Text = "Redo", Shortcut = "Ctrl+Shift+Y", Callback = props.onRedo},
            {Text = "Cut", Shortcut = "Ctrl+X", Callback = props.onCut},
            {Text = "Copy", Shortcut = "Ctrl+C", Callback = props.onCopy},
            {Text = "Paste", Shortcut = "Ctrl+V", Callback = props.onPaste},
            {Text = "Duplicate", Shortcut = "Ctrl+D", Callback = props.onDuplicate},
            {Text = "Delete", Shortcut = "X", Callback = props.onKeyFrameDeletion},
            {Text = "Select All", Shortcut = "Ctrl+A", Callback = props.onSelectAll},
            {Text = "Deselect All", Shortcut = "Ctrl+Shift+A", Callback = props.onDeselectAll},
            --{Text = "Preferences", Shortcut = "Ctrl+,", Callback = nil},
        },
        View = {
            {Text = "Timeline", Shortcut = "F2", Callback = props.onTimelineSwitch},
            {Text = "Graph Editor", Shortcut = "F3", Callback = props.onGraphSwitch},
            {
                Text = "Show Rule of Thirds", 
                Callback = function() props.onToggleSetting("showGrid") end,
                Divider = true,
            },
            {
                Text = "Show Letterbox", 
                Callback = function() props.onToggleSetting("showLetterbox") end
            },
        },
        --[[Keyframe = {
            { Text = "Insert Keyframe", Shortcut = "K", Callback = props.createKeyFrame },
            { Text = "Set Interpolation", Callback = nil },
            { Text = "Linear", Callback = nil },
            { Text = "Bezier", Callback = nil },
            { Text = "Constant", Callback = nil, Divider = true },
            { Text = "Bake Animation", Callback = nil },
            { Text = "Clean Keyframes", Callback = nil },
        },--]]
        Help = {
            { Text = "Documentation", Shortcut = "<nil>", Callback = function() print("this is the doc") end},
            { Text = "Tutorials", Callback = nil, Divider = true },
            { Text = "About", Callback = nil },
        }
    }
end