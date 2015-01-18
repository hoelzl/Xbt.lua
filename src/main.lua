--- Main file for the XBT module.
-- Currently this file is mostly useful for interactive
-- debugging in LDT.
-- @copyright © 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.

local util = require("util")
local xbt = require("xbt")
local nodes = require("example.nodes")

print("util:  ", util)
print("xbt:   ", xbt)
print("nodes: ", nodes)

--- Show off some XBT functionality.
local function main()
  print("XBTs are ready to go.")
  math.randomseed(os.time())
  local searcher = nodes.dual_searcher_2
  local path = util.path.new()
  local state = xbt.make_state()
  local res = xbt.tick(searcher, path, state)
  print("result:\t", res.status, res.value, res.cost)
  for i = 1,10 do
    local res = xbt.tick(searcher, path, state)
    print("result:\t", res.status, res.value, res.cost)
  end
  print("Done!")
end

main()
