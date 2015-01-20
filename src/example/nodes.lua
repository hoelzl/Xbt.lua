--- Some XBTs that are useful for testing.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.

local util = require("util")
local xbt = require("xbt")
local graph = require("example.graph")

local nodes = {}

local fail_walk_avg_tries = 3

local function fail_walk (node, path, state)
  print("fw:\t", node.id, "path = ", tostring(path), "state =", state)
  local prev_result = xbt.result(node, path, state)
  local prev_cost = (xbt.is_running(prev_result) and prev_result.cost) or 0
  if (math.random(fail_walk_avg_tries) == 1) then
    local cost = prev_cost + math.random()
    print("\tfw: failed with cost    " .. cost)
    return xbt.failed(cost, "Fell off a cliff.")
  else
    local cost = prev_cost + math.random()
    print("\tfw: running with cost   " .. cost)
    return xbt.running(cost)
  end
end

nodes.fail_walk = xbt.fun(fail_walk)

local random_walk_avg_tries = 5

local function random_walk (node, path, state)
  print("rw:\t", node.id, "path = ", tostring(path), "state =", state)
  local prev_result = xbt.result(node, path, state)
  local prev_cost = (xbt.is_running(prev_result) and prev_result.cost) or 0
  if (math.random(random_walk_avg_tries) == 1) then
    if (math.random(2) == 1) then
      local cost, value = prev_cost + math.random(), math.random()
      print("\trw: succeeded with cost " .. cost .. ", value " .. value)
      return xbt.succeeded(cost, value)
    else
      local cost = prev_cost + math.random()
      print("\trw: failed with cost    " .. cost)
      return xbt.failed(cost, "Fell off a cliff.")
    end
  else
    local cost = prev_cost + math.random()
    print("\trw: running with cost   " .. cost)
    return xbt.running(cost)
  end
end

nodes.random_walk = xbt.fun(random_walk)

local search_pattern_success = 5

local function search_pattern (node, path, state)
  print("sp:\t", node.id, "path = ", tostring(path), "state =", state)
  local prev_result = xbt.result(node, path, state)
  local prev_cost = (xbt.is_running(prev_result) and prev_result.cost) or 0
  local current_try = xbt.local_data(node, path, state, 1)
  xbt.set_local_data(node, path, state, current_try + 1)
  if (current_try % search_pattern_success == 0) then
    local cost, value = prev_cost + math.random(), math.random()
    print("\tsp: succeeded with cost " .. cost .. ", value " .. value)
    return xbt.succeeded(cost, value)
  elseif (math.random(2*search_pattern_success) == 1) then
    local cost = prev_cost + math.random()
    print("\tsp: failed with cost    " .. cost)
    return xbt.failed(cost, "Fell off a cliff.")
  else
    local cost = prev_cost + math.random()
    print("\tsp: running with cost   " .. cost)
    return xbt.running(cost)
  end
end

nodes.search_pattern = xbt.fun(search_pattern)

nodes.searcher = xbt.xchoice({
    nodes.random_walk, nodes.search_pattern, nodes.fail_walk, nodes.fail_walk
  },
  function (node) 
    print("XChoice: reordering children.")
    local temp = node.children[1]
    table.remove(node.children, 1)
    node.children[#node.children+1] = temp
    return node.children
  end,
  function ()
    print("XChoice: collecting result.")
  end)

nodes.dual_searcher_1 = xbt.seq({
  nodes.random_walk, nodes.search_pattern
})

nodes.dual_searcher_2 = xbt.seq({
  nodes.search_pattern, nodes.random_walk
})


----------------------------------------------------------
-- Generate actions for a graph
-- 

return nodes