--- Main file for the XBT module.
-- Currently this file is mostly useful for interactive
-- debugging in LDT.
-- @copyright © 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.
-- @module main

local xbt = require("xbt")
local util = require("xbt.util")
local xbt_path = require("xbt.path")
local graph = require("xbt.graph")
local nodes = require("example.nodes")
local tablex = require("pl.tablex")
local math = require("sci.math")
local prng = require("sci.prng")


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
  local data = xbt.local_data(node, path:root_path(), state)
  local res = data.carrying > 0
  print_yes_or_no("R" .. string.sub(path.id, 1, 4) ..
    ": Am I carrying a victim?", res)
  return res
end
xbt.define_function_name("is_carrying_victim", is_carrying_victim)

local function is_at_home_node (node, path, state)
  local data = xbt.local_data(node, path:root_path(), state)
  local cni = data.current_node_id
  if not cni then
    print_trace("R" .. string.sub(path.id, 1, 4) .. 
      ": I am not at home, I am nowhere.")
    return false
  end
  local node = data.graph.nodes[cni]
  assert(node, "Could not find node " .. cni)
  local res = node.type == "home"
  print_yes_or_no("R" .. string.sub(path.id, 1, 4) ..": Am I at a home node?", res)
  return res
end
xbt.define_function_name("is_at_home_node", is_at_home_node)

local function has_located_victim (node, path, state)
  local data = xbt.local_data(node, path:root_path(), state)
  local cni = data.current_node_id
  if not cni then
    print_trace("R" .. string.sub(path.id, 1, 4) .. 
      ": Cannot find a victim since I am nowhere!")
    return false
  end
  local node = data.graph.nodes[cni]
  assert(node, "Could not find node " .. cni)
  -- TODO: Remove hard-coded probability
  local victim = node.type == "victim"
  print_yes_or_no("R" .. string.sub(path.id, 1, 4) .. ": "
    .. "Am I at a victim location?", res)
  local res = victim and util.rng:sample() < 0.3
  print_yes_or_no("R" .. string.sub(path.id, 1, 4) .. ": "
    ..  "Have I located a victim?", res)
  return res
end
xbt.define_function_name("has_located_victim", has_located_victim)

local function can_pick_up_victim (node, path, state)
  local data = xbt.local_data(node, path:root_path(), state)
  local res = data.carrying == 0
  print_yes_or_no("R" .. string.sub(path.id, 1, 4) ..
    ": Can I pick up the victim?", res)
  return res
end
xbt.define_function_name("can_pick_up_victim", can_pick_up_victim)

local function pick_up_victim (node, path, state)
  print_trace("R" .. string.sub(path.id, 1, 4) .. ": Picking up the victim!")
  local data = xbt.local_data(node, path:root_path(), state)
  local graph_node = data.graph.nodes[data.current_node_id]
  data.carrying = data.carrying + 1
  data.cargo_value = data.cargo_value + (graph_node.value or 1000)
  return xbt.succeeded(10)
end
xbt.define_function_name("pick_up_victim", pick_up_victim)

local function pick_home_location (node, path, state)
  -- TODO: This should actually check a list of home locations.
  local data = xbt.local_data(node, path:root_path(), state)
  if data.target_node_id ~= 1 then
    print_trace("R" .. string.sub(path.id, 1, 4) .. 
      ": New home location " .. 1 .. "!")
    data.target_node_id = 1
  else
    print_trace("R" .. string.sub(path.id, 1, 4) .. 
      ": Keeping home location " .. data.target_node_id .. ".")
  end
end
xbt.define_function_name("pick_home_location", pick_home_location)

local function pick_victim_location (node, path, state)
  local data = xbt.local_data(node, path:root_path(), state)
  local vls = data.victim_locations
  local tni = data.target_node_id
  -- TODO: Should check list of home locations
  local change = not tni or tni == 1 or util.rng:sample() < 0.1
  if not change then
    print_trace("R" .. string.sub(path.id, 1, 4) .. ": Keeping taget location " .. tni .. ".")
  else
    local r = util.random(#vls)
    local loc = vls[r]
    print_trace("R" .. string.sub(path.id, 1, 4) .. ": New target location " .. loc .. "!")
    data.target_node_id = loc
  end
end
xbt.define_function_name("pick_victim_location", pick_victim_location)

local function update_teacher_result (reward, data)
  local results = data.teacher_results
  local current_teacher = data.current_teacher
  local teacher_result = results[current_teacher.id] or {}
  local n = teacher_result.n or 0
  local prev_reward = teacher_result.reward or 0
  teacher_result.reward = prev_reward + 1/(n+1) * (reward - prev_reward)
  teacher_result.n = n + 1
end

local function drop_off_victim (node, path, state)
  local data = xbt.local_data(node, path:root_path(), state)
  local value = data.cargo_value
  print_trace("R" .. string.sub(path.id, 1, 4)
    .. ": Dropping off the victim!  Value obtained: " .. value)
  data.carrying = 0
  data.cargo_value = 0
  data.target_node_id = nil
  update_teacher_result(value, data)
  return xbt.succeeded(value)
end
xbt.define_function_name("drop_off_victim", drop_off_victim)

-- TODO: Implement better choice of teacher.
local function pick_teacher (node, path, state)
  return state.teachers[1]
end

local function update_robot_data (node, path, state)
  print_trace("R" .. string.sub(path.id, 1, 4)
    .. ": Updating Robot Data!")
  local data = xbt.local_data(node, path:root_path(), state)
  local t = pick_teacher(node, path, state)
  data.graph = t.graph
  data.victim_locations = t.victim_locations
  data.movement_rewards = t.movement_rewards
  data.best_moves = t.best_moves
  data.actions = t.actions
  data.to_nodes = t.to_nodes
  print_trace("Adding " .. #data.samples .. " samples to teacher.")
  util.append(t.samples, data.samples)
  data.samples = {}
end
xbt.define_function_name("update_robot_data", update_robot_data)

local function go_actions (node, path, state)
  local data = xbt.local_data(node, path:root_path(), state)
  if not state.actions or not data.current_node_id then
    return {}
  end
  local cni = data.current_node_id
  local tni = data.target_node_id
  local res = tablex.deepcopy(state.actions[cni])
  -- We might not have a best action if we cannot reach the chosen victim
  if cni and tni then
    local next_node_id = data.best_moves[cni][tni]
    if next_node_id then
      -- Move the best action to the front of the list of actions.
      print_trace("R" .. string.sub(path.id, 1, 4) 
        .. ": Best action: move from state " .. cni .. " to " 
        .. tni .. ", next node is " ..  next_node_id .. ".")
      for i = 1,#res do
        local a = res[i]
        if a.args.to_id == next_node_id then
          res[i] = res[1]
          res[1] = a
          break
        end
      end
      -- assert(res[1].args.to_id == next_node_id)
    end
  end
  return res
end

local move_towards_chosen_location =
  xbt.xchoice({}, xbt.epsilon_greedy_child_fun,
              {sorted_children = go_actions})

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

local function initialize_graph (state, scenario)
  local g = graph.generate_graph(scenario.num_nodes, 
    scenario.diameter, graph.make_short_edge_generator(1))
  g = graph.copy_badly(g, 0.9, 0.1, 0, true)
  print("Navigation graph has " .. #g.nodes .. " nodes and " .. #g.edges .. " edges.")
  state.graph = g
  local hls, vls = assign_node_types(g, scenario.num_home_nodes, scenario.victim_nodes)
  state.home_locations = hls
  state.victim_locations = vls
  local actions,to_nodes = graph.make_graph_action_tables(g)
  state.actions = actions
  state.to_nodes = to_nodes
  state.movement_rewards, state.best_moves = graph.floyd(g)
end  

local function initialize_teachers (state, scenario)
  local teachers = {}
  for i,t in ipairs(scenario.teachers) do
    -- TODO: Fix teacher representation
    local g = graph.copy_badly(state.graph, t.p_del, t.p_gen, t.err)
    local movement_rewards, best_moves = graph.floyd(g)
    local vls = {}
    for i,vl in ipairs(state.victim_locations) do
      -- Ensure that we have at least one victim location.
      if i == 1 or util.rng:sample() > 0 --[[was: 0.3 ]]-- 
      then
        vls[#vls+1] = vl
      end
    end
    local actions,to_nodes = graph.make_graph_action_tables(g)
    teachers[i] = {
      id=i,
      graph=g, samples={},
      home_locations=state.home_locations, victim_locations=vls,
      movement_rewards=movement_rewards, best_moves=best_moves,
      actions=actions, to_nodes=to_nodes}
  end
  state.teachers = teachers
end

-- This requires the teachers to be already initialized!
local function initialize_robots (state, scenario)
  -- We use a forest of paths to identify robots; all paths of robot i start
  -- at node [i]
  local paths = {}
  state.paths = paths
  state.num_robots = scenario.num_robots
  state.robots = {}
  for i = 1,state.num_robots do
    local uuid = util.uuid()
    local path = xbt_path.new(uuid)
    if not path == path:root_path() then
      print("Path not equal to root path.")
    end
    state.robots[i] = {id=uuid, path=path}
    paths[i] = path
    local data = {current_node_id = 1,
      carrying = 0, cargo_value = 0, 
      samples = {},
      current_teacher = state.teachers[1], teacher_results = {}}
    xbt.set_local_data(nil, path, state, data)
    update_robot_data(nil, path, state)
  end
end

local function print_teacher_info (episode_teacher)
  print("    Teacher " .. episode_teacher.id
    .. " \tsamples: \t" .. episode_teacher.nsamples
    .. " \tbad choices: \t" .. episode_teacher.different_choices
    .. " \tdifference: \t" .. math.round(episode_teacher.absolute_difference))
end

local print_reward_only = false

local function print_episode (episode)
  if print_reward_only then
    print(episode.reward)
  else
    print("------------------------------------------------------------------------------------")
    print("Episode " .. episode.id
      .. " \treward:  \t" .. math.round(episode.reward)
      .. " \tepsilon: \t" .. (math.round(episode.state.epsilon * 100)) / 100)
    for _,et in ipairs(episode.teachers) do
      print_teacher_info(et)
    end
  end
end

local function print_episodes (episodes)
  for i,e in ipairs(episodes) do
    print_episode(e)
  end
  if not print_reward_only then
    print("-------------------------------------------------------------------------------------")
  end
end

local function start_episode (state, scenario, episode)
  print_trace("========== Starting new episode ==========")
  local teachers = state.teachers
  episode.teachers = {}
  local update_ratio
  for i,t in ipairs(teachers) do
    local g = t.graph
    if scenario.teachers_learn then
      update_ratio = graph.update_edge_rewards(g, t.samples)
      print_trace("Update ratio: ", update_ratio)
      t.movement_rewards, t.best_moves = graph.floyd(g)
    end
    local et = {id=t.id}
    et.absolute_difference = 
      graph.absolute_difference(state.movement_rewards, t.movement_rewards)
    et.different_choices =
      graph.different_choices(state.best_moves, t.best_moves)
    et.nsamples = #t.samples 
    t.samples = {}
    episode.teachers[i] = et
  end
  local eps = state.epsilon
  if eps > state.epsilon_min then
    if update_ratio then
      state.epsilon = math.min(1.0, 10*math.pow(update_ratio, 0.5))
    else 
      state.epsilon = eps * eps -- * eps
    end
  else
    state.epsilon = state.epsilon_min
  end
end

local function make_scenario (
    num_robots, num_nodes, num_steps, num_home_nodes,
    victim_nodes, diameter, teachers, epsilon, epsilon_min,
    damage, teachers_learn)
  num_robots = num_robots or 25 -- 25
  num_nodes = num_nodes or 100 -- 100
  num_steps = num_steps or 5000 -- 15000
  num_home_nodes = num_home_nodes or 1
  victim_nodes = math.max(2, victim_nodes or num_nodes / 20)
  if type(victim_nodes) == "number" then
    local nv = victim_nodes
    victim_nodes = {}
    for i=1,nv do
      victim_nodes[i] = 10000
    end
  end
  diameter = diameter or 500
  teachers = teachers or {{}}
  epsilon = epsilon or 0.999999999
  epsilon_min = epsilon_min or 0.01
  damage = damage or false
  if teachers_learn == nil then
    teachers_learn = true
  else
    teachers_learn = teachers_learn
  end
  
  return {
    num_robots=num_robots, num_nodes=num_nodes,
    num_steps=num_steps, num_home_nodes=num_home_nodes,
    victim_nodes=victim_nodes,
    diameter=diameter,
    teachers = teachers, 
    epsilon=epsilon, epsilon_min=epsilon_min,
    damage=damage,
    teachers_learn=teachers_learn,
    random_seed=tostring(util.rng)
  }  
end

local default_scenario
  = make_scenario()
local perfect_info_scenario
  = make_scenario(nil, nil, nil, nil, nil, nil, {{p_gen=0, p_del=0, err=0}}, 0, 0, false, false)
local damage_scenario
  = make_scenario(nil, nil, nil, nil, nil, nil, nil, nil, nil, "once")
local perfect_info_damage_scenario
  = make_scenario(nil, nil, nil, nil, nil, nil, {{p_gen=0, p_del=0, err=0}}, 0, 0, "once", false)
local multi_damage_scenario
  = make_scenario(nil, nil, nil, nil, nil, nil, nil, nil, nil, "multi")
local perfect_info_multi_damage_scenario
  = make_scenario(nil, nil, nil, nil, nil, nil, {{p_gen=0, p_del=0, err=0}}, 0, 0, "multi", false)

local current_random_seed = tostring(util.rng)
default_scenario.random_seed = current_random_seed
perfect_info_scenario.random_seed = current_random_seed
damage_scenario.random_seed = current_random_seed
perfect_info_damage_scenario.random_seed = current_random_seed

local function run_simulation (state, scenario, episodes)
  local num_steps = scenario.num_steps
  local episode_steps = num_steps / (num_steps < 1000 and 10 or 100)
  local episode
  local total_reward = 0
  for i = 1,num_steps do
    if i % 50 == 0 then io.write(".") end
    if i % (50*72) == 0 then print() end
    if i % episode_steps == 1 then
      episode = {id=i, reward=0, 
        state={movement_rewards=state.movement_rewards, 
               best_moves=state.best_moves,
               epsilon=state.epsilon},
        teachers={}}
      -- TODO: Fill in teacher data
      episodes[#episodes+1] = episode
      start_episode(state, scenario, episode)
    end
    -- TODO: Clean up the damaging
    if scenario.damage == "once" and i == math.floor(num_steps / 4) then
      print("Damaging graph (once)!")
      local g = graph.copy_badly(state.graph, 0.5, 0.1, 0.5, true)
      state.graph = g
      state.movement_rewards, state.best_moves = graph.floyd(g)
      state.actions,state.to_nodes = graph.make_graph_action_tables(g)
      print("Navigation graph has " .. #g.nodes .. " nodes and " .. #g.edges .. " edges.")
    end
    if scenario.damage == "multi" and i%math.floor(num_steps/10) == 0 then
      print("Damaging graph (multi)!")
      local g = graph.copy_badly(state.graph, 0.15, 0.025, 0.25, true)
      state.graph = g
      state.movement_rewards, state.best_moves = graph.floyd(g)
      state.actions,state.to_nodes = graph.make_graph_action_tables(g)
      print("Navigation graph has " .. #g.nodes .. " nodes and " .. #g.edges .. " edges.")
    end
    for r = 1,scenario.num_robots do
      local path = state.paths[r]
      local result = xbt.tick(robot_xbt, path:copy(1), state)
      total_reward = total_reward + result.reward
      episode.reward = episode.reward + result.reward
      -- Reset the node, but don't clear its data
      xbt.reset_node(robot_xbt, path, state, false)
    end
  end
  print()
  return total_reward
end

local function rescue_scenario (scenario)
  scenario = scenario or make_scenario()
  print("Robot rescue scenario (" .. scenario.num_steps .. " steps)...")
  if (scenario.random_seed) then
    util.rng = prng.restore(scenario.random_seed)
  else
    scenario.random_seed = tostring(util.rng)
  end
  print("Random seed: ", tostring(util.rng))
  local state = xbt.make_state({epsilon=scenario.epsilon, epsilon_min=scenario.epsilon_min})
  initialize_graph(state, scenario)
  initialize_teachers(state, scenario)
  initialize_robots(state, scenario)
  local episodes = {}
  local total_reward = run_simulation(state, scenario, episodes)
  print_episodes(episodes)
  print("Total reward = " .. math.round(total_reward))
  return episodes, scenario
end


--- Run the rescue scenario.
local function main()
  print("XBTs are ready to go.")
  print("Perfect info:")
  rescue_scenario(perfect_info_scenario)
  print("Default:")
  rescue_scenario(default_scenario)
  print("Perfect info with damage:")
  rescue_scenario(perfect_info_damage_scenario)
  print("Default with damage:")
  rescue_scenario(damage_scenario)
  print("Perfect info with multiple damage:")
  rescue_scenario(perfect_info_multi_damage_scenario)
  print("Default with multiple damage:")
  rescue_scenario(multi_damage_scenario)
  print("Done!")
end

main()
