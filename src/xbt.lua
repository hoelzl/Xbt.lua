--- Extended Behavior Trees in Lua(JIT).
-- @copyright © 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.

-- See the [readme file](README.md) for documentation (well, not yet).

local util = require("util")

local xbt = {}

--- Result Types.
-- 
-- A node can either be inactive, running, succeeded or failed.  We
-- define functions that return tables correspondig to these XBT
-- result types.  These tables share several attributes: The Boolean
-- `continue` attribute indicates whether a process can continue.
-- Inactive and running processes can always continue; failed
-- processes never can.  Succeeded processes may set this flag to true
-- if, given more time, they can improve the value they have
-- previously returned.  Each XBT result carries a `cost` attribute
-- that indicates the execution cost for the evaluation of the subtree
-- that produces the result.  Succeeded nodes additionally contain a
-- `value` attribute The difference between `cost` and `value` is that
-- _every_ evaluation result has a cost but that only successful
-- results carry a value.  Running node return the cost accumulated so
-- far; their parents could use this to abort them if the accumulated
-- cost is too high.
-- 
-- @section Result-Types

--- Create an XBT result value for inactive nodes.
-- @param cost The cost of executing the node (including all
--  descendants).  Default is `0`.
-- @return An XBT result indicating that `node` is inactive.
function xbt.inactive (cost)
  if cost == nil then cost = 0 end
  return {status="inactive", continue=true, cost=cost}
end

--- Create an XBT result value for running nodes.
-- @param cost The cost of executing the node (including all
--  descendants).  Default is `0`.
-- @return An XBT result indicating that the node is running.
function xbt.running (cost)
  if cost == nil then cost = 0 end
  return {status="running", continue=true, cost=cost}
end

--- Create an XBT result value for successful nodes.
-- @param cost The cost of executing the node (including all
--  descendants).  Default is `0`.
-- @param value The value that was obtained by the node.  Default is
--  `nil`.
-- @param continue Boolean indicating whether `value` can be improved
--  by further computation.  Default is `false`.
-- @return An XBT result indicating that the node has completed
--  successfully
function xbt.succeeded (cost, value, continue)
  if cost == nil then cost = 0 end
  continue = continue or false
  return {status="succeeded", continue=continue, cost=cost,
    value=value}
end

--- Create an XBT result value for failed nodes.
-- @param cost The cost of executing the node (including all
--  descendants).  Default is `0`.
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
-- `"failed"`, a numerical `cost` attribute and a `continue`
-- attribute.  If the result is inactive or running the `continue`
-- attribute must be truthy, if the result is failed it must be falsy.
-- If result has status `"succeeded"` the `continue` flag indicates
-- whether the node can continue in order to try to improve its
-- result.
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

-- Predicates that check the status of a node (or rather of the result
-- returned by evaluating a node).

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


--- Check whether a node needs to be ticked again.
-- The function `is_done` returns `true` if `result` indicates that
-- node has already reached a state that allows the computation to
-- progress (even if the node could still be improved).
-- @param result The result to be checked.
-- @return `true` if the result's status is either `succeeded` or
--  `failed`, `false` otherwise.
function xbt.is_done (result)
  return xbt.is_succeeded(result) or xbt.is_failed(result)
end

--- Check whether a node can be ticked again.
-- In contrast to `is_done` this function returns `true` whenever the
-- node can continue executing, either to finish an incomplete
-- computation or to improve a previous result.
-- @param result The result to be checked.
-- @return A Boolean indicating whether ticking the node may result in
--  a different result than the one previously obtained.
function xbt.can_continue (result)
  return result.continue
end

--- State.
-- 
-- XBTs are passed a `state` object when they are evaluated.
-- 
-- @section State

--- Make a new state, or update a table to become a state.
-- Any table can be used as state (there is no need to have a
-- particular metatable), but it has to contain certain attributes:
--
-- * a `blackboard` for use by the nodes
--
-- * `node_results`, a table mapping paths to the corresponding result
--   values.
-- 
-- * `local_data`, a table for storing local data that node want to
--   persist between ticks.
--
-- * `improve`, a Boolean flag that indicates whether nodes that can
--   improve their values should restart the computation or return
--   their previous values.
--
-- `make_state` takes a table and adds these attributes if necessry.
-- It can also be called without argument (or with a falsy value) to
-- generate a new state.
-- 
-- @param table Either falsy in which case a new state is created or a
--  table, in which case the missing fields are added.
-- @return A state.
function xbt.make_state (table)
  if not table then
    table = {}
  end
  if type(table) == "table" then
    util.maybe_add(table, "blackboard")
    util.maybe_add(table, "node_results")
    util.maybe_add(table, "local_data")
    util.maybe_add(table, "improve", false)
    return table
  else
    error("Argument to make_state is not a table.")
  end
end

--- Store local data for a node instance.
-- Save `data` in state so that it persists during ticks.  It can be
-- read with `local_data` and is deleted by `deactivate_node`.
-- @param node The node for which we are storing data.
-- @param path A path identifying the instance of the node.
-- @param state The current state of the evaluation.
-- @param data The data we want to persist.  Any old data stored for
--  this instance is overwritten.
function xbt.set_local_data (node, path, state, data)
  state.local_data[tostring(path)] = data
end

--- Retreive local data for a node instance.
-- Retreive data that was previously stored using `set_local_data` or
-- return the default value if no previously stored value is
-- available.
-- @param node The node for which we are retreiving data.
-- @param path A path identifying the instance of the node.
-- @param state The current state of the evaluation.
-- @param default The value returned if no data is available.
-- @return The previously stored data or `default`.
function xbt.local_data (node, path, state, default)
  return state.local_data[tostring(path)] or default
end

--- Set the evaluation result for a node.
-- This is mostly useful for the `tick` function and for evaluators
-- that can improve their results.
-- @param node The node that was evaluated.
-- @param path A path identifying the instance of the node.
-- @param state The current state of the evaluation.
-- @param result The new evaluation result for `node`.
-- @return The new evaluation result for `node`, i.e., `result`.  
function xbt.set_result(node, path, state, result)
  assert(xbt.is_result(result),
    tostring(result) .. " is not a valid XBT result.")
  state.node_results[tostring(path)] = result
  return result
end

--- Get the previous evaluation result for a node.
-- This is mostly useful for the `tick` function and for evaluators
-- that can improve previous results.
-- @param node The node to evaluate.
-- @param path A path identifying the instance of the node.
-- @param state The current state of the evaluation.
-- @return The result of the previous evaluation of `node`.  If node
--  was not previously evaluated, an `inactive` result is returned.
function xbt.result(node, path, state)
  local res = state.node_results[tostring(path)]
  if not res then
    res = xbt.inactive()
    xbt.set_result(node, path, state, res)
  end
  assert(xbt.is_result(res),
    tostring(res) .. " is not a valid XBT result.")
  return res
end

--- Evaluation and Compilation.
-- 
-- The following functions are concerned with evaluating nodes or
-- compiling XBTs into a for that can be integrated into other systems
-- (currently no compilers are available).
-- 
-- @section Evaluation

--- Evaluators for ticking nodes.
-- Ticking is the fundamental operation that triggers evaluation of
-- nodes.  To make the node types extensible we look up the ticking
-- function in the table `evaluators` using the `xbt_node_type` as
-- key.  Each ticking function receives three arguments: the node that
-- is ticked, the path to the node from the root of the XBT to
-- uniquely identify the node instance, and the state of the
-- evaluation.
xbt.evaluators = {}

--- Compilers for XBTs.
-- To achieve greater performance (or to integrate XBTs into existing
-- systems) it may be necessary to compile the XBT into a
-- representation that can be executed by the target system.  This
-- table maps each node type to a table that in turn maps backend
-- names to a compiler for the given node type and backend.
xbt.compilers = {}

--- The default cost for failures.
xbt.default_failure_cost = -1

--- Trigger evaluation of a node.
-- A tick triggers the evaluation of an XBT.  Each leaf node should
-- perform a small amount of computation when ticked and then return
-- an XBT result to its parent.  Long-running computations repeatedly
-- return a `running` result until they either successfully complete
-- with result `succeeded` or fail with `failed`.
--  
-- In this implementation XBTs are not instanced, i.e., an XBT holds
-- no information about its evaluation.  Therefore each XBT may be
-- reused multiple times during an evaluation (e.g., by call nodes or
-- by structural sharing between nodes in the XBT so that the tree
-- becomes a DAG).
-- 
-- The function `tick` manages the evaluation state of the XBT.  Each
-- node is uniquely identified by its path in the tree which is passed
-- as second argument.  The `state` passed as third argument contains
-- the state of the XBTs evaluation and methods to perform all actions
-- that leaf nodes may trigger in the environment.
--  
-- @param node The node to be ticked.
-- @param path The path to `node`.
-- @param state The current state of the XBT's evaluation.
-- @return The result of the evaluation of the subtree below `node`.
function xbt.tick (node, path, state)
  state = xbt.make_state(state)
  path = path or util.path.new()
  assert(util.path.is_path(path), tostring(path) .. " is not a path.")
  local node_type = node.xbt_node_type
  assert(node_type, tostring(node) .. " has no xbt_node_type.")
  util.debug_print("xbt.tick: node " .. node.id ..
    " of type " .. node_type .. "\t path=" .. tostring(path))
  
  local prev_result = xbt.result(node, path, state)
  local improving = xbt.can_continue(prev_result) and state.improve
  if xbt.is_done(prev_result) and not improving then return prev_result end
  local e = xbt.evaluators[node_type]
  assert(e, "No evaluator for node type " .. node_type .. ".")
  
  local result = e(node, path, state)
  xbt.set_result(node,path,state,result)
  return result
end

--- Define an evaluation function and a constructor for node type `nt`.
-- @param nt The node type that will be stored as `xbt_node_type` in
--  all instances.
-- @param arg_names The names under which the arguments to the
--  constructor are stored in the resulting node.  For example, if
--  `nt` is `"foo"` and `arg_names` is `{"bar", "baz"}`,
--  `define_node_type` will define a function `foo` that takes two
--  arguments `arg1` and `arg2` and returns a table
--  `{xbt_node_type="foo", bar=arg1, baz=arg2, id=...}`.  Composite
--  nodes must have an argument named `children`.
-- @param evaluator An evaluator function for this node type.  It is
--  called with three arguments: a node, a path and a state.  The
--  state always contains `blackboard`, `node_results` and `improve`
--  attributes.
-- @param compilers If provided the argument is a table mapping
--  backend names to functions that can compile the XBT for that type
--  of backend.  Default is `{}`.
function xbt.define_node_type (nt, arg_names, evaluator, compilers)
  xbt[nt] = function (...)
    local args = {...}
    local node = {xbt_node_type=nt, id=util.uuid()}
    for i, arg_name in ipairs(arg_names) do
      node[arg_name] = args[i]
    end
    return node
  end
  xbt.evaluators[nt] = evaluator
  xbt.compilers[nt] = compilers or {}
end

--- Set all descendants of a node to result status `inactive`.
-- The desendants of an inactive node all have to be inactive as well,
-- so we don't recurse into inactive children.  However, since
-- planning or learning nodes might reorder their children dynamically
-- we cannot be sure that the right siblings of an inactive child are
-- also inactive; therefore we always process the complete list of
-- children.
-- @param node The node whose descendants we are deactivating.
-- @param path The path to `node` in the XBT.
-- @param state The state of the XBT's evaluation.
function xbt.deactivate_descendants (node, path, state)
  if not node.children then return end
  for i, child in pairs(node.children) do
    local child_path = path:copy(i)
    local child_result = xbt.result(child, child_path, state)
    if not xbt.is_inactive(child_result) then
      xbt.set_result(child, child_path, state, xbt.inactive())
      xbt.deactivate_descendants(child, child_path, state)
    end
  end
end

--- Deactivate a node.
-- Set all descendants of a node to status `inactive` and clear any
-- data the node might have stored under its path.
-- @param node The node whose descendants we are deactivating.
-- @param path The path to `node` in the XBT.
-- @param state The state of the XBT's evaluation.
function xbt.deactivate_node (node, path, state)
  xbt.deactivate_descendants(node, path, state)
  xbt.set_local_data(node, path, state, nil)
end


--- A table mapping function names to functions.
-- Function and action nodes use this table to look up their `fun`
-- attributes.
-- 
xbt.functions = {};

--- Define a name for a function or action.
-- We often want to serialize XBTs.  To make this more convenient we
-- allow functions appearing in leaf nodes to be specified as strings,
-- in which case we look up the function value in `xbt.functions`.
-- @param name The name with which the function can be accessed in
--  `fun` nodes.
-- @param fun The function.
function xbt.define_function_name (name, fun)
  if type(name) ~= "string" then
    error("Function or action name must be a string.")
  end
  xbt.functions[name] = fun
end

--- Look up a function or action given its name.
-- @param f A function or the name of a function defined using
--  `define_function_name`.
-- @return If `f` is a string, use it as key in the `xbt.functions`
--  table and return the value found.  Throw an error if no definition
--  for `f` exists.  Otherwise just return `f`.
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

--- Node Types.
-- 
-- An XBT node is represented by a table containing an `xbt_node_type`
-- attribute.  Nodes can either be composite (have child nodes) or
-- atomic (encapsulate a function or coroutine).  Each node has a
-- unique ID.
-- 
-- @section Node-Types

--- Generate a function node.
-- Function ("fun") nodes encapsulate a function.  The function is
-- called with the node, the path and a state as argument sand has to
-- return a valid XBT result.  The node and path are mainly useful if
-- the function has to store local information in the state.  If the
-- information is for all occurences of the function then `node` can
-- be used as key; if it is just for this occurrence of the function
-- then `tostring(path)` can be used.  Note that `path` itself is not
-- a useful key, since there is no guarantee that different
-- invocations of the function at the same position will receive
-- identical paths.  The paths are guaranteed to be `==`, however.
-- @function fun
-- @param fun A function invoked with `node`, `path` and `state` as
--  arguments.  It performs the work of this node.
-- @param args The "arguments" for the `fun` parameter.  They are
--  stored as `node.args` so that they can be accessed by the `fun`
--  parameter when it is executing.  These arguments are the same for
--  all invocations of the node, since they are stored in the node
--  itself, not in the path.
--  @return An function node.  This node is serializable if the `fun`
--   and `args` arguments are serializable.  Typically this is the
--   case if `fun` is a string that references a function defined with
--  `define_function_name`.
xbt.define_node_type("fun", {"fun", "args"}, function (node, path, state)
    local fun = xbt.lookup_function(node.fun)
    local result = fun(node, path, state)
    assert(xbt.is_result(result),
      "Function didn't return a valid result.")
    return result
  end)

-- TODO: Maybe actions should fail when `fun` throws an exception?

--- Generate an action node.
-- Action nodes are similar to functions, but they wrap the return
-- value of the function into a XBT result that indicates that the
-- function has succeeded and contains the return value of the
-- function as value.  The cost of the call has to be provided as
-- `args.cost` when the node is created; it is the same for all
-- invocations of this node.  Actions should not modify the 
-- `node.args.cost` value to return different costs; functions that
-- need to return different costs for different invocations should not
-- be defined as action nodes but rather as `fun` nodes.
-- @function action
-- @param fun A function invoked with `node`, `path` and `state` as
--  arguments.  It performs the work of this node.
-- @param args The "arguments" for the `fun` parameter.  They are
--  stored as `node.args` so that they can be accessed by the `fun`
--  parameter when it is executing.  These arguments are the same for
--  all invocations of the node, since they are stored in the node
--  itself, not in the path.
-- @return An action node.  This node is serializable if the `fun` and
--  `args` arguments are serializable.  Typically this is the case if
--  `fun` is a string that references a function defined with
--  `define_function_name`.
xbt.define_node_type("action", {"fun", "args"}, function (node, path, state)
  local fun = xbt.lookup_function(node.fun)
  local cost = node.args.cost or 0
  return xbt.succeeded(cost, fun(node, path, state))
end)

-- The tick function for sequence nodes
local function tick_seq_node (node, path, state)
   -- Cost and value for this node
  local cost = 0
  local value = 0
  for pos, child in pairs(node.children) do
    local p = path:copy(pos)
    local result = xbt.tick(child, p, state)
    -- Update the total accumulated cost/value
    cost = cost + result.cost
    value = value + (result.value or 0)
    if xbt.is_failed(result) then
      -- A child node has failed, which means that the sequence node
      -- is failed as well and cannot continue.  Prepare for the next
      -- activation before returning the failed result.
      xbt.deactivate_node(node, path, state)
      return xbt.failed(cost, "A child node failed")
    end
    if xbt.is_running(result) then
      return xbt.running(cost)
    end
    assert(xbt.is_succeeded(result),
      "Evaluation of seq-node child returned " .. tostring(result))
    -- No longer running, reset the runtime cost.
    xbt.set_local_data(node, path, state, nil)
  end
  xbt.deactivate_node(node, path, state)
  return xbt.succeeded(cost, value)
end

--- Generate a sequence node.
-- Sequence ("seq") nodes evaluate their children sequentially and
-- fail as soon as one of their children fails.
-- @function seq
-- @param children The child nodes of the node.
-- @return A sequence node.  This node is serializable if its children
--  are.
xbt.define_node_type("seq", {"children"}, tick_seq_node)

local function tick_choice_node (node, path, state)
  local cost = 0
  for pos,child in pairs(node.children) do
    local p = path:copy(pos)
    local result = xbt.tick(child, p, state)
    cost = cost + result.cost
    if xbt.is_succeeded(result) then
      xbt.deactivate_node(node, path, state)
      return xbt.succeeded(cost, result.value)
    end
    if xbt.is_running(result) then
      return xbt.running(cost)
    end
    assert(xbt.is_failed(result),
      "Evaluation of choice node returned " .. tostring(result))
  end
  xbt.deactivate_node(node, path, state)
  return xbt.failed(cost, "All children failed")
end

--- Generate a choice node.
-- Choice nodes evaluate their children sequentially and succeed as
-- soon as one of their children succeeds.
-- @function choice
-- @param children The child nodes of the node.
-- @return A choice node.  This node is serializable if its children
--  are.
xbt.define_node_type("choice", {"children"}, tick_choice_node)

local function tick_xchoice_node (node, path, state)
  local cost = 0
  local result = nil
  -- Don't reorder children whild the node is running.
  if not xbt.is_running(xbt.result(node, path, state)) then
    node.children = node.child_fun(node, path, state)
  end
  for pos,child in pairs(node.children) do
    local p = path:copy(pos)
    result = xbt.tick(child, p, state)
    cost = cost + result.cost
    if xbt.is_succeeded(result) then
      node.update_fun(node, path, state, result)
      xbt.deactivate_node(node, path, state)
      return xbt.succeeded(cost, result.value)
    end
    if xbt.is_running(result) then
      return xbt.running(cost)
    end
    assert(xbt.is_failed(result),
      "Evaluation of choice node returned " .. tostring(result))
  end
  node.update_fun(node, path, state, result)
  xbt.deactivate_node(node, path, state)
  return xbt.failed(cost, "All children failed")
end

--- Generate an external choice node.
-- External choice nodes call a function to determine the evaluation
-- order of their children and succeed as soon as one of their
-- children succeeds.  If this function removes nodes from the list
-- of children it has to deactivate them to free any resources the
-- children might retain.  The update_fun is called just before
-- deactivating the node when a successful or failed result has been
-- reached.  It receives the node, path and state as arguments, and
-- either the result of the evaluation if `child_fun` returned at
-- least one child, or `nil` otherwise.
-- @function xchoice
-- @param children The child nodes of the node.
-- @return An external choice node.  This node is serializable if its
--  children are.
xbt.define_node_type("xchoice",
  {"children", "child_fun", "update_fun", "data"},
  tick_xchoice_node)

--- Epsilon-greedy `child_fun` for `xchoice`.
-- Sort the children of a node and with probability `node.epsilon`
-- swap the first element of the result with another one.
-- The function to generate the sorted list of children is taken
-- from `node.data.sorted_children`.
-- @param node The xchoice node.
-- @param path Path that identifies the instance of the node
-- @param state The current state of the evaluation.
-- @return An epsilon-greedy result list of children.
function xbt.epsilon_greedy_child_fun (node, path, state)
  local children = node.data.sorted_children(node, path, state)
  if #children >= 2 and math.random < node.epsilon then
    local temp = math.random(2, #children)
    children[1],children[temp] = children[temp],children[1]
  end
  return children
end

return xbt
