--- Extended Behavior Trees in Lua.
-- @copyright © 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license Licensed under the MIT license, see the file LICENSE.md.

-- See the [readme file](README.md) for documentation (well, not yet).

local util = require("util")

local xbt = {}

-- A node can either be inactive, running, succeeded or failed.  We
-- define functions that return tables correspondig to these
-- XBT result types.  These tables share several attributes: The
-- Boolean `continue` attribute indicates whether a process can
-- continue.  Inactive and running processes can always continue;
-- failed processes never can.  Succeeded processes may set this
-- flag to true if, given more time, they can improve the value
-- they have previously returned.  Each XBT result carries a `cost`
-- attribute that indicates the execution cost for the evaluation
-- of the subtree that produces the result.  Succeeded nodes
-- additionally contain a `value` attribute  The difference
-- between `cost` and `value` is that _every_ evaluation
-- result has a cost but that only successful results carry a
-- value.  Running node return the cost accumulated so far;
-- their parents could use this to abort them if the accumulated
-- cost is too high.

--- Create an XBT result value for inactive nodes.
-- @param cost The cost of executing the node (including
--  all descendants).  Default is `0`.
-- @return An XBT result indicating that `node` is inactive.
function xbt.inactive (cost)
  if cost == nil then cost = 0 end
  return {status="inactive", continue=true, cost=cost}
end

--- Create an XBT result value for running nodes.
-- @param cost The cost of executing the node (including
--  all descendants).  Default is `0`.
-- @return An XBT result indicating that the node is running.
function xbt.running (cost)
  if cost == nil then cost = 0 end
  return {status="running", continue=true, cost=cost}
end

--- Create an XBT result value for successful nodes.
-- @param cost The cost of executing the node (including
--  all descendants).  Default is `0`.
-- @param value The value that was obtained by the node.
--  Default is `nil`.
-- @param continue Boolean indicating whether `value` can be
--  improved by further computation.  Default is `false`.
-- @return An XBT result indicating that the node has completed
--  successfully
function xbt.succeeded (cost, value, continue)
  if cost == nil then cost = 0 end
  continue = continue or false
  return {status="succeeded", continue=continue, cost=cost,
    value=value}
end

--- Create an XBT result value for failed nodes.
-- @param cost The cost of executing the node (including
--  all descendants).  Default is `0`.
-- @param reason A string describing the reason why the computation
--  failed.  Default is `nil`.
-- @return An XBT result indicating that the node has failed.
function xbt.failed (cost, reason)
  if cost == nil then cost = 0 end
  return {status="failed", continue=false, cost=cost,
    reason=reason}
end

--- Check whether a value is a valid result.
-- XBT results values are tables with a `status` attribute containing
-- one of the values `"inactive"`, `"running"`, `"succeeded"` or
-- `"failed"`, a numerical `cost` attribute and a `continue` attribute.
-- If the result is inactive or running the
-- `continue` attribute must be truthy, if the result is failed it must
-- be falsy.  If result has status `"succeeded"` the `continue` flag indicates
-- whether the node can continue in order to try to improve its result.
-- @param value The value to be checked.
-- @return A Boolean indicating whether `value` is a valid result.
function xbt.is_result (value)
  if type(value) == "table" then
    if type(value.cost) ~= "number" then return false end
    local status, cont = value.status, value.continue
    return ((status == "inactive" and cont)
      or (status == "running" and cont)
      or status == "succeeded"
      or (status == "failed" and not cont))
  else
    return false
  end
end

-- Predicates that check the status of a node
-- (or rather of the result returned by evaluating a node).

--- Check whether `result` has status `"inactive"`.
-- @param result The result to be checked.
-- @return A Boolean indicatus whether `result` is inactive.
function xbt.is_inactive (result)
  return result.status == "inactive"
end

--- Check whether `result` has status `"running"`.
-- @param result The result to be checked.
-- @return A Boolean indicatus whether `result` is running.
function xbt.is_running (result)
  return result.status == "running"
end

--- Check whether result has status `"succeeded"`.
-- @param result The result to be checked.
-- @return A Boolean indicatus whether `result` is succeeded.
function xbt.is_succeeded (result)
  return result.status == "succeeded"
end

---Check whether result has status `"failed"`.
-- @param result The result to be checked.
-- @return A Boolean indicatus whether `result` is failed.
function xbt.is_failed (result)
  return result.status == "failed"
end

--- Make a new state, or update a table to become a state.
-- Any table can be used as state (there is no need to have a 
-- particular metatable), but it has to contain certain
-- attributes:
--
-- * a `blackboard` for use by the nodes
--
-- * `node_results`, a table mapping paths to the corresponding
--   result values.
--
-- * `improve`, a Boolean flag that indicates whether nodes that
--   can improve their values should restart the computation or
--   return their previous values.
--
-- `make_state` takes a table and adds these attributes if necessry.
-- It can also be called without argument (or with a falsy value)
-- to generate a new state.
-- 
-- @param table Either falsy in which case a new state is created
--  or a table, in which case the missing fields are added.
-- @return A state.
function xbt.make_state (table)
  if not table then
    table = {}
  end
  if type(table) == "table" then
    util.maybe_add(table, "blackboard")
    util.maybe_add(table, "node_results")
    util.maybe_add(table, "improve", false)
    return table
  else
    error("Argument to make_state is not a table.")
  end
end

--- Set the evaluation result for a node.
-- @param node The node that was evaluated.
-- @param path A path identifying the instance of the node.
-- @param state The current state of the evaluation.
-- @result The result of the evaluation of `node`.  
function xbt.set_result(node, path, state, result)
  assert(xbt.is_result(result),
    tostring(result) .. " is not a valid XBT result.")
  state.node_results[tostring(path)] = result
  return result
end

--- Get the previous evaluation result for a node.
-- @param node The node to evaluate.
-- @param path A path identifying the instance of the node.
-- @param state The current state of the evaluation.
-- @result The result of the previous evaluation of `node`.  
--  If node was not previously evaluated, an `inactive` result
--  is returned.
function xbt.result(node, path, state)
  local res = state.node_results[tostring(path)]
  if not res then
    xbt.set_result(node, path, state, xbt.inactive())
  end
  assert(xbt.is_result(res),
    tostring(res) .. " is not a valid XBT result.")
  return res
end

--- Evaluators for ticking nodes.
-- Ticking is the fundamental operation that triggers
-- evaluation of nodes.  To make the node types extensible
-- we look up the ticking function in the table `evaluators`
-- using the `xbt_node_type` as key.  Each ticking function
-- receives three arguments: the node that is ticked, the
-- path to the node from the root of the XBT to uniquely
-- identify the node instance, and the state of the evaluation.
xbt.evaluators = {}

--- Compilers for XBTs
-- To achieve greater performance (or to integrate XBTs into
-- existing systems) it may be necessary to compile the XBT into
-- a representation that can be executed by the target system.
-- This table maps each node type to a table that in turn maps
-- backend names to a compiler for the given node type and
-- backend.
xbt.compilers = {}

--- The default cost for failures.
xbt.default_failure_cost = -1

--- Trigger evaluation of a node.
-- A tick triggers the evaluation of an XBT.  Each leaf node
-- should perform a small amount of computation when ticked
-- and then return an XBT result to its parent.  Long-running
-- computations repeatedly return a `running` result until
-- they either successfully complete with result `succeeded`
-- or fail with `failed`.
--  
-- In this implementation XBTs are not instanced, i.e., an
-- XBT holds no information about its evaluation.  Therefore
-- each XBT may be reused multiple times during an evaluation
-- (e.g., by call nodes or by structural sharing between
-- nodes in the XBT so that the tree becomes a DAG).
-- 
-- The function `tick` manages the evaluation state of the
-- XBT.  Each node is uniquely identified by its path in the
-- tree which is passed as second argument.  The `state`
-- passed as third argument contains the state of the XBTs
-- evaluation and methods to perform all actions that leaf
-- nodes may trigger in the environment.
--  
-- @param node The node to be ticked.
-- @param path The path to `node`.
-- @param state The current state of the XBT's evaluation.
-- @return The result of the evaluation of the subtree below
--  `node`.
function xbt.tick (node, path, state)
  state = xbt.make_state(state)
  path = path or util.path.new()
  assert(util.is_path(p), tostring(path) .. " is not a path.")
  local node_type = node.xbt_node_type
  assert(node_type, tostring(node) .. " has no xbt_node_type.")
  local e = xbt.evaluators[node_type]
  assert(e, "No evaluator for node type " .. node_type .. ".")
  local result
  result = e(node, path, state)
  xbt.set_result(node,path,state,result)
  return result
end

--- Check whether a node has already reached a state that allows
-- the computation to progress (even if the node could still be
-- improved.
-- @param node The node to be ticked.
-- @param state The current state of the evaluation.
-- @param path The path to the position of `node` in the XBT.
-- @return `true` if the node is either `succeeded` or `failed`,
--  `false` otherwise.
function xbt.is_done (node, path, state)
  local result = xbt.result(node,path,state)
  return xbt.is_succeeded(result) or xbt.is_failed(result)
end

--- Check whether a node can be ticked again, either to finish
-- an incomplete computation or to improve a previous result.
-- @param node The node to be ticked.
-- @param state The current state of the evaluation.
-- @param path The path to the position of `node` in the XBT.
-- @return A Boolean indicating whether ticking the node may
--  result in a different result than the one previously
--  obtained.
function xbt.can_continue (node, path, state)
  local result = xbt.result(node, path, state)
  return result.continue
end

--- Define an evaluation function and a constructor for `node_type`.
-- @param node_type The node type that will be stored as
--  `xbt_node_type` in all instances.
-- @param arg_names The names under which the arguments to the
--  constructor are stored in the resulting node.
--  For example, if `node_type` is `"foo"` and `arg_names` is
--  `{"bar", "baz"}`, `define_node_type` will define a function
--  `foo` that takes two arguments `arg1` and `arg2` and returns
--  a table `{xbt_node_type="foo", bar=arg1, baz=arg2, id=...}`.
--  Composite nodes must have an argument named `children`.
-- @param evaluator An evaluator function for this node type.
--  It is called with three arguments: a node, a path and a state.
--  The state always contains `blackboard`, `node_results` and `improve`
--  attributes.
-- @param compilers If provided the argument is a table mapping
--  backend names to functions that can compile the XBT for that
--  type of backend.  Default is `{}`.
function xbt.define_node_type(node_type, arg_names, evaluator, compilers)
  xbt[node_type] = function (...)
    local args = {...}
    local node = {xbt_node_type=node_type, id=util.uuid()}
    for i, arg_name in ipairs(arg_names) do
      node[arg_name] = args[i]
    end
    return node
  end
  xbt.evaluators[node_type] = evaluator
  xbt.compilers[node_type] = compilers or {}
end

--[[
--- Compute the relative paths to all descendants of a node. 
-- This function assumes that composite nodes define an attribute `children`
-- that evaluates to a list of all children.  The children of a node
-- depend only on the structure of the tree, therefore `xbt.descendants`
-- caches its result in the attribute  `descendants` of `node` to avoid
-- recomputing it.
-- @param node the node whose descendants will be computed
-- @return A list of descendants of `node`.
function xbt.descendants (node)
  if node.descendants then
    return node.descendants
  end
  local node_descendants = {} -- list of descendants
  if node.children then
    for i,child in pairs(node.children) do
      local child_path = util.path.new(i)
      node_descendants[child_path] = child
      -- A table mapping a descendant path relative to `child` to the
      -- descendant node.
      local child_descendants = xbt.descendants(child)
      -- We need to prefix the path to `child` to each descendant path.
      for desc_path, desc in pairs(child_descendants) do
        local node_relative_path = util.append(child_path:copy(), desc_path)
        node_descendants[node_relative_path] = desc
      end
    end
    node.descendants = node_descendants
    return node_descendants
  else
    node.descendants = {}
    return {}
  end
end
]]--

--- Set all descendants of a node to result status `inactive`.
-- The desendants and right siblings of an inactive node all
-- have to be inactive as well, so we stop the recursion into
-- children as soon as we encounter an inactive child.
function xbt.deactivate_descendants (node, path, state)
  for i, child in pairs(node.children) do
    local child_path = path:copy(i)
    local child_result = xbt.result(child, child_path, state)
    if xbt.is_inactive(child_result) then break end
    xbt.set_result(child, child_path, state, xbt.inactive())
    xbt.deactivate_descendants(child, child_path, state)
  end
end

-- We often want to serialize XBTs.  To make this more convenient
-- we allow functions appearing in leaf nodes to be specified as
-- strings, in which case we look up the function value in
-- `xbt.functions`.
xbt.functions = {};

function xbt.define_function_name (name, fun)
  if type(name) ~= "string" then
    error("Action name must be a string.")
  end
  xbt.functions[name] = fun
end

-- For testing purposes.
---[[
xbt.define_function_name("print", print)
xbt.define_function_name("print1", function (state)
  print(state)
  return 1
end)
xbt.define_function_name("print_and_succeed", function (state)
  print(state)
  return xbt.succeeded("Yeah!")
end)
--]]

function xbt.lookup_function (f)
  if type(f) == "string" then
    local result = xbt.functions[f]
    if result then
      return result
    else
      error("Action " .. f .. " is not defined.")
    end
  else
    return f
  end
end

-- An XBT node is represented by a table containing an xbt_node_type
-- attribute.  Nodes can either be composite (have child nodes) or
-- atomic (encapsulate a function or coroutine).  Each node has a
-- unique ID.

-- Function ("fun") nodes encapsulate a function.
-- The function has to return a valid XBT result.

xbt.define_node_type("fun", {"fun"}, function (node, state)
  local fun = xbt.lookup_function(node.fun)
  local result = fun(state)
  if xbt.is_result(result) then
    return result
  else
    return xbt.failed(xbt.default_failure_cost,
      "Function didn't return a valid result")
  end
end)

-- Action nodes are similar to functions, but they wrap the return
-- value of the function into a XBT result.
xbt.define_node_type("action", {"fun"}, function (node, state)
  local fun = xbt.lookup_function(node.fun)
  return xbt.succeeded(fun(state))
end)

-- The tick function for sequence nodes
local function tick_seq_node (node, path, state)
  -- If `node` has already returned a result indicating that it
  -- cannot continue in `state` then return the previous result.
  if xbt.is_done(node, path, state) then
    return xbt.result(node, state)
  end
  local sum = 0
  local result
  for _, child in pairs(node.children) do
    result = xbt.tick(child, path, state)
    if xbt.is_failed(result) then
      -- A child node has failed, which means that the sequence
      -- node is failed as well and cannot continue.  Prepare
      -- for the next activation before returning the failed
      -- result.
      xbt.deactivate_descendants(node, path, state)
      return result
    end
    if xbt.is_running(result) then
      return result
    end
    assert(xbt.is_succeeded(result),
      "Evaluation of seq-node child returned " ..
      tostring(result))
    -- TODO: Need more general handling of result values
    sum = sum + result.value
  end
  -- We have ticked all children with a successful result
  -- Reset the children's results to inactive
  xbt.deactivate_descendants(node, path, state)
  return xbt.succeeded(sum)
end

-- Sequence ("seq") nodes evaluate their children sequentially
-- and fail as soon as one of their children fails.
xbt.define_node_type("seq", {"children"}, tick_seq_node)

local function tick_choice_node (node, path, state)
  -- If `node` has already returned a result indicating that it
  -- cannot continue in `state` then return the previous result.
  if xbt.is_done(node, path, state) then
    return xbt.result(node, state)
  end
  local sum = 0
  local result
  for _, child in pairs(node.children) do
    result = xbt.tick(child, path, state)
    if xbt.is_succeeded(result) then
      -- We have succeeded; reset the children before
      -- returning
      xbt.deactivate_descendants(node, path, state)
      return xbt.succeeded(result.value + sum)
    end
    if xbt.is_running(result) then
      return result
    end
    assert(xbt.is_failed(result),
      "Evaluation of choice node returned " .. tostring(result))
    -- TODO: Need more general handling of result values
    sum = sum + result.value
  end
  -- We have ticked all children with a successful result
  -- Reset the children's results to inactive
  xbt.deactivate_descendants(node, path, state)
  return xbt.failed(sum, "All children failed")
end

-- Choice nodes evaluate their children sequentially and
-- succeed as soon as one of their children succeeds.
xbt.define_node_type("choice", {"children"}, tick_choice_node)

return xbt
