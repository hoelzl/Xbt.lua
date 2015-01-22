--- Main file for the XBT module.
-- Currently this file is mostly useful for interactive
-- debugging in LDT.
-- @copyright © 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.

local util = require("util")
local xbt = require("xbt")
local nodes = require("example.nodes")
local graph = require("example.graph")

local function navigate_graph ()
  print("Navigating graph...")
  local g = graph.generate_graph(100, 500, graph.make_short_edge_generator(1.2))
  print("Diameter:        ", graph.diameter(g.nodes))
  local d,n = graph.maxmin_distance(g.nodes)
  print("Maxmin distance: ", d, "for node", n)
  print("Nodes:           ", #g.nodes, "Edges:", #g.edges)
  for i=1,5 do
    for j = i,5 do
      print(i, "->", j, graph.pathstring(g, i, j))
    end
  end
  local a,t = graph.make_graph_action_tables(g)
  print("Action table sizes: ", #a, #t)
end

local function search ()
  print("Searching...")  
  local searcher = nodes.searcher
  local path = util.path.new()
  local state = xbt.make_state()
  local res = xbt.tick(searcher, path, state)
  print("result:\t", res.status .. "   ", res.cost .. "  ", res.value)
  while not xbt.is_done(res) do
    res = xbt.tick(searcher, path, state)
    print("result:\t", res.status .. "   ", res.cost .. "  ", res.value)
  end
  -- Show that finished results stay constant
  for _=1,2 do
    res = xbt.tick(searcher, path, state)
    print("result:\t", res.status .. "   ", res.cost .. "  ", res.value)
  end
end

local function tick_suppress_failure ()
  print("Ticking suppressing failures...")
  local node = xbt.suppress_failure(nodes.searcher)
  local path = util.path.new()
  local state = xbt.make_state()
  local res = xbt.tick(node, path, state)
  print("result:\t", res.status .. "   ", res.cost .. "  ", res.value)
  while not xbt.is_done(res) do
    res = xbt.tick(node, path, state)
    print("result:\t", res.status .. "   ", res.cost .. "  ", res.value)
  end
end

local function tick_negate ()
  print("Ticking negated node...")
  local node = xbt.negate(nodes.searcher)
  local path = util.path.new()
  local state = xbt.make_state()
  local res = xbt.tick(node, path, state)
  print("result:\t", res.status .. "   ", res.cost .. "  ", res.value)
  while not xbt.is_done(res) do
    res = xbt.tick(node, path, state)
    print("result:\t", res.status .. "   ", res.cost .. "  ", res.value)
  end
end

----------------------------------------------------------------------
-- Graph navigation using XBTs
-- 

local print_trace_info = false

local function print_trace (...)
  if print_trace_info then
    print(...)
  end
end

local function print_yes_or_no (prefix, res)
  print_trace(prefix .. " " .. (res and "Yes." or "No."))
end

local function is_carrying_victim (node, path, state)
  local res = state.carrying > 0
  print_yes_or_no("Am I carrying a victim?", res)
  return res
end
xbt.define_function_name("is_carrying_victim", is_carrying_victim)

local function is_at_home_node (node, path, state)
  local cni = state.current_node_id
  if not cni then
    print_trace("I am not at home, I am nowhere.")
    return false
  end
  local node = state.graph.nodes[cni]
  assert(node, "Could not find node " .. cni)
  local res = node.type == "home"
  print_yes_or_no("Am I at a home node?", res)
  return res
end
xbt.define_function_name("is_at_home_node", is_at_home_node)

local function drop_off_victim (node, path, state)
  print_trace("Dropping off victim!")
  local value = state.cargo_value
  state.carrying = 0
  state.cargo_value = 0
  return xbt.succeeded(1, value)
end

local function has_located_victim (node, path, state)
  local cni = state.current_node_id
  if not cni then
    print_trace("Cannot find a victim since I am nowhere!")
    return false
  end
  local node = state.graph.nodes[cni]
  assert(node, "Could not find node " .. cni)
  local res = node.type == "victim"
  print_yes_or_no("Have I located a victim?", res)
  return res
end
xbt.define_function_name("has_located_victim", has_located_victim)

local function can_pick_up_victim (node, path, state)
  local res = state.carrying == 0
  print_yes_or_no("Can I pick up the victim?", res)
  return res
end
xbt.define_function_name("can_pick_up_victim", can_pick_up_victim)

local function pick_up_victim (node, path, state)
  print_trace("Picking up the victim!")
  local graph_node = state.graph.nodes[state.current_node_id]
  state.carrying = state.carrying + 1
  state.cargo_value = state.cargo_value + (graph_node.value or 1000)
  return xbt.succeeded(10, 0)
end
xbt.define_function_name("pick_up_victim", pick_up_victim)

local function pick_home_location (node, path, state)
  -- TODO: This should actually check a list of home locations.
  if state.target_node_id ~= 1 then
    print_trace("New home location " .. 1 .. "!")
    state.target_node_id = 1
  else
    print_trace("Keeping home location " .. state.target_node_id .. ".")
  end
end
xbt.define_function_name("pick_home_location", pick_home_location)

local function pick_victim_location (node, path, state)
  local vls = state.victim_locations
  local tni = state.target_node_id
  -- TODO: Should check list of home locations
  local change = not tni or tni == 1 or math.random(10) == 1
  if not change then
    print_trace("Keeping taget location " .. tni .. ".")
  else
    local loc = vls[math.random(#vls)]
    print_trace("New target location " .. loc .. "!")
    state.target_node_id = loc
  end
end
xbt.define_function_name("pick_victim_location", pick_victim_location)

local function drop_off_victim (node, path, state)
  local value = state.cargo_value
  print_trace("Dropping off the victim!  Value obtained: " .. value)
  state.carrying = 0
  state.cargo_value = 0
  state.target_node_id = nil
  return xbt.succeeded(0, value)
end
xbt.define_function_name("drop_off_victim", drop_off_victim)

local function go_actions (node, path, state)
  if not state.actions or not state.current_node_id then
    return {}
  end
  -- TODO: These are unsorted, as yet.
  local cni = state.current_node_id
  local tni = state.target_node_id
  local res = state.actions[cni]
  -- We might not have a best action if we cannot reach the chosen victim
  if cni and tni then
    local next_node_id = state.best_moves[cni][tni]
    if next_node_id then
      -- Move the best action to the front of the list of actions.
      print_trace("Best action: move to " .. tni .. ", next node is " .. 
        next_node_id .. ".")
      for i = 1,#res do
        local a = res[i]
        if a.args.to == next_node_id then
          res[i] = res[1]
          res[1] = a
          break
        end
      end
      assert(res[1].args.to == next_node_id)
    end
  end
  return res
end

local move_towards_chosen_location =
  xbt.xchoice({}, xbt.epsilon_greedy_child_fun,
              {sorted_children = go_actions})

local robot_xbt = xbt.choice({
  xbt.when("is_at_home_node", 
    xbt.when("is_carrying_victim", xbt.fun("drop_off_victim"))),
  xbt.when("has_located_victim",
    xbt.when("can_pick_up_victim", xbt.fun("pick_up_victim"))),
  xbt.when("is_carrying_victim",
    xbt.seq({xbt.action("pick_home_location"),
             move_towards_chosen_location})),
  xbt.seq({xbt.action("pick_victim_location"),
           move_towards_chosen_location})
})

local function graph_search ()
  print("Robot rescue scenario...")
  local state = xbt.make_state()
  local path = util.path.new()
  local g = graph.generate_graph(25, 100, graph.make_short_edge_generator(1.5))
  print("Navigation graph has " .. #g.nodes .. " nodes and " .. #g.edges .. " edges.")
  state.graph = g
  g.nodes[1].type = "home"
  -- Assign values to victim nodes.  This might change for integration with Hades.
  g.nodes[2].type = "victim"; g.nodes[2].value = 10000
  g.nodes[3].type = "victim"; g.nodes[3].value = 5000
  g.nodes[4].type = "victim"; g.nodes[4].value = 8000
  state.current_node_id = 1
  state.victim_locations = {2, 3} -- location 4 missing deliberately
  local actions,to_nodes = graph.make_graph_action_tables(g)
  state.actions = actions
  state.to_nodes = to_nodes
  state.movement_costs, state.best_moves = graph.floyd(g)
  -- The number of victims the robot is currently carrying
  state.carrying = 0
  state.cargo_value = 0
  local total_value = 0
  local total_cost = 0
  for i = 1,50 do
    local result = xbt.tick(robot_xbt, path, state)
    total_value = total_value + result.value
    total_cost = total_cost + result.cost
    xbt.reset_node(robot_xbt, path, state)
  end
  print("Total value = " .. total_value .. 
    ", total cost = " .. total_cost)
end


--- Show off some XBT functionality.
local function main()
  print("XBTs are ready to go.")
  --[[
  math.randomseed(1)
  navigate_graph()
  math.randomseed(os.time())
  search()
  tick_suppress_failure()
  tick_negate()
  --]]--
  math.randomseed(os.time())
  graph_search()
  print("Done!")
end

main()
