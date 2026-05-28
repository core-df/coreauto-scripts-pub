-- minimal JSON (from cawbs Lua pattern)
local json = {}
function json.encode(val)
  local t = type(val)
  if t == "nil" then return "null"
  elseif t == "boolean" then return val and "true" or "false"
  elseif t == "number" then return tostring(val)
  elseif t == "string" then return '"' .. val:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\n","\\n") .. '"'
  elseif t == "table" then
    if #val > 0 then
      local p = {}; for i=1,#val do p[#p+1]=json.encode(val[i]) end
      return "[" .. table.concat(p,",") .. "]"
    end
    local p = {}; for k,v in pairs(val) do p[#p+1]=json.encode(tostring(k))..":"..json.encode(v) end
    return "{" .. table.concat(p,",") .. "}"
  end
  return "null"
end
function json.decode(str)
  local pos=1
  local function skip() while str:sub(pos,pos):match("%s") do pos=pos+1 end end
  local parse_value, parse_string
  function parse_string()
    pos=pos+1; local start=pos; local out={}
    while pos<=#str do
      local c=str:sub(pos,pos)
      if c=='"' then table.insert(out,str:sub(start,pos-1)); pos=pos+1; return table.concat(out) end
      pos=pos+1
    end
    error("bad string")
  end
  function parse_value()
    skip(); local c=str:sub(pos,pos)
    if c=='"' then return parse_string()
    elseif c=='{' then pos=pos+1; local o={}; skip()
      if str:sub(pos,pos)=='}' then pos=pos+1 return o end
      while true do skip(); local k=parse_string(); skip(); pos=pos+1; o[k]=parse_value(); skip()
        if str:sub(pos,pos)=='}' then pos=pos+1 return o end pos=pos+1 end
    elseif c=='[' then pos=pos+1; local a={}; local i=1; skip()
      if str:sub(pos,pos)==']' then pos=pos+1 return a end
      while true do a[i]=parse_value(); i=i+1; skip()
        if str:sub(pos,pos)==']' then pos=pos+1 return a end pos=pos+1 end
    else local start=pos; while str:sub(pos,pos):match("[%d%.%-eE]") do pos=pos+1 end
      local n=str:sub(start,pos-1); if n=="true" then return true elseif n=="false" then return false elseif n=="null" then return nil end
      return tonumber(n) end
  end
  return parse_value()
end
return json
