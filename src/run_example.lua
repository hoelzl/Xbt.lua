--- Example file for the XBT module.
-- Currently this file is mostly useful for interactive
-- debugging in LDT.
-- @copyright © 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.
-- @module run_example
-- 
local xbt = require("xbt")
local util = require("xbt.util")
local xbt_path = require("xbt.path")
local graph = require("xbt.graph")
local nodes = require("example.nodes")
local tablex = require("pl.tablex")
local math = require("sci.math")
local prng = require("sci.prng")

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
  local path = xbt_path.new()
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
  local path = xbt_path.new()
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
  local path = xbt_path.new()
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


math.randomseed(1)
navigate_graph()

--[[--
math.randomseed(os.time())
search()
tick_suppress_failure()
tick_negate()
graph_copy()
graph_update_edge_cost()
graph_update_edge_costs()
--]]--