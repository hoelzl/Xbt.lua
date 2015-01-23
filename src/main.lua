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
local tablex = require("pl.tablex")

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

local function graph_copy ()
  local g = graph.generate_graph(10, 10, graph.make_short_edge_generator(1.5))
  local gc = graph.copy(g)
  local gcb1 = graph.copy_badly(g, 1)
  local gcb2 = graph.copy_badly(g)
  for i=1,#g.edges do
    print("Edge " .. i .. ": \t"
      .. g.edges[i].cost .. ", \t" .. gc.edges[i].cost .. ", \t"
      .. gcb1.edges[i].cost .. ", \t" .. gcb2.edges[i].cost)
  end
end

local function graph_update_edge_cost ()
  local g = graph.generate_graph(10, 10, graph.generate_all_edges)
  local gc = graph.copy_badly(g, 50)
  local sample = {from=1, to=2, cost=g.nodes[1].edges[2].cost}
  for i=1,20 do
    print("N = " .. i .. "\t"
      .. g.edges[1].cost .. ", \t" .. gc.edges[1].cost)
    graph.update_edge_cost(gc, sample)
  end
end

local function graph_update_edge_costs ()
  local g = graph.generate_graph(10, 10, graph.generate_all_edges)
  local gc = graph.copy_badly(g, 50)
  local samples = {
    {from=1, to=2, cost=g.nodes[1].edges[2].cost},
    {from=1, to=3, cost=g.nodes[1].edges[3].cost}}
  for i=1,20 do
    print("N = " .. i .. "\t"
      .. g.nodes[1].edges[2].cost .. ", \t"
      .. gc.nodes[1].edges[2].cost .. ", \t"
      .. g.nodes[1].edges[3].cost .. ", \t"
      .. gc.nodes[1].edges[3].cost)
    graph.update_edge_costs(gc, samples)
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
  local data = xbt.local_data(node, path:object_id(), state)
  local res = data.carrying > 0
  print_yes_or_no("R" .. path[1] ..
    ": Am I carrying a victim?", res)
  return res
end
xbt.define_function_name("is_carrying_victim", is_carrying_victim)

local function is_at_home_node (node, path, state)
  local data = xbt.local_data(node, path:object_id(), state)
  local cni = data.current_node_id
  if not cni then
    print_trace("R" .. path[1] .. 
      ": I am not at home, I am nowhere.")
    return false
  end
  local node = data.graph.nodes[cni]
  assert(node, "Could not find node " .. cni)
  local res = node.type == "home"
  print_yes_or_no("R" .. path[1] ..": Am I at a home node?", res)
  return res
end
xbt.define_function_name("is_at_home_node", is_at_home_node)

local function has_located_victim (node, path, state)
  local data = xbt.local_data(node, path:object_id(), state)
  local cni = data.current_node_id
  if not cni then
    print_trace("R" .. path[1] .. 
      ": Cannot find a victim since I am nowhere!")
    return false
  end
  local node = data.graph.nodes[cni]
  assert(node, "Could not find node " .. cni)
  local res = node.type == "victim"
  print_yes_or_no("R" .. path[1] .. ": " ..
    "Have I located a victim?", res)
  return res
end
xbt.define_function_name("has_located_victim", has_located_victim)

local function can_pick_up_victim (node, path, state)
  local data = xbt.local_data(node, path:object_id(), state)
  local res = data.carrying == 0
  print_yes_or_no("R" .. path[1] ..
    ": Can I pick up the victim?", res)
  return res
end
xbt.define_function_name("can_pick_up_victim", can_pick_up_victim)

local function pick_up_victim (node, path, state)
  print_trace("R" .. path[1] .. ": Picking up the victim!")
  local data = xbt.local_data(node, path:object_id(), state)
  local graph_node = data.graph.nodes[data.current_node_id]
  data.carrying = data.carrying + 1
  data.cargo_value = data.cargo_value + (graph_node.value or 1000)
  return xbt.succeeded(10, 0)
end
xbt.define_function_name("pick_up_victim", pick_up_victim)

local function pick_home_location (node, path, state)
  -- TODO: This should actually check a list of home locations.
  local data = xbt.local_data(node, path:object_id(), state)
  if data.target_node_id ~= 1 then
    print_trace("R" .. path[1] .. 
      ": New home location " .. 1 .. "!")
    data.target_node_id = 1
  else
    print_trace("R" .. path[1] .. 
      ": Keeping home location " .. data.target_node_id .. ".")
  end
end
xbt.define_function_name("pick_home_location", pick_home_location)

local function pick_victim_location (node, path, state)
  local data = xbt.local_data(node, path:object_id(), state)
  local vls = data.victim_locations
  local tni = data.target_node_id
  -- TODO: Should check list of home locations
  local change = not tni or tni == 1 or math.random(10) == 1
  if not change then
    print_trace("R" .. path[1] .. ": Keeping taget location " .. tni .. ".")
  else
    local loc = vls[math.random(#vls)]
    print_trace("R" .. path[1] .. ": New target location " .. loc .. "!")
    data.target_node_id = loc
  end
end
xbt.define_function_name("pick_victim_location", pick_victim_location)

local function update_teacher_result (value, data)
  local results = data.teacher_results
  local current_teacher = data.current_teacher
  local teacher_result = results[current_teacher.id] or {}
  local n = teacher_result.n or 0
  local prev_value = teacher_result.value or 0
  teacher_result.value = prev_value + 1/(n+1) * (value - prev_value)
  teacher_result.n = n + 1
end

local function drop_off_victim (node, path, state)
  local data = xbt.local_data(node, path:object_id(), state)
  local value = data.cargo_value
  print_trace("R" .. path[1]
    .. ": Dropping off the victim!  Value obtained: " .. value)
  data.carrying = 0
  data.cargo_value = 0
  data.target_node_id = nil
  update_teacher_result(value, data)
  return xbt.succeeded(0, value)
end
xbt.define_function_name("drop_off_victim", drop_off_victim)

-- TODO: Implement better choice of teacher.
local function pick_teacher (node, path, state)
  return state.teachers[1]
end

local function update_robot_data (node, path, state)
  print_trace("R" .. path[1]
    .. ": Updating Robot Data!")
  local data = xbt.local_data(node, path:object_id(), state)
  local t = pick_teacher(node, path, state)
  data.graph = t.graph
  data.victim_locations = t.victim_locations
  data.movement_costs = t.movement_costs
  data.best_moves = t.best_moves
  data.actions = t.actions
  data.to_nodes = t.to_nodes
  print_trace("Adding " .. #data.samples .. " samples to teacher.")
  util.append(t.samples, data.samples)
  data.samples = {}
end
xbt.define_function_name("update_robot_data", update_robot_data)

local function go_actions (node, path, state)
  local data = xbt.local_data(node, path:object_id(), state)
  if not data.actions or not data.current_node_id then
    return {}
  end
  local cni = data.current_node_id
  local tni = data.target_node_id
  local res = tablex.deepcopy(data.actions[cni])
  -- We might not have a best action if we cannot reach the chosen victim
  if cni and tni then
    local next_node_id = data.best_moves[cni][tni]
    if next_node_id then
      -- Move the best action to the front of the list of actions.
      print_trace("R" .. path[1] .. ": Best action: move to " ..
        tni .. ", next node is " ..  next_node_id .. ".")
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
              {sorted_children = go_actions, epsilon=0.5})

local robot_xbt = xbt.choice({
  xbt.when("is_at_home_node",
    xbt.seq({
      xbt.action("update_robot_data"),
      xbt.when("is_carrying_victim", xbt.fun("drop_off_victim"))})),
  xbt.when("has_located_victim",
    xbt.when("can_pick_up_victim", xbt.fun("pick_up_victim"))),
  xbt.when("is_carrying_victim",
    xbt.seq({xbt.action("pick_home_location"),
             move_towards_chosen_location})),
  xbt.seq({xbt.action("pick_victim_location"),
           move_towards_chosen_location})
})

local function assign_node_types (g, num_home_nodes, victim_nodes)
  local home_locations, victim_locations = {}, {}
  for i = 1,num_home_nodes do
    g.nodes[i].type = "home"
    home_locations[#home_locations+1] = i
  end
  local i = num_home_nodes+1
  for _,value in ipairs(victim_nodes) do
    g.nodes[i].type = "victim"
    g.nodes[i].value = value
    victim_locations[#victim_locations+1] = i
    i = i + 1 
  end
  return home_locations, victim_locations
end

local function initialize_graph
    (state, num_nodes, num_home_nodes, victim_nodes, diameter)
  local g = graph.generate_graph(num_nodes, diameter, graph.make_short_edge_generator(1.5))
  print("Navigation graph has " .. #g.nodes .. " nodes and " .. #g.edges .. " edges.")
  state.graph = g
  if type(victim_nodes) == "number" then
    local nv = victim_nodes
    victim_nodes = {}
    for i=1,nv do
      victim_nodes[i] = 10000
    end
  end
  local hls, vls = assign_node_types(g, num_home_nodes, victim_nodes)
  state.home_locations = hls
  state.victim_locations = vls
  local actions,to_nodes = graph.make_graph_action_tables(g)
  state.actions = actions
  state.to_nodes = to_nodes
  state.movement_costs, state.best_moves = graph.floyd(g)
end  

local function initialize_teachers (state, error_funs)
  local teachers = {}
  for i,error_fun in ipairs(error_funs) do
    local g = graph.copy_badly(state.graph, error_fun)
    local movement_costs, best_moves = graph.floyd(g)
    local vls = {}
    for _,vl in ipairs(state.victim_locations) do
      if util.rng:sample() > 0.3 then
        vls[#vls+1] = vl
      end
    end
    local actions,to_nodes = graph.make_graph_action_tables(g)
    teachers[i] = {
      id=i,
      graph=g, samples={},
      home_locations=state.home_locations, victim_locations=vls,
      movement_costs=movement_costs, best_moves=best_moves,
      actions=actions, to_nodes=to_nodes}
  end
  state.teachers = teachers
end

-- This requires the teachers to be already initialized!
local function initialize_robots (state, num_robots)
  -- We use a forest of paths to identify robots; all paths of robot i start
  -- at node [i]
  local paths = {}
  state.paths = paths
  state.num_robots = num_robots
  for i = 1,num_robots do
    local path = util.path.new(i)
    paths[i] = path
    local data = {current_node_id = 1,
      carrying = 0, cargo_value = 0, 
      samples = {},
      current_teacher = state.teachers[1], teacher_results = {}}
    xbt.set_local_data(nil, path, state, data)
    update_robot_data(nil, path, state)
  end
end

local function start_episode (state, delta)
  print_trace("========== Starting new episode ==========")
  local teachers = state.teachers
  for i,t in ipairs(teachers) do
    local g = t.graph
    graph.update_edge_costs(g, t.samples)
    t.movement_costs, t.best_moves = graph.floyd(g)
    print("Updated T" .. i .. " with "
      .. #t.samples .. " samples.  ("
      .. graph.absolute_difference(state.movement_costs, t.movement_costs)
      .. ", "
      .. graph.different_choices(state.best_moves, t.best_moves)
      .. ").")
    t.samples = {}
  end
  state.epsilon = state.epsilon * delta
end

local function rescue_scenario (num_robots, num_nodes, num_steps,
  num_home_nodes, victim_nodes, diameter, epsilon, delta)
  num_robots = num_robots or 25
  num_nodes = num_nodes or 100
  num_steps = num_steps or 2000
  num_home_nodes = num_home_nodes or 1
  victim_nodes = victim_nodes or num_nodes / 10
  diameter = diameter or 10000
  epsilon = epsilon or 0.8
  delta = delta or 0.999
  print("Robot rescue scenario (" .. num_steps .. " steps)...")
  local state = xbt.make_state({epsilon=epsilon})
  initialize_graph(state, num_nodes, num_home_nodes, victim_nodes, diameter)
  initialize_teachers(state, {1000})
  initialize_robots(state, num_robots)
  local episode_steps = num_steps / (num_steps < 1000 and 10 or 100)
  local episode
  local episodes = {}
  local total_value = 0
  local total_cost = 0
  for i = 1,num_steps do
    if i % episode_steps == 1 then
      episode = {value=0, cost=0, 
        state={movement_costs=state.movement_costs, 
               best_moves=state.best_moves,
               epsilon=state.epsilon},
        teachers={}}
      -- TODO: Fill in teacher data
      episodes[#episodes+1] = episode
      start_episode(state, delta)
      -- delta = delta * delta
    end
    for r = 1,num_robots do
      local path = state.paths[r]
      local result = xbt.tick(robot_xbt, path:copy(1), state)
      total_value = total_value + result.value
      total_cost = total_cost + result.cost
      episode.value = episode.value + result.value
      episode.cost = episode.cost + result.cost
      -- Reset the node, but don't clear its data
      xbt.reset_node(robot_xbt, path, state, false)
    end
  end
  for i,e in ipairs(episodes) do
    print("Episode value = " .. e.value .. ",\t episode cost = " .. e.cost
      .. " (" .. e.state.epsilon .. ")")
  end
  print("Total value   = " .. total_value .. ",\t total cost   = " .. total_cost)
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
  graph_copy()
  graph_update_edge_cost()
  graph_update_edge_costs()
  --]]--
  math.randomseed(os.time())
  -- rescue_scenario(10, 7500, 10)
  rescue_scenario()
  print("Done!")
end

main()
