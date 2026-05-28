-- Copyright Core DF — Apache License 2.0
local function script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1, 1) == "@" then src = src:sub(2) end
  return src:match("(.-)[^/]+$") or "./"
end
local root = script_dir()
package.path = package.path
  .. ";" .. root .. "../../cawbs/Lua/?.lua"
  .. ";" .. root .. "../../transform/Lua/?.lua"
  .. ";" .. root .. "../../files/Lua/?.lua"

local cawbs = require("cawbs")
local transform = require("transformclient")

assert(cawbs.Init().status_code == 200)
local event = cawbs.GetEventPayload()
assert(event.status_code == 200)

local order_id = "unknown"
if type(event.payload) == "table" then
  order_id = event.payload.orderId or event.payload.id or order_id
end

local ack_dir = os.getenv("EXAMPLE_ACK_DIR") or "/tmp/coreauto-example"
local ack_path = ack_dir .. "/" .. order_id .. ".json"
local order = { orderId = order_id, details = event.payload }
local text = transform.JsonStringify(order)
assert(text.status_code == 200)

local files = require("fileclient")
assert(files.LocalWrite(ack_path, text.text).status_code == 200)

local out = { orderId = order_id, ackPath = ack_path }
assert(cawbs.PutStepPayload(out).status_code == 200)

local json = require("json")
print(json.encode({ status_code = 200, result = out }))
