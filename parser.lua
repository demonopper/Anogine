
local lpeg = require("lpeg")
local P, C, Ct, V, S = lpeg.P, lpeg.C, lpeg.Ct, lpeg.V, lpeg.S
local R = lpeg.R
local Cc =lpeg.Cc


---@param b string
---@param e string
---@return LPegPattern
local function balanced(b, e)
    local bp, ep = P(b), P(e)
    return P { bp * ((1 - bp - ep) + V(1)) ^ 0 * ep }
end

local G = {"TextMode"}
G.LuaMode = V("LuaMode")
G.LuaCode = C((P(1) - (P("${{")+P("{{") + P("}}"))) ^ 1)/function (code)
    return {code, "\n"} -- table allocation is just cost of lazy concat and its reasonable since code len is unknown but table gen cost is constant
end
G.Text = C((P(1) - (P("<@")+ P("</@>")+P("${")+P("{{") + P("}}"))) ^ 1)/function (text)
    return string.format("buffer[#buffer +1] = %q\n", text)
end

local expr = C(((P(1) - S"{}") + balanced("{", "}"))^0)
G.Expr = P("${") * expr * P("}") / function (code)
    return {"val = ", code, "\nbuffer[#buffer + 1] = type(val) == 'table' and val or tostring(val)\n"} -- reeval önleme
end
G.ToLua = P("{{") * G.LuaMode * P("}}") / function(luacode)
    return {" do\n", luacode, " end\n"}
end

local alpha = R("az","AZ") + P("_")
local numerical = R("09")
local identifier = alpha* (alpha + numerical)^0

local ws = S(" \n\t")^0
function Token(rule)
    if type(rule) == "string" then
        rule = P(rule)
    end
    return rule * ws
end


G.TextMode = Ct((G.ToLua + G.Expr +V("Component")+ G.Text) ^0) 
G.ToText = P("{{") * G.TextMode * P("}}")
G.BufferExpr = P("${{") * G.TextMode * P("}}") / function (generator)
    return {
        "(function()\nlocal tbuffer = buffer\nbuffer = {}\n",generator,"local newBuffer = buffer\nbuffer=tbuffer\nreturn newBuffer end)()"
    }
end

local simpleString = P('"') * C((P(1)- P("\n"))^1) * P('"')/function (s)
    return string.format("%q",s)
end
local attr = Token(C(identifier)) * Token("=") * Token(simpleString + (Token("{") * expr * Token("}")))/function (name,value)
    return {name,"=",value} 
end
local attributes = Ct(attr^0)/function (values)
    local result = {"{"}
    for i = 1, #values do
        result[#result+1] = values[i]
        result[#result+1] = ","
    end
    result[#result+1] = "}"
    return result
end


G.Component = P("<@") * Token(C(identifier)) * Token(attributes)* (P(">") * G.TextMode * P("</@>") + P("/>"))/function (name,attr, textGen)
    textGen = textGen or ""
    return {[[
    if type(]],name,[[) == "function" then
    
        local tbuffer = buffer --luada shadowing var sıkıntı yok sonra maine bi kere tanımlar locali kaldırırım
        buffer = {}
        ]],textGen,[[
        local newBuffer = buffer
        buffer = tbuffer
        buffer[#buffer +1] =]], name, "(newBuffer,",attr or "{}",[[)
    elseif ]],name,[[ == nil then
    else
        buffer[#buffer +1] = type(]],name,[[) == "table" and ]],name,[[ or tostring(]],name,[[)
    end
    ]]
}
end
G.LuaMode = Ct((G.BufferExpr+G.ToText + G.LuaCode) ^0)

local Grammar = P(G)

function Flatten(tbl,buffer)
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


---@param templ string
---@return Component
function BakeTemplate(templ)
    
    local code = {[[return function(slot,attr)
    local ownedCtx=false
    if not ctx then ownedCtx=true
    _ENV = setmetatable({ctx = { styles = {} }}, {__index=_ENV}) end
    local buffer = {} local val
    ]], Grammar:match(templ), [[
        if ownedCtx then _ENV = getmetatable(_ENV).__index end 
        return buffer 
        end
    ]]}
    local code = Flatten(code)
    local fun, err = load(code, "template","t", setmetatable({}, {__index=_G}))
    if err or not fun then
        error(string.format("%s\n---------\n%s", code,err))
    end
    return fun()
end

function Table2Attr(attr)
    if not attr then return "" end
    local result = {}
    for key, value in pairs(attr) do
        result[#result+1] = key
        result[#result+1] = "="
        if type(value) == "number" then
            result[#result+1] = string.format("%q", tostring(value).."px")
        else
            result[#result+1] = string.format("%q", tostring(value))    
        end
        
    end
    return result
end
local template = BakeTemplate([[
{{
function H(slot, attr)
attr = attr or {}
local priority = tostring(attr.priority or "3") 
attr.priority = nil
return ${{<h${priority} ${Table2Attr(attr)}>${slot}</h${priority}>}}
end

ctx.counter = ctx.counter and (ctx.counter + 1) or 1

}}

${H("heya world i guess?", {width="100px"})}
<@H width={20} height={"%100"} >if it works it works <@H>if this works too<@H>if this works too</@><@H>if this works too</@><@H>if this works too</@><@H>if this works too</@><@H>if this works too</@><@H>if this works too</@></@></@>

its our ${ctx.counter}th time so lets say kekkou ii desu for ${ctx.counter} times
{{
for i=1,ctx.counter do
{{Kekkou ii desu
}}
end
}}

{{
local date = os.date("*t")
if date.hour > 12 then
{{Suprisingly today clock shows ${os.date("%H:%M")} even if were not ready}}
end
}}
its in text mode

and this is our slot 
<@slot/>
and my content ends
    ]])
print(Flatten(
    template(template,{})
))