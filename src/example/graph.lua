--- Generating and finding paths in graphs.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.

local graph = {}

function graph.node_dist (n1, n2)
  local x1,y1 = n1.x, n1.y
  local x2,y2 = n2.x, n2.y
  local dx,dy = x1-x2, y1-y2
  return math.sqrt(dx*dx + dy*dy)
end

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

function graph.maxmin_distance(nodes)
  local dist = 0
  for _,n in ipairs(nodes) do
    local d = graph.min_node_distance(n, nodes)
    if d > dist then
      dist = d
    end
  end
  return dist
end

function graph.generate_all_edges (nodes)
  local edges = {}
  for i = 1,#nodes-1 do
    for j = i+1,#nodes do
      local n1,n2 = nodes[i], nodes[j]
      local dist = graph.node_dist(n1, n2)
      local edge1 = {from=n1, to=n2, type="edge", dist=dist, cost=dist}
      edges[#edges+1] = edge1
      n1.edges[j] = edge1
      local edge2 = {from=n2, to=n1, type="edge", dist=dist, cost=dist}
      edges[#edges+1] = edge2
      n2.edges[i] = edge2
    end
  end
  return edges
end

function graph.make_short_edge_generator (slack)
  slack = slack or 0
  return function (nodes)
    local edges = {}
    local maxmin_dist = graph.maxmin_distance(nodes)
    for i = 1,#nodes-1 do
      for j = i+1,#nodes do
        local n1,n2 = nodes[i], nodes[j]
        local dist = graph.node_dist(n1, n2)
        if dist < maxmin_dist + slack then
          local edge1 = {from=n1, to=n2, type="edge", dist=dist, cost=dist}
          edges[#edges+1] = edge1
          n1.edges[j] = edge1
          local edge2 = {from=n2, to=n1, type="edge", dist=dist, cost=dist}
          edges[#edges+1] = edge2
          n2.edges[i] = edge2
        end
      end
    end
    return edges
  end -- function
end

function graph.generate_graph (number_of_nodes, size, edge_generator)
  edge_generator = edge_generator or graph.generate_all_edges
  if not size then size = 500 end
  if type(size) == "number" then size={x=size,y=size} end
  local nodes = {}
  for i = 1,number_of_nodes do
    local x,y = math.random(size.x), math.random(size.y)
    nodes[#nodes+1] = {id=i, x=x, y=y, type="node", edges={}}
  end
  local edges = edge_generator(nodes)
  return {nodes=nodes, edges=edges}
end

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

function graph.floyd (g)
  local n = #g.nodes
  local dist = graph.generate_table(n, math.huge)
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

function graph.path (g, n1, n2)
  if not g.dist then
    graph.floyd(g)
  end
  local dist,next = g.dist,g.next
  local u = type(n1) == "number" and n1 or n1.id
  local v = type(n2) == "number" and n2 or n2.id
  local path = {}
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

local your_graph = graph.generate_graph(10, 500, graph.make_short_edge_generator())
print(graph.diameter(your_graph.nodes))
print(graph.maxmin_distance(your_graph.nodes))
print("1->1:", graph.path(your_graph, 1, 1)[1])
print("1->2:", graph.path(your_graph, 1, 2)[1])
print("1->3:", graph.path(your_graph, 1, 3)[1])
print("1->4:", graph.path(your_graph, 1, 4)[1])
print("1->5:", graph.path(your_graph, 1, 5)[1])
local my_graph = graph.generate_graph(30, {x=200, y=300})
print(graph.diameter(my_graph.nodes))
print(graph.maxmin_distance(my_graph.nodes))
print(#my_graph.edges)

return graph
