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

local function is_at_home_node (node, path, state)
  local cni = state.current_node -- This is an index, not a node
  if not cn then return false end
  local node = state.graph.nodes[cn]
  assert(node, "Could not find node " .. cn)
  return node.type == "home"
end

local function has_located_victim (node, path, state)
  local cni = state.current_node -- This is an index, not a node
  if not cn then return false end
  local node = state.graph.nodes[cn]
  assert(node, "Could not find node " .. cn)
  return node.type == "victim"
end

local function pick_victim_location (node, path, state)
  local vls = state.victim_locations
  state.target_location = vls[math.random(#vls)]
end

local function pick_home_location (node, path, state)
  state.target_location = 1
end

local robot_xbt = xbt.seq()

local function graph_search ()
  print("Searching in graph...")
  local state = xbt.make_state()
  local g = graph.generate_graph(20, 100, graph.make_short_edge_generator(1.5))
  state.graph = g
  g.nodes[1].type = "home"
  g.nodes[2].type = "victim"
  g.nodes[3].type = "victim"
  state.victim_locations = {2, 3}
  local actions,to_nodes = graph.make_graph_action_tables(g)
  state.action = actions
  state.to_nodes = to_nodes
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
  graph_search()
  print("Done!")
end

main()
