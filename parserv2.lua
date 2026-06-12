---@type Lpeg
local lpeg = require("lpeg")
local P, C, Ct, V, S = lpeg.P, lpeg.C, lpeg.Ct, lpeg.V, lpeg.S
local R = lpeg.R
local Cc =lpeg.Cc
local Cs = lpeg.Cs

local ws = S(" \n\t")^0
function Token(pattern)
    if type(pattern) == "string" then
        return P(pattern) * ws
    end
    return pattern *ws
end

local alpha = R("az","AZ") + P("_")
local numerical = R("09")
local alphaNumerical = alpha + numerical
local identifier = alpha * alphaNumerical^0


---@param key string
function Keyword(key)
    return P(key) * -alphaNumerical * ws
end


local G = {} --grammar
G.LuaMode = V("LuaMode")
G.TextMode = V("TextMode")
G.LuaCode = V("LuaCode")
G.Text = V("Text")
local reservedkw = P("if") + P("for") + P("while") + P("else") + P("elseif") + P("end")
local stopConditions =  P("</@>") + P("<@") +P("@") + P("}") + P("$(") + P("${")

G.Text = C((P("{") * G.Text * P("}") + P(1) - stopConditions)^1) / function (text)
    return string.format("buffer[#buffer + 1] = %q\n", string.gsub(text, "%s+", " "))
end
G.InnerLua = (P("{") * V("InnerLua") * P("}") + P(1) - S("}@"))^1

G.LuaCode = C(
G.InnerLua
)

G.For = P("@for ") * C((P(1) - P("do"))^0 * P("do")) * G.TextMode * P("@end")/function (head, generator)
    return {
        "for ", head,"\n", generator, "end\n"
    }
end
G.While = P("@while ") * C((P(1) - P("do"))^0 * P("do")) * G.TextMode * P("@end")/function (head, generator)
    return {
        "while ", head,"\n", generator, "end\n"
    }
end

local condBody= C((P(1) - P("then"))^0 * P("then"))
G.If = P("@if ") *condBody *G.TextMode * 
    Ct((P("@elseif") * condBody * G.TextMode)^0) *  
    (P("@else") * G.TextMode)^-1 * 
P("@end")/function (ifCond, ifGen, elseifs, elsegen)
    local result = {"if ", ifCond,"\n", ifGen,"\n"}
    for i = 1, #elseifs,2 do
        result[#result+1] = "elseif "
        result[#result+1] = elseifs[i]
        result[#result+1] = "\n"
        result[#result+1] = elseifs[i + 1]
        result[#result+1] = "\n"
    end
    if elsegen then
        result[#result+1] = "else\n"
        result[#result+1] = elsegen
    end
    result[#result+1] = "end\n"
    return result
end
function noop(_,_,_) end

local stringLiteral = C(P('"') * (P(1) - P('"'))^0 * P('"'))
G.InnerScope =(P("{")* V("InnerScope") *P("}") +  P(1) - S("{}"))^1
G.BalancedScope = P("{") *C(G.InnerScope) * P("}") + P("{}") * Cc(nil)
local attribute = C(identifier) * (P("=") * (stringLiteral + G.BalancedScope) + Cc("true"))
local attributes= Ct(Token(attribute)^0) /function (list)
    local result = {"{"}
    for i = 1, #list, 2 do
        result[#result+1] = list[i]
        result[#result+1] = " = "
        result[#result+1] = list[i +1]
        result[#result+1] = ", "
    end
    result[#result+1] = "}"
    return result
end
G.Component = P("<@") * Token(C((identifier * (P(".") * identifier)^0))) * attributes * (P("/>") + P(">") * G.TextMode * P("</@>"))/
function (name,attributes, generator)
    local genwrapped = generator and {"function(_,_,_)",generator,"end"} or "noop"
    return {name, "(", genwrapped,", ", attributes, ", ctx)\n"} -- sadece side effect olduğu için
    
end


G.BalancedParen = P("(") * ( (P(1) - S("()")) + V("BalancedParen") )^0 * P(")")
G.TExpr = P("@")*C(G.BalancedParen) /function (expr)
    return string.format("buffer[ctx.counter] = tostring(%s)\nctx.counter = ctx.counter + 1\n", expr)
end

G.FunCall = P("@") * -reservedkw * C(identifier * (P(".") *identifier)^0 * G.BalancedParen)/function (fun)
    return string.format("buffer[ctx.counter] = tostring(%s)\nctx.counter = ctx.counter + 1\n", fun)
end

G.Identifier = P("@") * -reservedkw * C(identifier * (P(".") *identifier)^0)/function (identifier)
    return string.format("buffer[ctx.counter] = tostring(%s)\nctx.counter = ctx.counter + 1\n",identifier)
end
G.Patch = P("$") *C(G.BalancedParen)/function (expr)
    return string.format(
    [[ctx.counter = ctx.counter + 1
    local idx = ctx.counter
    buffer[idx]= ""
    local _old_patch = _patch
    _patch = function() buffer[idx] =%s _old_patch() end
    ]],expr)
end

G.PatchText = P("${") * G.TextMode * P("}") /function (textGen)
    return {[[ctx.counter = ctx.counter + 1
        local idx = ctx.counter
        buffer[idx]= ""
        local _old_patch = _patch
        _patch = function()
            local ogBuffer = buffer
            local buffer = {}
            ]]
            ,textGen,[[
            ogBuffer[idx]= table.concat(buffer)
            _old_patch()
        end
    ]]}
end

G.ToLua = P("@{") * G.LuaMode^-1 * P("}")
G.ToText = P("@{") * G.TextMode^-1 * P("}")
local atEscape = P("\\@") * Cc("@")
G.TextMode = Ct((atEscape + G.PatchText + G.Patch + G.FunCall+ G.TExpr + G.For + G.While + G.If + G.Component +G.ToLua + G.Identifier+ G.Text)^1)/function (generators)
    return {"do\n", generators, "end\n"}
end
G.LuaMode = Ct((G.ToText+(G.LuaCode* Cc("\n")))^1)
G[1] = "TextMode"
local grammar = P(G)
local function Flatten(tbl,buffer)
    local isTop = buffer == nil
    buffer = buffer or {}
    for i = 1, #tbl do
        local item = tbl[i]
        if type(item) == "table" then
            Flatten(item,buffer)
            goto continue
        end
        buffer[#buffer+1] = item
        ::continue::
    end


    if isTop then
        return table.concat(buffer)
    end
end
local function GenerateCode(code)
    local code = {
        [[function(slot, attr, ctx)
            local _patch = function() end
            ctx.buffer = ctx.buffer or {}
            local buffer = ctx.buffer
            ctx.counter = ctx.counter or 1
        ]]
        ,grammar:match(code),[[
        _patch()
        return buffer
    end]]
    }
    local code = Flatten(code)
    return code
end



---@param code string
---@return Component
local function CompileComponent(code,global,name)
    local code = [[function noop(_,_,_) end return]] .. GenerateCode(code)
    local mod,err = load(code,name or "template","t",global)
    if err or not mod then
        print(code)
        error(err)
    end

    return mod()
end

---@alias Component fun(slot:Component, attr:table, ctx:table):nil


return {
    CompileComponent = CompileComponent,
    GenerateCode = GenerateCode
}