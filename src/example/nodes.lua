--- Some XBTs that are useful for testing.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.
-- @module example.nodes

local util = require("xbt.util")
local xbt = require("xbt")
local graph = require("xbt.graph")

local nodes = {}

local fail_walk_avg_tries = 3

local function fail_walk (node, path, state)
  print("fw:\t", node.id, "path = ", tostring(path), "state =", state)
  local prev_result = xbt.result(node, path, state)
  local prev_reward = (xbt.is_running(prev_result) and prev_result.reward) or 0
  if (util.random(fail_walk_avg_tries) == 1) then
    local reward = prev_reward + util.random()
    print("\tfw: failed with reward    " .. reward)
    return xbt.failed(reward, "Fell off a cliff.")
  else
    local reward = prev_reward + util.random()
    print("\tfw: running with reward   " .. reward)
    return xbt.running(reward)
  end
end

nodes.fail_walk = xbt.fun(fail_walk)

local random_walk_avg_tries = 5

local function random_walk (node, path, state)
  print("rw:\t", node.id, "path = ", tostring(path), "state =", state)
  local prev_result = xbt.result(node, path, state)
  local prev_reward = (xbt.is_running(prev_result) and prev_result.reward) or 0
  if (util.random(random_walk_avg_tries) == 1) then
    if (util.random(2) == 1) then
      local reward, value = prev_reward + util.random(), util.random()
      print("\trw: succeeded with reward " .. reward .. ", value " .. value)
      return xbt.succeeded(reward, value)
    else
      local reward = prev_reward + util.random()
      print("\trw: failed with reward    " .. reward)
      return xbt.failed(reward, "Fell off a cliff.")
    end
  else
    local reward = prev_reward + util.random()
    print("\trw: running with reward   " .. reward)
    return xbt.running(reward)
  end
end

nodes.random_walk = xbt.fun(random_walk)

local search_pattern_success = 5

local function search_pattern (node, path, state)
  print("sp:\t", node.id, "path = ", tostring(path), "state =", state)
  local prev_result = xbt.result(node, path, state)
  local prev_reward = (xbt.is_running(prev_result) and prev_result.reward) or 0
  local current_try = xbt.local_data(node, path, state, 1)
  xbt.set_local_data(node, path, state, current_try + 1)
  if (current_try % search_pattern_success == 0) then
    local reward, value = prev_reward + util.random(), util.random()
    print("\tsp: succeeded with reward " .. reward .. ", value " .. value)
    return xbt.succeeded(reward, value)
  elseif (util.random(2*search_pattern_success) == 1) then
    local reward = prev_reward + util.random()
    print("\tsp: failed with reward    " .. reward)
    return xbt.failed(reward, "Fell off a cliff.")
  else
    local reward = prev_reward + util.random()
    print("\tsp: running with reward   " .. reward)
    return xbt.running(reward)
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
  {
    update_fun = function ()
      print("XChoice: collecting result.")
    end
  }
)

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