--- Extended Behavior Trees in Lua.
-- @copyright © 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license Licensed under the MIT license, see the file LICENSE.md.

-- See the [readme file](README.md) for documentation (well, not yet).

local util = require("util")
local path = util.path

local xbt = {}

-- A node can either be inactive, running, succeeded or failed.
-- We define functions that return the correspondig status as
-- tables.  The continue flag indicates whether a process can
-- continue.  Inactive and running processes can always continue;
-- failed processes never can.  Succeeded processes may set this
-- flag to true if they can improve the value they returned
-- given more time.  Each status carries a cost that indicates
-- the execution cost for the evaluation of the status.  The
-- difference between cost and value is that _every_ evaluation
-- result has a cost but that only successful results carry a
-- value.  Running node return the cost accumulated so far;
-- their parents could use this to abort them if the accumulated
-- cost is too high.

--- Create a status indicator for inactive nodes.
-- @param cost The cost of executing the node (including
--  all descendants).  Default is `0`.
-- @return An status indicating that `node` is inactive.
function xbt.inactive (cost)
  if cost == nil then cost = 0 end
  return {status="inactive", continue=true, cost=cost}
end

--- Create a status indicator for running nodes.
-- @param cost The cost of executing the node (including
--  all descendants).  Default is `0`.
-- @return A status indicating that the node is running.
function xbt.running (cost)
  if cost == nil then cost = 0 end
  return {status="running", continue=true, cost=cost}
end

--- Create a status indicator for successful nodes.
-- @param cost The cost of executing the node (including
--  all descendants).  Default is `0`.
-- @param value The value that was obtained by the node.
--  Default is `nil`.
-- @param continue Boolean indicating whether `value` can be
--  improved by further computation.  Default is `false`.
-- @return A status indicating that the node has completed
--  successfully
function xbt.succeeded (cost, value, continue)
  if cost == nil then cost = 0 end
  continue = continue or false
  return {status="succeeded", continue=continue, cost=cost,
    value=value}
end

--- Create a status indicator for failed nodes.
-- @param cost The cost of executing the node (including
--  all descendants).  Default is `0`.
-- @param reason A string describing the reason why the computation
--  failed.  Default is `nil`.
-- @return A status indicating that the node has failed.
function xbt.failed (cost, reason)
  if cost == nil then cost = 0 end
  return {status="failed", continue=false, cost=cost,
    reason=reason}
end

--- Check whether a value is a valid status.
-- Status values have to be tables with a `status` attribute containing
-- one of the values `"inactive"`, `"running"`, `"succeeded"` or
-- `"failed"`, a numerical `cost` attribute and a `continue` attribute.
-- In addition, if the status is inactive or running the
-- `continue` attribute must be truthy, if the status is failed it must
-- be falsy.  If status is succeeded the `continue` flag indicates
-- whether the node can continue in order to try to improve its result.
-- @param value The value to be checked.
-- @return A Boolean indicating whether `value` is a valid status.
function xbt.is_status (value)
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

-- Predicates that check in which state a node
-- (or rather a status returned by evaluating a node) is.

--- Check whether `status` is inactive.
-- @param status The status to be checked.
-- @return A Boolean indicatus whether `status` is inactive.
function xbt.is_inactive (status)
  return status.status == "inactive"
end

--- Check whether status is running.
-- @param status The status to be checked.
-- @return A Boolean indicatus whether `status` is running.
function xbt.is_running (status)
  return status.status == "running"
end

--- Check whether status is succeeded.
-- @param status The status to be checked.
-- @return A Boolean indicatus whether `status` is succeeded.
function xbt.is_succeeded (status)
  return status.status == "succeeded"
end

---Check whether status is failed.
-- @param status The status to be checked.
-- @return A Boolean indicatus whether `status` is failed.
function xbt.is_failed (status)
  return status.status == "failed"
end

--- Make a state or update a table to become a state.
-- States can be arbitrary table, but they have to contain certain
-- attributes:
--
-- * a `blackboard` for use by the nodes
--
-- * `node_status`, a table mapping paths to the corresponding
--   status values.
--
-- * `improve`, a Boolean flag that indicates whether the nodes
--   that can improve their values should restart the computation
--   or return their previous values.
--
-- `make_state` takes a table and adds these attributes if necessry.
-- It can also be called without argument (or with a falsy value)
-- to generate a new state.
-- @param table Either falsy in which case a new state is created
--  or a table, in which case the missing fields are added.
-- @return a state
function xbt.make_state (table)
  if not table then
    table = {}
  end
  if type(table) == "table" then
    util.maybe_add(table, "blackboard")
    util.maybe_add(table, "node_status")
    util.maybe_add(table, "improve", false)
    return table
  else
    error("Argument to make_state is not a table.")
  end
end

--- Return the status of a node during the evaluation of an 
-- XBT.
-- @param node The node whose status we are checking.
-- @param state The state of the evaluation.
-- @param path A path to the instance of the node.

--- Evaluator for ticking nodes.
-- Ticking is the fundamental operation that triggers
-- evaluation of nodes.  To make the node types extensible
-- we look up the ticking function in the table `evaluators`.
xbt.evaluators = {}

--- The default cost for failures.
xbt.default_failure_cost = -1

--- Trigger evaluation of a node.
-- A tick triggers the evaluation of an XBT.  Each leaf node
--  should perform a small amount of computation when ticked
--  and then return a status to its parent.  Long-running
--  computations repeatedly return a `running` status until
--  they either successfully complete with status `succeeded`
--  or the fail with `failed`.
--  
--  In this implementation XBTs are not instanced, i.e., an
--  XBT holds no information about its evaluation.  Therefore
--  each XBT may be reused multiple times during an evaluation
--  (e.g., by call nodes or by structurally sharing structure
--  between nodes in the XBT so that the tree becomes a DAG).
--  
--  The function `tick` manages the evaluation state of the
--  XBT in the `state` that is passed along the tree during
--  evaluation.  To cope with multiple occurrences of the same
--  subtree during the evaluation, we pass along a path from
--  the root of the XBT to the node's location so that we can
--  distinguish multiple occurrences of the same node.
--  
--  @param node The node to be ticked.
--  @param state The current state of the XBT's evaluation.
--  @param path The path to `node`.
--  @return The status of the evaluation of the subtree below
--   `node`.
function xbt.tick (node, state, path)
  state = xbt.make_state(state)
  path = path or util.path.new()
  assert(util.is_path(p), tostring(path) .. " is not a path.")
  local node_type = node.xbt_node_type
  assert(node_type, tostring(node) .. " has no xbt_node_type.")
  local e = xbt.evaluators[node_type]
  assert(e, "No evaluator for node type " .. node_type .. ".")
  local result
  result = e(node, state)
  assert(xbt.is_status(result),
    tostring(result) .. " is not a valid status.")
  state.node_status[path] = result
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
function xbt.is_done (node, state, path)
  local status = state.node_status[path]
  if status then
    return xbt.is_succeeded(status) or xbt.is_failed(status)
  else
    -- No status for `node` is available, i.e., node has never been
    -- ticked in `state`.
    return false
  end
end

--- Check whether a node can be ticked again, either to finish
-- an incomplete computation or to improve a previous result.
-- @param node The node to be ticked.
-- @param state The current state of the evaluation.
-- @param path The path to the position of `node` in the XBT.
-- @return A Boolean indicating whether ticking the node may
--  result in a different result than the one previously
--  obtained.
function xbt.can_continue (node, state, path)
  local status = state.node_status[path]
  -- This should be unnecessary since we should never store an invalid
  -- status in the `node_status` table.  But let's check just in case.
  assert(xbt.is_status(status),
    tostring(status) .. " is not a valid status.")
  if status then
    -- Since `status` is valid the `continue` attribute correctly represents
    -- whether we are done or not.
    return status.continue
  else
    -- No status for `node` is available, i.e., node has never been
    -- ticked in `state`.
    return false
  end
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
--  It is called with two arguments: a node and a state.  The state
--  always contains `blackboard`, `node_status` and `improve`
--  attributes.
function xbt.define_node_type(node_type, arg_names, evaluator)
  xbt[node_type] = function (...)
    local args = {...}
    local node = {xbt_node_type=node_type, id=util.uuid()}
    for i, arg_name in ipairs(arg_names) do
      node[arg_name] = args[i]
    end
    return node
  end
  xbt.evaluators[node_type] = evaluator
end

--- Compute the descendants of a node. 
-- This assumes that composite nodes define an attribute `children`
-- that evaluates to a list of all children.  The resulting list
-- depends only on the structure of the tree, therefore this function
-- stores it in the attribute  `descendants` of `node` to avoid
-- recomputing it in every evaluation.
-- @param node the node whose descendants will be computed
-- @return A list of descendants of `node`.
function xbt.descendants (node)
  if node.descendants then
    return node.descendants
  end
  local result = {}
  if node.children then
    for i,child in pairs(node.children) do
      result[#result+1] = child.id
      util.append(result, xbt.descendants(child))
    end
    node.descendants = result
    return result
  else
    node.descendants = {}
    return {}
  end
end

-- TODO: Store whether the children of a node are inactive
-- in the state so that we don't repeatedly deactivate subrees.
-- TODO: Use path instead of ID to index `node_status`
--- Set all descendants of a node to status `inactive`.
function xbt.deactivate_descendants (node, state, path)
  for _, cid in pairs(xbt.descendants(node)) do
    state.node_status[cid] = xbt.inactive()
  end
end

-- We often want to serialize XBTs.  To make this more convenient
-- we allow functions appearing in leaf nodes to be specified as
-- strings, in which case we look up the function value in
-- `xbt.actions`.
xbt.actions = {};

function xbt.define_function_name (name, fun)
  if type(name) ~= "string" then
    error("Action name must be a string.")
  end
  xbt.actions[name] = fun
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
    local result = xbt.actions[f]
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
-- The function has to return a valid status.

xbt.define_node_type("fun", {"fun"}, function (node, state)
  local fun = xbt.lookup_function(node.fun)
  local result = fun(state)
  if xbt.is_status(result) then
    return result
  else
    return xbt.failed(xbt.default_failure_cost,
      "Function didn't return a status")
  end
end)

-- Action nodes are similar to functions, but they wrap the return
-- value of the function into a success status.
xbt.define_node_type("action", {"fun"}, function (node, state)
  local fun = xbt.lookup_function(node.fun)
  return xbt.succeeded(fun(state))
end)

-- The tick function for sequence nodes
local function tick_seq_node (node, state)
  -- If `node` has already returned a status indicating that it
  -- cannot continue in `state` then return the previous result.
  if xbt.is_done(node, state) then
    return xbt.result(node, state)
  end
  local sum = 0
  local status
  for _, child in pairs(node.children) do
    status = xbt.tick(child, state)
    if xbt.is_failed(status) then
      -- A child node has failed, which means that the sequence
      -- node is failed as well and cannot continue.  Prepare
      -- for the next activation before returning the failed
      -- status.
      xbt.deactivate_descendants(node)
      return status
    end
    if xbt.is_running(status) then
      return status
    end
    assert(xbt.is_succeeded(status),
      "Evaluation of seq-node child returned " ..
      tostring(status))
    -- TODO: Need more general handling of result values
    sum = sum + status.value
  end
  -- We have ticked all children with a successful result
  -- Reset the children's results to inactive
  xbt.deactivate_descendants(node)
  return xbt.succeeded(sum)
end

-- Sequence ("seq") nodes evaluate their children sequentially
-- and fail as soon as one of their children fails.
xbt.define_node_type("seq", {"children"}, tick_seq_node)

local function tick_choice_node (node, state)
  -- If `node` has already returned a status indicating that it
  -- cannot continue in `state` then return the previous result.
  if xbt.is_done(node, state) then
    return xbt.result(node, state)
  end
  local sum = 0
  local status
  for _, child in pairs(node.children) do
    status = xbt.tick(child, state)
    if xbt.is_succeeded(status) then
      -- We have succeeded; reset the children before
      -- returning
      xbt.deactivate_descendants(node)
      return xbt.succeeded(status.value + sum)
    end
    if xbt.is_running(status) then
      return status
    end
    assert(xbt.is_failed(status),
      "Evaluation of choice node returned " .. tostring(status))
    -- TODO: Need more general handling of result values
    sum = sum + status.value
  end
  -- We have ticked all children with a successful result
  -- Reset the children's results to inactive
  xbt.deactivate_descendants(node)
  return xbt.failed(sum, "All children failed")
end

-- Choice nodes evaluate their children sequentially and
-- succeed as soon as one of their children succeeds.
xbt.define_node_type("choice", {"children"}, tick_choice_node)

return xbt
