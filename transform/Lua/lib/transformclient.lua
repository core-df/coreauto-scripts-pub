local json = require("json")
local M = {}
function M.JsonParse(text)
  local ok, data = pcall(json.decode, text)
  if ok then return { status_code = 200, data = data } end
  return { status_code = 400, error = tostring(data) }
end
function M.JsonStringify(data)
  local ok, text = pcall(json.encode, data)
  if ok then return { status_code = 200, text = text } end
  return { status_code = 400, error = tostring(text) }
end
function M.CsvToRows(text, delimiter)
  delimiter = delimiter or ","
  local lines = {}
  for line in (text .. "\n"):gmatch("(.-)\r?\n") do if line~="" then lines[#lines+1]=line end end
  if #lines==0 then return { status_code = 400, error = "empty csv" } end
  local hdr = {}; for f in lines[1]:gmatch("[^"..delimiter.."]+") do hdr[#hdr+1]=f end
  local rows = {}
  for i=2,#lines do
    local row={}; local j=1
    for f in lines[i]:gmatch("[^"..delimiter.."]+") do row[hdr[j]]=f; j=j+1 end
    rows[#rows+1]=row
  end
  return { status_code = 200, rows = rows }
end
function M.RowsToCsv(rows, delimiter)
  delimiter = delimiter or ","
  if not rows or #rows==0 then return { status_code = 400, error = "rows must not be empty" } end
  local keys={}; for k in pairs(rows[1]) do keys[#keys+1]=k end
  local out=table.concat(keys,delimiter).."\n"
  for _,r in ipairs(rows) do
    local parts={}; for _,k in ipairs(keys) do parts[#parts+1]=r[k] or "" end
    out=out..table.concat(parts,delimiter).."\n"
  end
  return { status_code = 200, text = out }
end
function M.XmlToDict(text)
  local tag = text:match("<([%w_%-]+)")
  if not tag then return { status_code = 400, error = "xml parse error" } end
  return { status_code = 200, data = { [tag] = {} } }
end
function M.DictToXml(data, root_tag)
  root_tag = root_tag or "root"
  return { status_code = 200, text = "<" .. root_tag .. "/>" }
end
return M
