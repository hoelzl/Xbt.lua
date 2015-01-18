--- Some XBTs that are useful for testing.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.

local util = require("util")
local xbt = require("xbt")

local nodes = {}

local random_walk_avg_tries = 5

local function random_walk (node, path, state)
  print("rw:\t", node.id, "path = ", tostring(path), "state =", state)
  if (math.random(random_walk_avg_tries) == 1) then
    local cost, value = math.random(), math.random()
    print("\trw: succeeded with cost " .. cost .. " and value " .. value)
    return xbt.succeeded(cost, value)
  elseif (math.random(3) == 1) then
    local cost = math.random()
    print("\trw: failed with cost " .. cost)
    return xbt.failed(cost, "Fell off a cliff.")
  else
    local cost = math.random()
    print("\trw: running with cost " .. cost)
    return xbt.running(cost)
  end
end

nodes.random_walk = xbt.fun(random_walk)

local search_pattern_success = 5

local function search_pattern (node, path, state)
  print("sp:\t", node.id, "path = ", tostring(path), "state =", state)
  local current_try = state[node] or 1
  state[node] = current_try + 1
  if (current_try % search_pattern_success == 0) then
    local cost, value = math.random(), math.random()
    print("\tsp: succeeded with cost " .. cost .. " and value " .. value)
    return xbt.succeeded(cost, value)
  else
    local cost = math.random()
    print("\tsp: running with cost " .. cost)
    return xbt.running(cost)
  end
end

nodes.search_pattern = xbt.fun(search_pattern)

nodes.searcher = xbt.choice({
  nodes.random_walk, nodes.search_pattern
})

nodes.dual_searcher_1 = xbt.seq({
  nodes.random_walk, nodes.search_pattern
})

nodes.dual_searcher_2 = xbt.seq({
  nodes.search_pattern, nodes.random_walk
})

return nodes