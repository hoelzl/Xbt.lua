--- Tests for the graph functions.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.

local util = require("xbt.util")
local graph = require("xbt.graph")
local lunatest = require("lunatest")

local test_iterations = 2

local assert_equal = lunatest.assert_equal
local assert_not_equal = lunatest.assert_not_equal
local assert_error = lunatest.assert_error
local assert_false = lunatest.assert_false
local assert_not_false = lunatest.assert_not_false
local assert_table = lunatest.assert_table
local assert_not_table = lunatest.assert_not_table
local assert_true = lunatest.assert_true
local assert_nil = lunatest.assert_nil

local t = {}

function t.test_node_dist ()
  local n1 = {x=1, y=1}
  local n2 = {x=4, y=5}
  local n3 = {x=10, y=13}
  assert_equal(0, graph.node_dist(n1, n1))
  assert_equal(5, graph.node_dist(n1, n2))
  assert_equal(5, graph.node_dist(n2, n1))
  assert_equal(10, graph.node_dist(n2, n3))
  assert_equal(10, graph.node_dist(n3, n2))
  assert_equal(15, graph.node_dist(n1, n3))
  assert_equal(15, graph.node_dist(n3, n1))
end

function t.test_diameter_1 ()
  local n1 = {x=1, y=1}
  local n2 = {x=4, y=5}
  local n3 = {x=10, y=13}
  assert_equal(0, graph.diameter({n1, n1}))
  assert_equal(5, graph.diameter({n1, n2}))
  assert_equal(5, graph.diameter({n2, n1}))
  assert_equal(10, graph.diameter({n2, n3}))
  assert_equal(10, graph.diameter({n3, n2}))
  assert_equal(15, graph.diameter({n1, n3}))
  assert_equal(15, graph.diameter({n3, n1}))
end
function t.test_diameter_2 ()
  local n1 = {x=1, y=1}
  local n2 = {x=4, y=5}
  local n3 = {x=10, y=13}
  assert_equal(15, graph.diameter({n1, n2, n3}))
  assert_equal(15, graph.diameter({n1, n3, n2}))
  assert_equal(15, graph.diameter({n2, n1, n3}))
  assert_equal(15, graph.diameter({n2, n3, n1}))
  assert_equal(15, graph.diameter({n3, n1, n2}))
  assert_equal(15, graph.diameter({n3, n2, n1}))
end

function t.test_diameter_3 ()
  local n1 = {x=1, y=1}
  local n2 = {x=4, y=5}
  local n3 = {x=10, y=13}
  -- These two nodes are inside the convex hull of the others and thus
  -- should not affect the diameter.  
  local n4 = {x=11, y=11}
  local n5 = {x=1, y=15}
  assert_equal(15, graph.diameter({n1, n2, n4, n3, n5}))
  assert_equal(15, graph.diameter({n1, n3, n2, n4, n5}))
  assert_equal(15, graph.diameter({n4, n1, n2, n5, n3}))
  assert_equal(15, graph.diameter({n4, n3, n5, n1, n2}))
  assert_equal(15, graph.diameter({n3, n2, n4, n5, n1}))
  assert_equal(15, graph.diameter({n3, n4, n1, n5, n2}))
end

function t.test_min_node_distance ()
  local n1 = {x=1, y=1}
  local n2 = {x=4, y=5}
  local n3 = {x=10, y=13}
  local n4 = {x=11, y=15}
  local n5 = {x=6, y=16}
  local nodes = {n1, n2, n3, n4, n5}
  assert_equal(5, graph.min_node_distance(n1, nodes))
  assert_equal(5, graph.min_node_distance(n2, nodes))
  assert_equal(5, graph.min_node_distance(n5, nodes))
end

function t.test_maxmin_distance_1 ()
  local n1 = {x=1, y=1}
  local n2 = {x=4, y=5}
  local n3 = {x=10, y=13}
  local nodes = {n1, n2, n3}
  assert_equal(10, graph.maxmin_distance(nodes))
end

function t.test_maxmin_distance_2 ()
  local n1 = {x=1, y=1}
  local n2 = {x=4, y=5}
  local n3 = {x=10, y=13}
  local n4 = {x=11, y=15}
  local n5 = {x=6, y=16}
  local nodes = {n1, n2, n3, n4, n5}
  assert_equal(5, graph.maxmin_distance(nodes))
end

function t.test_maxmin_distance_3 ()
  local n1 = {x=1, y=1}
  local n2 = {x=1, y=2}
  local n3 = {x=2, y=1}
  local n4 = {x=2, y=2}
  local nodes = {n1, n2, n3, n4}
  assert_equal(1, graph.maxmin_distance(nodes))
end

function t.test_generate_all_edges ()
  local n1 = {id=1, x=1, y=1, edges={}}
  local n2 = {id=2, x=1, y=2, edges={}}
  local n3 = {id=3, x=2, y=1, edges={}}
  local n4 = {id=4, x=2, y=2, edges={}}
  local nodes = {n1, n2, n3, n4}
  local edges = graph.generate_all_edges(nodes)
  assert_equal(12, #edges)
  assert_equal(1, edges[1].from.id)
  assert_equal(2, edges[1].to.id)
  assert_equal(2, edges[2].from.id)
  assert_equal(1, edges[2].to.id)
  assert_equal(1, edges[3].from.id)
  assert_equal(3, edges[3].to.id)
  assert_equal(3, edges[4].from.id)
  assert_equal(1, edges[4].to.id)
  assert_equal(1, edges[5].from.id)
  assert_equal(4, edges[5].to.id)
  assert_equal(4, edges[6].from.id)
  assert_equal(1, edges[6].to.id)
  assert_equal(2, edges[7].from.id)
  assert_equal(3, edges[7].to.id)
  assert_equal(3, edges[8].from.id)
  assert_equal(2, edges[8].to.id)
  assert_equal(2, edges[9].from.id)
  assert_equal(4, edges[9].to.id)
  assert_equal(4, edges[10].from.id)
  assert_equal(2, edges[10].to.id)
  assert_equal(3, edges[11].from.id)
  assert_equal(4, edges[11].to.id)
  assert_equal(4, edges[12].from.id)
  assert_equal(3, edges[12].to.id)
end

function t.test_generate_short_edges_1 ()
  local n1 = {id=1, x=1, y=1, edges={}}
  local n2 = {id=2, x=1, y=2, edges={}}
  local n3 = {id=3, x=2, y=1, edges={}}
  local n4 = {id=4, x=2, y=2, edges={}}
  local nodes = {n1, n2, n3, n4}
  local gen = graph.make_short_edge_generator(1.0)
  local edges = gen(nodes)
  assert_equal(8, #edges)
  assert_equal(1, edges[1].from.id)
  assert_equal(2, edges[1].to.id)
  assert_equal(2, edges[2].from.id)
  assert_equal(1, edges[2].to.id)
  assert_equal(1, edges[3].from.id)
  assert_equal(3, edges[3].to.id)
  assert_equal(3, edges[4].from.id)
  assert_equal(1, edges[4].to.id)
  assert_equal(2, edges[5].from.id)
  assert_equal(4, edges[5].to.id)
  assert_equal(4, edges[6].from.id)
  assert_equal(2, edges[6].to.id)
  assert_equal(3, edges[7].from.id)
  assert_equal(4, edges[7].to.id)
  assert_equal(4, edges[8].from.id)
  assert_equal(3, edges[8].to.id)
end

function t.test_generate_short_edges_2 ()
  local n1 = {id=1, x=1, y=1, edges={}}
  local n2 = {id=2, x=1, y=2, edges={}}
  local n3 = {id=3, x=2, y=1, edges={}}
  local n4 = {id=4, x=2, y=2, edges={}}
  local nodes = {n1, n2, n3, n4}
  local gen = graph.make_short_edge_generator(1.4)
  local edges = gen(nodes)
  assert_equal(8, #edges)
  assert_equal(1, edges[1].from.id)
  assert_equal(2, edges[1].to.id)
  assert_equal(2, edges[2].from.id)
  assert_equal(1, edges[2].to.id)
  assert_equal(1, edges[3].from.id)
  assert_equal(3, edges[3].to.id)
  assert_equal(3, edges[4].from.id)
  assert_equal(1, edges[4].to.id)
  assert_equal(2, edges[5].from.id)
  assert_equal(4, edges[5].to.id)
  assert_equal(4, edges[6].from.id)
  assert_equal(2, edges[6].to.id)
  assert_equal(3, edges[7].from.id)
  assert_equal(4, edges[7].to.id)
  assert_equal(4, edges[8].from.id)
  assert_equal(3, edges[8].to.id)
end

function t.test_generate_short_edges_3 ()
  local n1 = {id=1, x=1, y=1, edges={}}
  local n2 = {id=2, x=1, y=2, edges={}}
  local n3 = {id=3, x=2, y=1, edges={}}
  local n4 = {id=4, x=2, y=2, edges={}}
  local nodes = {n1, n2, n3, n4}
  local gen = graph.make_short_edge_generator(1.5)
  local edges = gen(nodes)
  assert_equal(12, #edges)
  assert_equal(1, edges[1].from.id)
  assert_equal(2, edges[1].to.id)
  assert_equal(2, edges[2].from.id)
  assert_equal(1, edges[2].to.id)
  assert_equal(1, edges[3].from.id)
  assert_equal(3, edges[3].to.id)
  assert_equal(3, edges[4].from.id)
  assert_equal(1, edges[4].to.id)
  assert_equal(1, edges[5].from.id)
  assert_equal(4, edges[5].to.id)
  assert_equal(4, edges[6].from.id)
  assert_equal(1, edges[6].to.id)
  assert_equal(2, edges[7].from.id)
  assert_equal(3, edges[7].to.id)
  assert_equal(3, edges[8].from.id)
  assert_equal(2, edges[8].to.id)
  assert_equal(2, edges[9].from.id)
  assert_equal(4, edges[9].to.id)
  assert_equal(4, edges[10].from.id)
  assert_equal(2, edges[10].to.id)
  assert_equal(3, edges[11].from.id)
  assert_equal(4, edges[11].to.id)
  assert_equal(4, edges[12].from.id)
  assert_equal(3, edges[12].to.id)
end


function t.test_generate_graph_1 ()
  local g = graph.generate_graph(4, 10, graph.generate_all_edges)
  local n1 = g.nodes[1]
  local n2 = g.nodes[2]
  local n3 = g.nodes[3]
  local n4 = g.nodes[4]
  local edges = g.edges
  assert_equal(12, #edges)
  assert_equal(n1, edges[1].from)
  assert_equal(n2, edges[1].to)
  assert_equal(n2, edges[2].from)
  assert_equal(n1, edges[2].to)
  assert_equal(n1, edges[3].from)
  assert_equal(n3, edges[3].to)
  assert_equal(n3, edges[4].from)
  assert_equal(n1, edges[4].to)
  assert_equal(n1, edges[5].from)
  assert_equal(n4, edges[5].to)
  assert_equal(n4, edges[6].from)
  assert_equal(n1, edges[6].to)
  assert_equal(n2, edges[7].from)
  assert_equal(n3, edges[7].to)
  assert_equal(n3, edges[8].from)
  assert_equal(n2, edges[8].to)
  assert_equal(n2, edges[9].from)
  assert_equal(n4, edges[9].to)
  assert_equal(n4, edges[10].from)
  assert_equal(n2, edges[10].to)
  assert_equal(n3, edges[11].from)
  assert_equal(n4, edges[11].to)
  assert_equal(n4, edges[12].from)
  assert_equal(n3, edges[12].to)
end

function t.test_generate_graph_2 ()
  local slack = 1.0
  for i=1,20 do
    local gen = graph.make_short_edge_generator(slack)
    local g = graph.generate_graph(20, 20, gen)
    -- Slack of 1.0 means that we have at least one outgoing edge for
    -- each node.
    assert_true(#g.edges >= #g.nodes, "Graph has too few edges.")
    -- We can have at most one edge from each node to each other node.
    -- We don't allow self edges so the second term is one less than
    -- the first.
    assert_true(#g.edges <= #g.nodes*(#g.nodes-1), "Graph has too many edges.")
    local maxmin = graph.maxmin_distance(g.nodes)
    for _,e in ipairs(g.edges) do
      assert_true(graph.node_dist(e.from, e.to) <= slack * maxmin,
        "Nodes are too far apart.")
    end
  end
end


function t.test_generate_graph_3 ()
  local slack = 0.5
  for i=1,20 do
    local gen = graph.make_short_edge_generator(slack)
    local g = graph.generate_graph(20, 20, gen)
    -- We don't know much about the minimum number of edges if slack
    -- is less than 1.0.
    -- We can have at most one edge from each node to each other node.
    -- We don't allow self edges so the second term is one less than
    -- the first.
    assert_true(#g.edges <= #g.nodes*(#g.nodes-1), "Graph has too many edges.")
    local maxmin = graph.maxmin_distance(g.nodes)
    for _,e in ipairs(g.edges) do
      assert_true(graph.node_dist(e.from, e.to) <= slack * maxmin,
        "Nodes are too far apart.")
    end
  end
end


function t.test_generate_graph_4 ()
  local slack = 2.0
  for i=1,20 do
    local gen = graph.make_short_edge_generator(slack)
    local g = graph.generate_graph(20, 20, gen)
    -- Slack > 1.0 means that we have at least one outgoing edge for
    -- each node.
    assert_true(#g.edges >= #g.nodes, "Graph has too few edges.")
    -- We can have at most one edge from each node to each other node.
    -- We don't allow self edges so the second term is one less than
    -- the first.
    assert_true(#g.edges <= #g.nodes*(#g.nodes-1), "Graph has too many edges.")
    local maxmin = graph.maxmin_distance(g.nodes)
    for _,e in ipairs(g.edges) do
      assert_true(graph.node_dist(e.from, e.to) <= slack * maxmin,
        "Nodes are too far apart.")
    end
  end
end


function t.test_generate_graph_5 ()
  local n1 = {x=1, y=1}
  local n2 = {x=1, y=2}
  local n3 = {x=2, y=1}
  local n4 = {x=2, y=2}
  local nodes = {n1, n2, n3, n4}
  local g = graph.generate_graph(nodes, 0, graph.generate_all_edges)
  assert_equal(n1, g.nodes[1])
  assert_equal(1, n1.id)
  assert_equal("node", n1.type)
  assert_equal(n2, g.nodes[2])
  assert_equal(2, n2.id)
  assert_equal("node", n2.type)
  assert_equal(n3, g.nodes[3])
  assert_equal(3, n3.id)
  assert_equal("node", n3.type)
  assert_equal(n4, g.nodes[4])
  assert_equal(4, n4.id)
  assert_equal("node", n4.type)
  local edges = g.edges
  assert_equal(12, #edges)
  assert_equal(n1, edges[1].from)
  assert_equal(n2, edges[1].to)
  assert_equal(n2, edges[2].from)
  assert_equal(n1, edges[2].to)
  assert_equal(n1, edges[3].from)
  assert_equal(n3, edges[3].to)
  assert_equal(n3, edges[4].from)
  assert_equal(n1, edges[4].to)
  assert_equal(n1, edges[5].from)
  assert_equal(n4, edges[5].to)
  assert_equal(n4, edges[6].from)
  assert_equal(n1, edges[6].to)
  assert_equal(n2, edges[7].from)
  assert_equal(n3, edges[7].to)
  assert_equal(n3, edges[8].from)
  assert_equal(n2, edges[8].to)
  assert_equal(n2, edges[9].from)
  assert_equal(n4, edges[9].to)
  assert_equal(n4, edges[10].from)
  assert_equal(n2, edges[10].to)
  assert_equal(n3, edges[11].from)
  assert_equal(n4, edges[11].to)
  assert_equal(n4, edges[12].from)
  assert_equal(n3, edges[12].to)
end


function t.test_copy_graph_1 ()
  local slack = 1.0
  for i=1,test_iterations do
    local g = graph.generate_graph(12, 20)
    local gc = graph.copy(g)
    for i,n in ipairs(g.nodes) do
      assert_true(n ~= gc.nodes[i], "Node and its copy are identical.")
      assert_true(util.equal(n, gc.nodes[i]), "Node and its copy not equal.")
    end
    for i,e in ipairs(g.edges) do
      assert_true(e ~= gc.edges[i], "Edge and its copy are identical.")
      assert_true(util.equal(e, gc.edges[i]), "Edge and its copy not equal.")
    end
  end
end

function t.test_copy_graph_2 ()
  local slack = 1.0
  for i=1,test_iterations do
    local gen = graph.make_short_edge_generator(slack)
    local g = graph.generate_graph(12, 20, gen)
    local gc = graph.copy(g)
    for i,n in ipairs(g.nodes) do
      assert_true(n ~= gc.nodes[i], "Node and its copy are identical.")
      assert_true(util.equal(n, gc.nodes[i]), "Node and its copy not equal.")
    end
    for i,e in ipairs(g.edges) do
      assert_true(e ~= gc.edges[i], "Edge and its copy are identical.")
      assert_true(util.equal(e, gc.edges[i]), "Edge and its copy not equal.")
    end
  end
end


function t.test_copy_graph_badly_1 ()
  local slack = 1.0
  for i=1,test_iterations do
    local g = graph.generate_graph(12, 20)
    local gc = graph.copy_badly(g, 0, 0, 0)
    for i,n in ipairs(g.nodes) do
      assert_true(n ~= gc.nodes[i], "Node and its copy are identical.")
      assert_true(util.equal(n, gc.nodes[i]), "Node and its copy not equal.")
    end
    for i,e in ipairs(g.edges) do
      assert_true(e ~= gc.edges[i], "Edge and its copy are identical.")
      assert_true(util.equal(e, gc.edges[i]), "Edge and its copy not equal.")
    end
  end
end

function t.test_copy_graph_badly_2 ()
  local slack = 1.0
  for i=1,test_iterations do
    local gen = graph.make_short_edge_generator(slack)
    local g = graph.generate_graph(12, 20, gen)
    local gc = graph.copy_badly(g, 0, 0, 0)
    for i,n in ipairs(g.nodes) do
      assert_true(n ~= gc.nodes[i], "Node and its copy are identical.")
      assert_true(util.equal(n, gc.nodes[i]), "Node and its copy not equal.")
    end
    for i,e in ipairs(g.edges) do
      assert_true(e ~= gc.edges[i], "Edge and its copy are identical.")
      assert_true(util.equal(e, gc.edges[i]), "Edge and its copy not equal.")
    end
  end
end

local function compare_node_and_bad_copy (m, n)
  assert_true(n ~= m, "Node and its copy are identical.")
  assert_equal(m.id, n.id)
  assert_equal(m.x, n.x)
  assert_equal(m.y, n.y)
  assert_equal("node", n.type)
end

-- Don't know how to really test the copy badly function, except that
-- it generates some graph.
function t.test_copy_graph_badly_3 ()
  local slack = 1.0
  for i=1,test_iterations do
    local g = graph.generate_graph(12, 20)
    local gc = graph.copy_badly(g)
    for i,n in ipairs(g.nodes) do
      compare_node_and_bad_copy(gc.nodes[i], n)
    end
    for i,e in ipairs(g.edges) do
      assert_true(e ~= gc.edges[i], "Edge and its copy are identical.")
    end
  end
end

function t.test_copy_graph_badly_4 ()
  local slack = 1.0
  for i=1,test_iterations do
    local gen = graph.make_short_edge_generator(slack)
    local g = graph.generate_graph(12, 20, gen)
    local gc = graph.copy_badly(g)
    for i,n in ipairs(g.nodes) do
      compare_node_and_bad_copy(gc.nodes[i], n)
    end
    for i,e in ipairs(g.edges) do
      assert_true(e ~= gc.edges[i], "Edge and its copy are identical.")
    end
  end
end

function t.test_outnodes_1 ()
  local n1 = {x=1, y=1}
  local n2 = {x=1, y=2}
  local n3 = {x=2, y=1}
  local n4 = {x=2, y=2}
  local nodes = {n1, n2, n3, n4}
  local g = graph.generate_graph(nodes, 0, graph.generate_all_edges)
  assert_true(util.equal({n2,n3,n4}, graph.outnodes(g, 1)), "Bad outnodes for (g,1).")
  assert_true(util.equal({n2,n3,n4}, graph.outnodes(g, n1)), "Bad outnodes for (g,n1).")
end

function t.test_outnodes_2 ()
  local n1 = {x=1, y=1}
  local n2 = {x=1, y=2}
  local n3 = {x=2, y=1}
  local n4 = {x=2, y=2}
  local nodes = {n1, n2, n3, n4}
  local gen = graph.make_short_edge_generator(1)
  local g = graph.generate_graph(nodes, 0, gen)
  assert_true(util.equal({n2,n3}, graph.outnodes(g, 1)), "Bad outnodes for (g,1).")
  assert_true(util.equal({n2,n3}, graph.outnodes(g, n1)), "Bad outnodes for (g,n1).")
end

function t.test_generate_table ()
  local table = graph.generate_table(10, 42)
  for i=1,10 do
    for j=1,10 do
      assert_equal(42, table[i][j])
    end
  end
end

function t.test_floyd ()
  -- The graph looks like this, with 1 unit distance between each closest pair of nodes
  --    n1   n2
  --    n3
  --    n4
  local n1 = {x=1, y=1}
  local n2 = {x=1, y=2}
  local n3 = {x=2, y=1}
  local n4 = {x=3, y=1}
  local nodes = {n1, n2, n3, n4}
  local gen = graph.make_short_edge_generator(1)
  local g = graph.generate_graph(nodes, 0, gen)
  local dist,next = graph.floyd(g)
  assert_equal(dist, g.dist)
  assert_equal(next, g.next)
  assert_equal(2, dist[1][1])
  assert_equal(1, dist[1][2])
  assert_equal(1, dist[1][3])
  assert_equal(2, dist[1][4])
  assert_equal(1, dist[2][1])
  assert_equal(2, dist[2][2])
  assert_equal(2, dist[2][3])
  assert_equal(3, dist[2][4])
  assert_equal(1, dist[3][1])
  assert_equal(2, dist[3][2])
  assert_equal(2, dist[3][3])
  assert_equal(1, dist[3][4])
  assert_equal(2, dist[4][1])
  assert_equal(3, dist[4][2])
  assert_equal(1, dist[4][3])
  assert_equal(2, dist[4][4])
  assert_equal(2, next[1][1])
  assert_equal(2, next[1][2])
  assert_equal(3, next[1][3])
  assert_equal(3, next[1][4])
  assert_equal(1, next[2][1])
  assert_equal(1, next[2][2])
  assert_equal(1, next[2][3])
  assert_equal(1, next[2][4])
  assert_equal(1, next[3][1])
  assert_equal(1, next[3][2])
  assert_equal(1, next[3][3])
  assert_equal(4, next[3][4])
  assert_equal(3, next[4][1])
  assert_equal(3, next[4][2])
  assert_equal(3, next[4][3])
  assert_equal(3, next[4][4])
end

function t.test_absolute_difference ()
  local n1 = {x=1, y=1}
  local n2 = {x=1, y=2}
  local n3 = {x=2, y=1}
  local n4 = {x=3, y=1}
  local nodes = {n1, n2, n3, n4}
  local gen = graph.make_short_edge_generator(1)
  local g = graph.generate_graph(nodes, 0, gen)
  graph.floyd(g)
  local gc = graph.copy_badly(g, 1, 1, 1)
  graph.floyd(gc)
  assert_equal(0, graph.absolute_difference(g.dist, g.dist))
  assert_true(graph.absolute_difference(g.dist, gc.dist) > 0)
end

function t.test_different_choices ()
  local n1 = {x=1, y=1}
  local n2 = {x=1, y=2}
  local n3 = {x=2, y=1}
  local n4 = {x=3, y=1}
  local nodes = {n1, n2, n3, n4}
  local gen = graph.make_short_edge_generator(1)
  local g = graph.generate_graph(nodes, 0, gen)
  graph.floyd(g)
  local gc = graph.copy_badly(g, 1, 1, 1)
  graph.floyd(gc)
  assert_equal(0, graph.different_choices(g.next, g.next))
  assert_true(graph.different_choices(g.next, gc.next) > 0)
end

function t.test_path ()
  -- The graph looks like this, with 1 unit distance between each closest pair of nodes
  --    n1   n2
  --    n3
  --    n4
  local n1 = {x=1, y=1}
  local n2 = {x=1, y=2}
  local n3 = {x=2, y=1}
  local n4 = {x=3, y=1}
  local nodes = {n1, n2, n3, n4}
  local gen = graph.make_short_edge_generator(1)
  local g = graph.generate_graph(nodes, 0, gen)
  assert_true(util.equal({1}, graph.path(g, n1, n1)))
  assert_true(util.equal({1,2}, graph.path(g, n1, n2)))
  assert_true(util.equal({1,3}, graph.path(g, n1, n3)))
  assert_true(util.equal({1,3,4}, graph.path(g, n1, n4)))
  assert_true(util.equal({2,1}, graph.path(g, n2, n1)))
  assert_true(util.equal({2}, graph.path(g, n2, n2)))
  assert_true(util.equal({2,1,3}, graph.path(g, n2, n3)))
  assert_true(util.equal({2,1,3,4}, graph.path(g, n2, n4)))
  assert_true(util.equal({3,1}, graph.path(g, n3, n1)))
  assert_true(util.equal({3,1,2}, graph.path(g, n3, n2)))
  assert_true(util.equal({3}, graph.path(g, n3, n3)))
  assert_true(util.equal({3,4}, graph.path(g, n3, n4)))
  assert_true(util.equal({4,3,1}, graph.path(g, n4, n1)))
  assert_true(util.equal({4,3,1,2}, graph.path(g, n4, n2)))
  assert_true(util.equal({4,3}, graph.path(g, n4, n3)))
  assert_true(util.equal({4}, graph.path(g, n4, n4)))
end

return t