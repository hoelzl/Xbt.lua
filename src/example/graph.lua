--- Generating and finding paths in graphs.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.

local util = require("util")
local xbt = require("xbt")
-- local tablex = require("pl.tablex")
local dist = require("sci.dist")
local alg = require("sci.alg")
local graph = {}

graph.print_trace_info = true

local function print_trace (...)
  if graph.print_trace_info then
    print(...)
  end
end

--- Compute the distance between two nodes
-- @param n1 The first node.
-- @param n2 The second node.
-- @return The distance between `n1` and `n2`.
function graph.node_dist (n1, n2)
  local x1,y1 = n1.x, n1.y
  local x2,y2 = n2.x, n2.y
  local dx,dy = x1-x2, y1-y2
  return math.sqrt(dx*dx + dy*dy)
end

--- Compute the diameter of a graph
-- Compute the diameter of the nodes of a graph, i.e., the maximum
-- distance between any two nodes.  It is passed a set of nodes, not a
-- graph.
-- @param nodes The nodes of a graph.
-- @return The diameter of the graph.
function graph.diameter (nodes)
  local dist = 0
  for i = 1,#nodes-1 do
    for j = i,#nodes do
      local d = graph.node_dist(nodes[i],nodes[j])
      dist = math.max(dist, d)
    end
  end
  return dist  
end

--- Compute the minimum distance between a node and a set of nodes.
-- @param node A node.
-- @param nodes A set of nodes.
-- @return The minimum distance between `node` and any element of
--  `nodes`
function graph.min_node_distance (node, nodes)
  local dist = math.huge
  for _,n in ipairs(nodes) do
    local d = graph.node_dist(n, node)
    if d > 0 then
      if d < dist then
        dist = d
      end
    end
  end
  return dist
end

--- Compute the maximum of the minimal node distances.
-- Ccompute the maximum of the minimal distances between any two
-- members of a set of nodes.  Inserting all edges of length no bigger
-- than this value ensures that every node in the graph is connected
-- to at least one other node (although the graph may still consist of
-- many disconnected components).
-- @param nodes The nodes of a graph.
-- @return The maximum of the minimum of the distances between nodes.
function graph.maxmin_distance(nodes)
  local dist = 0
  local node_index = -1
  for i,n in ipairs(nodes) do
    local d = graph.min_node_distance(n, nodes)
    if d > dist then
      dist = d
      node_index = i
    end
  end
  return dist,node_index
end


--- When updating a graph we may sometimes want to bias the results
-- towards the initial value, so that the first few samples don't
-- have an undue effect on the graph if the environment is very
-- noisy.  Therefore we can adjust how often the update algorithm
-- thinks that it has already seen the initial cost of the edge before
-- the first update.
graph.initial_edge_occurrences = 1

--- Generate all possible edges between members of nodes.
-- When passed as edge generator to `generate_graph` this will build
-- the complete graph for the generated nodes.
-- @param nodes The nodes of a graph.
-- @return All possible edges for the nodes.
function graph.generate_all_edges (nodes)
  local edges = {}
  for i = 1,#nodes-1 do
    for j = i+1,#nodes do
      local n1,n2 = nodes[i], nodes[j]
      local dist = graph.node_dist(n1, n2)
      local edge1 = {from=n1, to=n2, type="edge",
        dist=dist, cost=dist,
        occurrences=graph.initial_edge_occurrences}
      edges[#edges+1] = edge1
      n1.edges[j] = edge1
      local edge2 = {from=n2, to=n1, type="edge",
        dist=dist, cost=dist,
        occurrences=graph.initial_edge_occurrences}
      edges[#edges+1] = edge2
      n2.edges[i] = edge2
    end
  end
  return edges
end

--- Build a generator that builds all short edges between nodes.
-- This function returns a function that is suitable as edge generator
-- for `generate_graph`.  This generator builds all edges that are
-- shorter than `slack` times the `maxmin_distance` between nodes.
-- Setting slack to a value below 1 will ensure that the graph
-- contains isolated nodes (and in general consists of many
-- disconnected components).
-- @param slack A factor by which the generated edges may be longer
--  than the maxmin distance.
-- @return All short edges for `nodes`.
function graph.make_short_edge_generator (slack)
  slack = slack or 1.2
  return function (nodes)
    local edges = {}
    local maxmin_dist = graph.maxmin_distance(nodes)
    for i = 1,#nodes-1 do
      for j = i+1,#nodes do
        local n1,n2 = nodes[i], nodes[j]
        local dist = graph.node_dist(n1, n2)
        if dist <= maxmin_dist * slack then
          local edge1 = {from=n1, to=n2, type="edge",
            dist=dist, cost=dist,
            occurrences=graph.initial_edge_occurrences}
          edges[#edges+1] = edge1
          n1.edges[j] = edge1
          local edge2 = {from=n2, to=n1, type="edge",
            dist=dist, cost=dist,
            occurrences=graph.initial_edge_occurrences}
          edges[#edges+1] = edge2
          n2.edges[i] = edge2
        end
      end
    end
    return edges
  end -- function
end

--- Generate a graph.
-- Generate a graph with the given number of nodes.
-- @param number_of_nodes The number of nodes in the graph.  Each node
--  has an integer attribute `id` that has to correspond to its
--  position in the array of nodes, `x` and `y` attributes that
--  describe its physical location, a `type` attribute that has the
--  value `"node"`, and an array of the same size as the nodes table
--  that contains `nil` for indices of nodes for which there is no
--  edge, and the transition for indices for which a transition
--  exists.  The entries in this array have to be filled in by the
--  `edge_generator`.
-- @param size The size of the are in which the nodes are located.
--  May either be a number, in which case both x and y dimension are
--  set to this number, or a pair `{x=x, y=y}` that specifies the
--  dimensions for x and y separately.  Defaults to 500.
-- @param edge_generator A function that generates the edges for the
--  graph given the table of nodes.  The generator has to add each
--  edge to the correct index of the `edges` array of its start node. 
function graph.generate_graph (number_of_nodes, size, edge_generator)
  edge_generator = edge_generator or graph.generate_all_edges
  if not size then size = 500 end
  if type(size) == "number" then size={x=size,y=size} end
  local nodes = {}
  for i = 1,number_of_nodes do
    local x,y = util.rng:sample() * size.x, util.rng:sample() * size.y
    nodes[#nodes+1] = {id=i, x=x, y=y, type="node", edges={}}
  end
  local edges = edge_generator(nodes)
  return {nodes=nodes, edges=edges}
end

--- Copy a graph.
-- This function copies a graph, taking care of the cycles appearing
-- in the graph structure.  It copys _only_ the default attributes
-- of a graph and ignores any attributes stored by the user.
function graph.copy (g)
  local nodes, edges = {}, {}
  for i,n in ipairs(g.nodes) do
    nodes[i] = {id=i, x=n.x, y=n.y, type=n.type, edges = {}}
  end
  for i,e in ipairs(g.edges) do
    local from_id, to_id = e.from.id, e.to.id
    local new_from, new_to = nodes[from_id], nodes[to_id]
    local new_edge = {from=new_from, to=new_to,
      type=e.type, dist=e.dist, cost=e.cost,
      occurrences=e.occurrences}
    edges[i] = new_edge
    new_from.edges[to_id] = new_edge
  end
  return {nodes=nodes, edges=edges}
end

--- Copy a graph, introducing errors in the edge costs.
-- @param g The graph to copy.
-- @param error_fun A function receiving the cost of an edge in `g` as
--  argument and returning the cost for the copy of the edge.
function graph.copy_badly (g, error_fun)
  if not error_fun then error_fun = graph.diameter(g.nodes) / 2 end
  if type(error_fun) == "number" then
    local sd = dist.normal(0, error_fun)
    error_fun = function (cost)
      return cost + sd:sample(util.rng)
    end
  end
  local res = graph.copy(g)
  for _,e in ipairs(res.edges) do
    e.cost = error_fun(e.cost)
  end
  return res
end

--- All nodes reachable via an outgoing edge.
-- Compute all nodes of `g` that are directly reachable from `n` via an
-- outgoing edge.
-- @param g A graph.
-- @param n Either a node or a node id.
function graph.outnodes (g, n)
  if type(n) == "number" then
    n = g.nodes[n]
  end
  -- assert(n, "Node not found.")
  local res = {}
  for _,edge in pairs(n.edges) do
    res[#res+1] = edge.to
  end
  return res
end

--- Generate a square two-dimensional table.
-- Genrate a table with `size`*`size` entries, each of which has the
-- value `init_value`.
-- @param size The size of one table dimension.
-- @param init_value The initial value of all entries.
-- @return A freshly allocated table.
function graph.generate_table (size, init_value)
  local res = {}
  for _ = 1,size do
    local t = {}
    for _ = 1,size do
      t[#t+1] = init_value
    end
    res[#res+1] = t
  end
  return res
end

--- Compute the tables for computing all paths in a graph.
-- Uses the Floyd-Warshall dynamic-programming algorithm to compute
-- tables `dist` and `next`.  `dist`'s entries at position `[i][j]`
-- contain the (weighted) cost of the cheapes path between nodes `i`
-- and `j` (where `i` and `j` are the node ids or, equivalently, their
-- position in the `nodes` array of the graph).  The cost is taken
-- from the transition's `cost` attribute.  The entry of `next` at
-- this position is the next node on the shortest path between the two
-- nodes.  These tables are then added to `g` as the `dist` and `next`
-- attributes; if these attributes already exist they are not taken
-- into account and overwritten.  The algorithm has time complexity
-- O(`#g.nodes`^3) and quadratic space complexity.
-- @param g The graph whose tables are computed.
-- @return The `dist` table.
-- @return The `next` table. 
function graph.floyd (g)
  local n = #g.nodes
  -- local dist = graph.generate_table(n, math.huge)
  local dist = alg.mat(n, n)
  local next = graph.generate_table(n, false)
  for _,e in ipairs(g.edges) do
    dist[e.from.id][e.to.id] = e.cost
    next[e.from.id][e.to.id] = e.to.id
  end
  for k = 1,n do
    for i = 1,n do
      for j = 1,n do
        if dist[i][k] + dist[k][j] < dist[i][j] then
          dist[i][j] = dist[i][k] + dist[k][j]
          next[i][j] = next[i][k]
        end
      end
    end
  end
  g.dist = dist
  g.next = next
  return dist,next
end

--- Compute the cheapest path between nodes in a graph.
-- Compute the cheapest path between two nodes in a graph.  The first
-- invocation of this function uses `floyd` to compute the `dist` and
-- `next` tables for `g` and therefore has time complexity
-- O(`#g.nodes`^3) and quadratic space complexity.  Subsequent
-- invocations have linear complexity in the size of the path.
-- @param g The graph.
-- @param n1 The start node.
-- @param n2 The end node. 
-- @return An array containing the ids of the nodes on the cheapest
--  path between 'n1' and 'n2'. 
function graph.path (g, n1, n2)
  if not g.dist then
    graph.floyd(g)
  end
  local dist,next = g.dist,g.next
  local u = type(n1) == "number" and n1 or n1.id
  local v = type(n2) == "number" and n2 or n2.id
  local path = {n1}
  if u == v then
    return path
  elseif not next[u][v] then
    return nil
  else
    while u ~= v do
      u = next[u][v]
      path[#path+1] = u
    end
  end
  return path
end

--- Return the shortest path between nodes in a graph as string.
-- Compute the sortest path between two nodes in a graph using the
-- function `path` and return the result as a string.
-- @param g The graph.
-- @param n1 The start node.
-- @param n2 The end node. 
-- @return A string representation of the shortest path. 
function graph.pathstring (g, n1, n2)
  local p = graph.path(g, n1, n2)
  local res = "["
  if p then
    local sep = ""
    for _,node in ipairs(p) do
      res = res .. sep .. tostring(node)
      sep = "->"
    end
    res = res .. "]"
  else
    res = "<no path>"
  end
  return res
end

-- If `use_global_go_action` is true, `make_go_action` generates
-- a call to action `go` with the ids of source and target as well
-- as the value of the transition as node arguments.
graph.use_global_go_action = true

xbt.define_function_name("go", function (node, path, state)
    local data = xbt.local_data(node, path:object_id(), state)
    --[[--
    assert(data.current_node_id == node.args.from, 
      "Performing a transition from wrong start node.")
    --]]--
    local from = data.current_node_id
    local to = node.args.to
    local graph_node = state.graph.nodes[to]
    local typeinfo = graph_node.type == "node" and "" or graph_node.type
    data.current_node_id = to
    local edge = state.graph.nodes[node.args.from].edges[node.args.to]
    --[[--
    print_trace(">>> R" .. path[1] .. ": Moving from state " ..
      from .. " to " ..  to .. " (cost " .. edge.cost - edge.cost%1 ..
      "). \t"  .. typeinfo)
    io.flush()
    assert(edge, "No edge for go action!")
    --]]--
    local samples = data.samples
    local cost = edge.cost
    if samples then
      data.samples[#samples+1] = {from=from, to=to, cost=cost}
    end
    return xbt.succeeded(cost, 0)
  end) 

local go_action_name_prefix = "__go_action_from_"   

function graph.make_go_action (edge)
  local target_node = edge.to
  local cost = edge.cost
  local value = target_node.value or 0
  local action_name
  if graph.use_global_go_action then
    action_name = "go"
  else
    action_name = go_action_name_prefix ..
      edge.from.id .. "_to_" .. target_node.id
    xbt.define_function_name(action_name, function (node, path, state)
        local data = xbt.local_data(node, path:object_id(), state)
        --[[--
        assert(data.current_node_id == node.args.from, 
          "Performing a transition from wrong start node")
        --]]--
        data.current_node_id = target_node.id
        return value
      end)
  end
  local action = xbt.fun(action_name,
    {from=edge.from.id, to=target_node.id, value=value},
    cost)
  return action
end

function graph.make_node_go_actions (node)
  -- `actions` is an array of actions, i.e., if there are i actions
  -- available for `node` then `actions` is an array of length i where
  -- each entry is a `go` action to some node.  `to_nodes` is a
  -- table indexed by the ids of the transition targets, i.e., if
  -- there is a transition from `node` to `n` then `to_nodes[n]`
  -- contains that action, otherwise it is falsy.
  local actions, to_nodes = {}, {}
  for _,edge in pairs(node.edges) do
    local action = graph.make_go_action(edge)
    actions[#actions+1] = action
    to_nodes[edge.to.id] = action
  end
  return actions, to_nodes
end

function graph.make_graph_action_tables (g)
  -- For each node `n` in `g`, `actions[n]` is an array of actions,
  -- i.e., if there are i actions available for a node `n` then
  -- `actions[n]` is an array of length i where each entry is a `go`
  -- action to some node.  `to_nodes` is a table indexed by the ids of
  -- the transition targets, i.e., if there is a transition from `n1`
  -- to `n2` then `to_nodes[n1][n2]` contains that action, otherwise
  -- it is falsy.
  local actions, to_nodes = {}, {}
  for id,node in ipairs(g.nodes) do
    actions[id], to_nodes[id] = graph.make_node_go_actions(node)
  end
  return actions, to_nodes
end

--- Update the cost of an edge based on a sample value.
function graph.update_edge_cost (g, sample)
  local from_id, to_id = sample.from, sample.to
  local from_node = g.nodes[from_id]
  local edge = from_node.edges[to_id]
  local old_cost, occ = edge.cost, edge.occurrences
  -- Update the edge cost to the average of all occurrences.  Note
  -- that we can use the `initial_edge_occurrences` parameter to
  -- influence how much the initial estimate is favored initially.
  edge.cost = old_cost + 1/(occ+1) * (sample.cost - old_cost) 
end

function graph.update_edge_costs (g, samples)
  local update_edge_cost = graph.update_edge_cost
  for _,sample in ipairs(samples) do
    update_edge_cost(g, sample)
  end
end

return graph
