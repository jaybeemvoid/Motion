local Roact = require(script.Parent.Parent.Parent.Roact)
local Start = Roact.Component:extend("Start")

local StartScreenComponent = require(script.Parent.Parent.Components.Start.StartScreen)

function Start:render()
    return Roact.createElement(StartScreenComponent, {
        onOpenProject = self.props.onOpenProject,
        onCreate = self.props.onCreate,
    })
end

return Start