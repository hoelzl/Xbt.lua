--- Generating and finding paths in graphs.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.
-- @module xbt.graph

local xbt = require("xbt")
local util = require("xbt.util")
-- local tablex = require("pl.tablex")
local dist = require("sci.dist")
local alg = require("sci.alg")
local graph = {}

--- Print information about the execution of some graph functions.
graph.print_trace_info = false

local function print_trace (...)
  if graph.print_trace_info then
    print(...)
  end
end

--- Compute the distance between two nodes.
-- @param n1 The first node.
-- @param n2 The second node.
-- @return The distance between `n1` and `n2`.
function graph.node_dist (n1, n2)
  local x1,y1 = n1.x, n1.y
  local x2,y2 = n2.x, n2.y
  local dx,dy = x1-x2, y1-y2
  return math.sqrt(dx*dx + dy*dy)
end

--- Compute the diameter of a graph.
-- The diameter of (the nodes of) a graph $g$ is the maximum distance
-- between any two nodes of $g$.  This function accepts a set of
-- nodes, /not/ a graph.
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
-- If `node` appears in the set of nodes it is ignored, i.e., the
-- result is always positive.  If `nodes` is empty or all members of
-- `nodes` are equal to `n`, the value `math.huge` is returned.
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
-- thinks that it has already seen the initial reward of the edge
-- before the first update.
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
        dist=dist, reward=-dist,
        occurrences=graph.initial_edge_occurrences}
      edges[#edges+1] = edge1
      n1.edges[j] = edge1
      local edge2 = {from=n2, to=n1, type="edge",
        dist=dist, reward=-dist,
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
            dist=dist, reward=-dist,
            occurrences=graph.initial_edge_occurrences}
          edges[#edges+1] = edge1
          n1.edges[j] = edge1
          local edge2 = {from=n2, to=n1, type="edge",
            dist=dist, reward=-dist,
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
-- @param nodes An array of nodes or the number of nodes in the graph.
--  If a node array is passed as argument, each node must have `x` and
--  `y` attributes that describe its physical location.  Each node is
--  assigned an integer attribute `id` that corresponds to its
--  position in the array of nodes, a `type` attribute that has the
--  value `"node"`, and an array of the same size as the nodes table
--  that contains `nil` for indices of nodes for which there is no
--  edge, and the transition for indices for which a transition
--  exists.  The entries in this array have to be filled in by the
--  `edge_gen`.
-- @param size The size of the are in which the nodes are located.
--  May either be a number, in which case both x and y dimension are
--  set to this number, or a pair `{x=x, y=y}` that specifies the
--  dimensions for x and y separately.  Defaults to 500.  Ignored when
--  an arrayo of nodes is passed in.
-- @param edge_gen A function that generates the edges for the
--  graph given the table of nodes.  The generator has to add each
--  edge to the correct index of the `edges` array of its start node. 
function graph.generate_graph (nodes, size, edge_gen)
  edge_gen = edge_gen or graph.generate_all_edges
  if not size then size = 500 end
  if type(size) == "number" then size={x=size,y=size} end
  if type(nodes) == "number" then
    local number_of_nodes = nodes
    nodes = {}
    for i = 1,number_of_nodes do
      local x = util.random(0, size.x)
      local y = util.random(0, size.y)
      nodes[#nodes+1] = {id=i, x=x, y=y, type="node", edges={}}
    end
  else
    for i,n in ipairs(nodes) do
      n.id = i
      n.type = "node"
      n.edges = {}
    end
  end
  local edges = edge_gen(nodes)
  return {nodes=nodes, edges=edges}
end

--- Copy a graph.
-- This function copies a graph, taking care of the cycles appearing
-- in the graph structure.  It copys _only_ the default attributes
-- of a graph and ignores any attributes stored by the user.
function graph.copy (g)
  local nodes, edges = {}, {}
  for i,n in ipairs(g.nodes) do
    nodes[i] = {id=i, x=n.x, y=n.y, type=n.type, edges = {},
      value=n.value}
  end
  for i,e in ipairs(g.edges) do
    local from_id, to_id = e.from.id, e.to.id
    local new_from, new_to = nodes[from_id], nodes[to_id]
    local new_edge = {from=new_from, to=new_to,
      type=e.type, dist=e.dist, reward=e.reward,
      occurrences=e.occurrences}
    edges[i] = new_edge
    new_from.edges[to_id] = new_edge
  end
  return {nodes=nodes, edges=edges}
end

local function generate_edges (edges, n1, i, n2, j, reward, occ)
  local dist = graph.node_dist(n1, n2)
  local edge1 = {from=n1, to=n2, type="edge",
    dist=dist, reward=reward,
    occurrences=occ}
  edges[#edges+1] = edge1
  n1.edges[j] = edge1;
  local edge2 = {from=n2, to=n1, type="edge",
    dist=dist, reward=reward,
    occurrences=occ}
  edges[#edges+1] = edge2
  n2.edges[i] = edge2
end

--- Copy a graph, introducing errors in the edge rewards.
-- @param g The graph to copy.
-- @param p_del The probability with which existing edges are deleted.
--  Defaults to 0.1.
-- @param p_gen The probability with which new edges will be introduced.
--  Defaults to 0.05.
-- @param err A function that computes the error for the new edge reward,
--  based on the old reward, or the standard deviation of a normal
--  distribution with which the existing rewards are modified.
--  Defaults to 1/20 the diameter of `g`.
function graph.copy_badly (g, p_del, p_gen, err)
  p_del = p_del or 0.1
  p_gen = p_gen or 0.05
  local err_fun
  if not err then err = graph.diameter(g.nodes) / 20 end
  if type(err) == "number" then
    if err <= 0 then
      err_fun = function (reward) return reward end
    else
      local sd = dist.normal(0, err or 1)
      err_fun = function (reward) return reward + sd:sample(util.rng) end
    end
  else
    err_fun = err
  end
  local nodes,edges = {},{}
  for i,n in ipairs(g.nodes) do
    nodes[i] = {id=i, x=n.x, y=n.y, type=n.type, edges = {},
      value=n.value}
  end
  for i = 1,#nodes-1 do
    for j = i+1,#nodes do
      local n1,n2 = nodes[i], nodes[j]
      local o1,o2 = g.nodes[i], g.nodes[j]
      local old_edge = o1.edges[j]
      if old_edge then
        if util.rng:sample() > p_del then
          -- Don't delete; create new edges with modified reward
          local reward = err_fun(old_edge.reward or 0)
          local occ = old_edge.occurrences or graph.initial_edge_occurrences
          generate_edges(edges, n1, i, n2, j, reward, occ)
        end
      else
        if util.rng:sample() <= p_gen then
          local reward = -graph.node_dist(n1, n2)
          local occ = graph.initial_edge_occurrences
          generate_edges(edges, n1, i, n2, j, reward, occ) 
        end
      end
    end
  end
  return {nodes=nodes, edges=edges}
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
  assert(n, "Node not found.")
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

--- Delete a transition from a graph.
function graph.delete_transition (g, from, to)
  if type(from == "number") then from = g.nodes[from] end
  if type(to == "number") then to = g.nodes[to] end
  local from_id = from.id
  local to_id = to.id
  from.edges[to_id] = nil
  for i,e in ipairs(g.edges) do
    if e.from.id == from_id and e.to.id == to_id then
      table.remove(g.edges, i)
      break
    end
  end
end

--- Compute the tables for computing all paths in a graph.
-- Uses the Floyd-Warshall dynamic-programming algorithm to compute
-- tables `rewards` and `next`.  `rewards`'s entries at position `[i][j]`
-- contain the (weighted) reward of the cheapest path between nodes `i`
-- and `j` (where `i` and `j` are the node ids or, equivalently, their
-- position in the `nodes` array of the graph).  The reward is taken
-- from the transition's `reward` attribute.  The entry of `next` at
-- this position is the next node on the shortest path between the two
-- nodes.  These tables are then added to `g` as the `rewards` and `next`
-- attributes; if these attributes already exist they are not taken
-- into account and overwritten.  The algorithm has time complexity
-- O(`#g.nodes`^3) and quadratic space complexity.
-- @param g The graph whose tables are computed.
-- @return The `rewards` table.
-- @return The `next` table. 
function graph.floyd (g)
  print_trace("Running Floyd algorithm.")
  local n = #g.nodes
  local rewards = graph.generate_table(n, -math.huge)
  -- Use this version for higher performance (but it does not work with
  -- the debugger, unfortunately.
  -- local rewards = alg.mat(n, n)
  local next = graph.generate_table(n, false)
  for _,e in ipairs(g.edges) do
    rewards[e.from.id][e.to.id] = e.reward
    next[e.from.id][e.to.id] = e.to.id
  end
  for k = 1,n do
    for i = 1,n do
      for j = 1,n do
        if rewards[i][k] + rewards[k][j] > rewards[i][j] then
          rewards[i][j] = rewards[i][k] + rewards[k][j]
          next[i][j] = next[i][k]
        end
      end
    end
  end
  g.rewards = rewards
  g.next = next
  return rewards,next
end

--- Compute the difference in rewards between two `rewards` tables
-- of the same size.
function graph.absolute_difference (rewards1, rewards2)
  local res = 0
  local size = #rewards1
  for i=1,size do
    for j=1,size do
      res = res + math.abs(rewards1[i][j] - rewards2[i][j])
    end
  end
  return res
end

--- Compute the number of different choices for two `next` tables.
function graph.different_choices (next1, next2)
  local res = 0
  for i,n in ipairs(next1) do
    for j,v in ipairs(n) do
      if v ~= next2[i][j] then
        res = res + 1
      end
    end
  end
  return res
end

--- Compute the cheapest path between nodes in a graph.
-- Compute the cheapest path between two nodes in a graph.  The first
-- invocation of this function uses `floyd` to compute the `rewards` and
-- `next` tables for `g` and therefore has time complexity
-- O(`#g.nodes`^3) and quadratic space complexity.  Subsequent
-- invocations have linear complexity in the size of the path.
-- @param g The graph.
-- @param n1 The start node.
-- @param n2 The end node. 
-- @return An array containing the ids of the nodes on the cheapest
--  path between 'n1' and 'n2'. 
function graph.path (g, n1, n2)
  if not g.rewards then
    graph.floyd(g)
  end
  local rewards,next = g.rewards,g.next
  local u = type(n1) == "number" and n1 or n1.id
  local v = type(n2) == "number" and n2 or n2.id
  local path = {n1.id}
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

--- The cost of a failed action.
-- The reward of a failed navigation action is the negated value of the cost.
graph.failure_cost = 100

function graph.go_action (node, path, state)
  local data = xbt.local_data(node, path:root_path(), state)
  -- Don't use data.graph, since we want to use the "real-world" graph, not
  -- the one the robot thinks it has. 
  local graph = state.graph
  local from_id = data.current_node_id
  assert(from_id == node.args.from_id,
    "Performing a transition from wrong start node.")
  local to_id = node.args.to_id
  local edge = graph.nodes[from_id].edges[to_id]
  if not edge then
    print_trace(">>> R" .. string.sub(path.id, 1, 4)
      .. " tried to perform an invalid move to "
      .. to_id .. ".")
    io.flush()
    local reward = -(graph.failure_cost or 100)
    data.samples[#data.samples+1] = {result="failure", from_id=from_id, to_id=to_id, reward=reward}
    return xbt.failed(reward)
  end
  data.current_node_id = to_id
  ---[[--
  local graph_node = graph.nodes[to_id]
  local typeinfo = graph_node.type == "node" and "" or graph_node.type
  print_trace(">>> R" .. string.sub(path.id, 1, 4)
    .. ": Moving from state " .. from_id .. " to " ..  to_id 
    .. " (reward " .. edge.reward - edge.reward%1 .. "). \t"  .. typeinfo)
  io.flush()
  --]]--
  local samples = data.samples
  if samples then
    local reward = edge.reward
    data.samples[#samples+1] = {result="go", from_id=from_id, to_id=to_id, reward=reward}
  end
  return xbt.succeeded(edge.reward)
end

xbt.define_function_name("go", graph.go_action) 

function graph.make_go_action (edge)
  local target_node = edge.to
  local reward = edge.reward
  local value = target_node.value or 0
  local action = xbt.fun("go",
    {from_id=edge.from.id, to_id=target_node.id, value=value},
    reward)
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

--- Update the reward of an edge based on a sample value.
function graph.update_edge_reward (g, sample)
  local from_id, to_id = sample.from_id, sample.to_id
  if sample.result == "go" then
    local from_node = g.nodes[from_id]
    local edge = from_node.edges[to_id]
    if edge then
      local old_reward, occ = edge.reward, edge.occurrences
      -- Update the edge reward to the average of all occurrences.  Note
      -- that we can use the `initial_edge_occurrences` parameter to
      -- influence how much the initial estimate is favored initially.
      local new_reward = old_reward + 1/(occ+1) * (sample.reward - old_reward)
      print_trace("Updating reward (go): ", from_id, to_id, old_reward, occ, sample.reward, new_reward)
      edge.reward = new_reward
      edge.occurrences = edge.occurrences + 1
      return math.abs(old_reward), math.abs(sample.reward - old_reward)
    else
      print_trace("Updating reward (new edge): ", from_id, to_id)
      local to_node = g.nodes[to_id]
      edge = {from=from_node, to=to_node, type="edge",
        dist=dist, reward=sample.reward,
        occurrences=graph.initial_edge_occurrences}
      from_node.edges[to_id] = edge
      g.edges[#g.edges+1] = edge
    end
  elseif sample.result == "failure" then
    print_trace("Updating reward (failed): ", from_id, to_id)
    graph.delete_transition(g, from_id, to_id)
  else
  end
end

function graph.update_edge_rewards (g, samples)
  local update_edge_reward = graph.update_edge_reward
  local total,diff
  for _,sample in ipairs(samples) do
    local t,d = update_edge_reward(g, sample)
    if t and d then
      total = (total or 0) + t
      diff = (diff or 0) + d
    end
  end
  if diff and total then
    return diff/total
  else
    return nil
  end
end

return graph
