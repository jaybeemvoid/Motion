return {
	version = "1.0.1r",
	devMode = false, -- helpful for debugging flux itself
	
	classes = {
        bg = {
            ["background"] = Color3.fromRGB(21, 21, 21),
            ["primary"] = Color3.fromRGB(35, 35, 35),
            ["accent"] = Color3.fromRGB(0, 170, 255),
            ["text-primary"] = Color3.fromRGB(235, 235, 235),
            ["text-secondary"] = Color3.fromRGB(160, 160, 160),
            ["highlight"] = Color3.fromRGB(90, 180, 255),
            ["warning"] = Color3.fromRGB(255, 90, 90),
            ["success"] = Color3.fromRGB(90, 255, 160),
		},
		textColor = {
            ["background"] = Color3.fromRGB(22, 22, 22),
            ["panel"] = Color3.fromRGB(30, 30, 30),
            ["accent"] = Color3.fromRGB(0, 170, 255),
            ["text-primary"] = Color3.fromRGB(235, 235, 235),
            ["text-secondary"] = Color3.fromRGB(160, 160, 160),
            ["highlight"] = Color3.fromRGB(90, 180, 255),
            ["warning"] = Color3.fromRGB(255, 90, 90),
            ["success"] = Color3.fromRGB(90, 255, 160),
        },
        img = {
            ["play"] = "rbxassetid://105280055251253",
            ["reverse"] = "rbxassetid://108023502489765",
        },
		animate = {
			["primary"] = {
				bg = "red-500",
				round = "md",
				s = "lg",
				duration = 0.5,
				easingStyle = Enum.EasingStyle.Linear,
				easingDirection = Enum.EasingDirection.InOut,
				repeatCount = 0,
				reverse = false,
				delayTime = 0,
			},
		}
	},
}