local function noop(_, _, _) end

return function(slot, attr, ctx)
    local _patch = function() end
    local _ENV = ctx
    ctx.buffer = ctx.buffer or {}
    offset = offset or 1
    do
        buffer[offset] = " "
        offset = offset + 1

        local function H(slot, attr, _)
            if attr.bebold then
                do
                    buffer[offset] = "fuck you"
                    offset = offset + 1
                end
            else
                do
                    buffer[offset] = "<h"
                    offset = offset + 1
                    buffer[offset] = tostring(attr.priority)
                    offset = offset + 1
                    buffer[offset] = ">"
                    offset = offset + 1
                    slot(noop, {}, ctx)
                    buffer[offset] = "</h"
                    offset = offset + 1
                    buffer[offset] = tostring(attr.priority)
                    offset = offset + 1
                    buffer[offset] = ">"
                    offset = offset + 1
                end
            end
        end
        local function add(a, b)
            return a + b
        end
        local lib = { add = add, baba = "isyou" }

        buffer[offset] = " "
        offset = offset + 1
        H(function(_, _, _)
            do
                buffer[offset] = " etto ne"
                offset = offset + 1
            end
        end, { priority = 1, bebold = true, }, ctx)
        buffer[offset] = " "
        offset = offset + 1
        if false then
            do
                buffer[offset] = " heya world "
                offset = offset + 1
            end
        else
            do
                buffer[offset] = " 2 + 3 is "
                offset = offset + 1
                buffer[offset] = tostring(lib.add(add(1, 1), 3))
                offset = offset + 1
                buffer[offset] = " just like "
                offset = offset + 1
                buffer[offset] = tostring((2 + 3))
                offset = offset + 1
                buffer[offset] = " belki tan─▒m─▒ de─şi┼şir "
                offset = offset + 1
                local idx = offset
                offset = offset + 1
                buffer[idx] = ""
                local _old_patch = _patch
                _patch = function()
                    buffer[idx] = (2 + 3)
                    _old_patch()
                end
                buffer[offset] = " "
                offset = offset + 1
            end
        end
        buffer[offset] = " "
        offset = offset + 1
    end

    _patch()
    return buffer
end
