--!strict
local Types = require(script.Parent.Parent.Store.Types)

local ErrorHandler = {}

function ErrorHandler.new(code: number, message: string, context: string?): Types.Error
    local newError: Types.Error = {
        Code = code,
        Message = message,
        Context = context or "Unknown Module",
        Timestamp = os.time()
    }
    return newError
end

function ErrorHandler.report(err: Types.Error)
    local formattedTime = os.date("%H:%M:%S", err.Timestamp)
    warn(string.format(
        "[%s] MOTION_SEQUENCER_ERR_%d in %s: %s",
        formattedTime,
        err.Code,
        err.Context,
        err.Message
        ))
end

return ErrorHandler