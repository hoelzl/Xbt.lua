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

local function print_yes_or_no (res)
  print("  " .. (res and "Yes!" or "No!"))
end

local function is_carrying_victim (node, path, state)
  print("Am I carrying a victim?")
  local res = state.carrying
  print_yes_or_no(res)
  return res
end
xbt.define_function_name("is_carrying_victim", is_carrying_victim)

local function is_at_home_node (node, path, state)
  print("Am I at a home node?")
  local cni = state.current_node_id
  if not cni then
    print("  I am nowhere")
    return false
  end
  local node = state.graph.nodes[cni]
  assert(node, "Could not find node " .. cni)
  local res = node.type == "home"
  print_yes_or_no(res)
  return res
end
xbt.define_function_name("is_at_home_node", is_at_home_node)

local function drop_off_victim (node, path, state)
  print("Dropping off victim!")
  local carrying = state.carrying
  state.carrying = false
  return carrying
end

local function has_located_victim (node, path, state)
  print("Have I located a victim?")
  local cni = state.current_node_id
  if not cni then
    print("  I am nowhere!")
    return false
  end
  local node = state.graph.nodes[cni]
  assert(node, "Could not find node " .. cni)
  local res = node.type == "victim"
  print_yes_or_no(res)
  return res
end
xbt.define_function_name("has_located_victim", has_located_victim)

local function can_pick_up_victim (node, path, state)
  print("Can I pick up the victim?")
  local res = not state.carrying
  print_yes_or_no(res)
  return res
end
xbt.define_function_name("can_pick_up_victim", can_pick_up_victim)

local function pick_up_victim (node, path, state)
  print("Picking up the victim!")
  state.carrying = true
  return true
end
xbt.define_function_name("pick_up_victim", pick_up_victim)

local function pick_home_location (node, path, state)
  print("New home location!", 1)
  state.target_node_id = 1
end
xbt.define_function_name("pick_home_location", pick_home_location)

local function pick_victim_location (node, path, state)
  local vls = state.victim_locations
  local loc = vls[math.random(#vls)]
  print("New target location!", loc)
  state.target_node_id = loc
end
xbt.define_function_name("pick_victim_location", pick_victim_location)

local function drop_off_victim (node, path, state)
  print("Dropping off the victim!")
  state.carrying = false
  state.target_node_id = nil
  return true
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
      -- Move the best action to the front of the list of
      -- actions.
      print("Best action: move to " .. tni .. ", target is " .. next_node_id)
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
    xbt.when("is_carrying_victim", xbt.bool("drop_off_victim"))),
  xbt.when("has_located_victim",
    xbt.when("can_pick_up_victim", xbt.bool("pick_up_victim"))),
  xbt.when("is_carrying_victim",
    xbt.seq({xbt.action("pick_home_location"),
             move_towards_chosen_location})),
  xbt.seq({xbt.action("pick_victim_location"),
           move_towards_chosen_location})
})

local function graph_search ()
  print("Searching in graph...")
  local state = xbt.make_state()
  local path = util.path.new()
  local g = graph.generate_graph(30, 100, graph.make_short_edge_generator(1.5))
  print("Navigation graph has " .. #g.nodes .. " nodes and " .. #g.edges .. " edges.")
  state.graph = g
  g.nodes[1].type = "home"
  g.nodes[2].type = "victim"
  g.nodes[3].type = "victim"
  g.nodes[4].type = "victim"
  state.current_node_id = 1
  state.victim_locations = {2, 3} -- location 4 missing deliberately
  local actions,to_nodes = graph.make_graph_action_tables(g)
  state.actions = actions
  state.to_nodes = to_nodes
  state.movement_costs, state.best_moves = graph.floyd(g)
  for i = 1,20 do
    xbt.tick(robot_xbt, path, state)
    xbt.reset_node(robot_xbt, path, state)
  end
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
