--- Extended Behavior Trees in Lua(JIT).
-- @copyright © 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.
-- @module xbt

-- See the [readme file](README.md) for documentation (well, not yet).

local util = require("xbt.util")
local xbt_path = require("xbt.path")

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
-- previously returned.  Each XBT result carries a `reward` attribute
-- that indicates the execution reward for the evaluation of the subtree
-- that produces the result.
-- 
-- @section Result-Types

--- Create an XBT result value for inactive nodes.
-- @param reward The reward for executing the node (including all
--  descendants).  Default is `0`.
-- @return An XBT result indicating that `node` is inactive.
function xbt.inactive (reward)
  reward = reward or 0
  return {status="inactive", continue=true, reward=reward}
end

--- Create an XBT result value for running nodes.
-- @param reward The reward for executing the node (including all
--  descendants).  Default is `0`.
-- @return An XBT result indicating that the node is running.
function xbt.running (reward)
  reward = reward or 0
  return {status="running", continue=true, reward=reward}
end

--- Create an XBT result value for successful nodes.
-- @param reward The reward for executing the node (including all
--  descendants).  Default is `0`.
-- @param continue Boolean indicating whether `reward` can be improved
--  by further computation.  Default is `false`.
-- @return An XBT result indicating that the node has completed
--  successfully
function xbt.succeeded (reward, continue)
  reward = reward or 0
  continue = continue or false
  return {status="succeeded", continue=continue, reward=reward}
end

--- Create an XBT result value for failed nodes.
-- @param reward The reward of executing the node (including all
--  descendants).  Default is `0`.
-- @param reason A string describing the reason why the computation
--  failed.  Default is `nil`.
-- @return An XBT result indicating that the node has failed.
function xbt.failed (reward, reason)
  reward = reward or 0
  return {status="failed", continue=false, reward=reward,
    reason=reason}
end

--- Check whether a value is a valid result.
-- XBT results values are tables with a `status` attribute containing
-- one of the values `"inactive"`, `"running"`, `"succeeded"` or
-- `"failed"`, a numerical `reward` attribute and a `continue`
-- attribute.  If the result is inactive or running the `continue`
-- attribute must be truthy, if the result is failed it must be falsy.
-- If result has status `"succeeded"` the `continue` flag indicates
-- whether the node can continue in order to try to improve its
-- result.
-- @param value The value to be checked.
-- @return A Boolean indicating whether `value` is a valid result.
function xbt.is_result (value)
  if type(value) == "table" then
    if type(value.reward) ~= "number" then return false end
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
-- * `node_results`, a table mapping paths to the corresponding XBT
--   results.
-- 
-- * `local_data`, a table for storing local data that nodes want to
--   persist between ticks.  This data is cleared when nodes are
--   deactivated, so data that should persist between runs of the
--   XBT should be stored in the blackboard.
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
-- @param node The node for which we are storing data.  Ignored by
--  the body, so it can be `nil` if local data is stored before a
--  node is available.
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
-- @param node The node for which we are retreiving data.  Ignored by
--  the body, so it can be `nil` if the node for path is not known.
-- @param path A path identifying the instance of the node.
-- @param state The current state of the evaluation.
-- @param default The value returned if no data is available.  Default
--  is {}
-- @return The previously stored data or `default`.
function xbt.local_data (node, path, state, default)
  local data = state.local_data[tostring(path)]
  if not data then
    default = default or {}
    xbt.set_local_data(node, path, state, data)
  end
  return data or default
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
  assert(xbt.is_result(result), "Not a valid XBT result.")
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
  assert(xbt.is_result(res), "Not a valid XBT result.")
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

--- The default reward for failures.
xbt.default_failure_reward = -1

-- TODO: Don't store the result for nodes marked as `transient`.
-- This will allow certain predicates to be triggered at every
-- tick.

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
  path = path or xbt_path.new()
  assert(xbt_path.is_path(path), "Not a path.")
  local node_type = node.xbt_node_type
  assert(node_type, "Node has no xbt_node_type.")
  --[[--
  util.debug_print("xbt.tick: node " .. node.id ..
    " of type " .. node_type .. "\t path=" .. tostring(path))
  --]]--
  local prev_result = xbt.result(node, path, state)
  local improving = xbt.can_continue(prev_result) and state.improve
  if xbt.is_done(prev_result) and not improving then return prev_result end
  local e = xbt.evaluators[node_type]
  assert(e, "No evaluator for node type.")
  
  local result = e(node, path, state)
  xbt.set_result(node, path, state, result)
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
      xbt.set_local_data(child, child_path, state, nil)
      xbt.deactivate_descendants(child, child_path, state)
    end
  end
end

--- Deactivate a node.
-- Set all descendants of a node to status `inactive` and clear any
-- data the node might have stored under its path, but keep the
-- current result status of the node in `state`.
-- @param node The node whose descendants we are deactivating.
-- @param path The path to `node` in the XBT.
-- @param state The state of the XBT's evaluation.
-- @param clear_data If true, the local data for the path is deleted,
--  otherwise it is kept
function xbt.deactivate_node (node, path, state, clear_data)
  if clear_data == nil then clear_data = true end
  xbt.deactivate_descendants(node, path, state)
  if clear_data then
    xbt.set_local_data(node, path, state, nil)
  end
end

--- Reset a node to inactive status.
-- Set the node and all of its descendants to status `inactive` and
-- clear any data the node might have stored under its path.
-- @param node The node whose descendants we are deactivating.
-- @param path The path to `node` in the XBT.
-- @param state The state of the XBT's evaluation.
-- @param clear_data If true, the local data for the path is deleted,
--  otherwise it is kept
function xbt.reset_node (node, path, state, clear_data)
  if clear_data == nil then clear_data = true end
  xbt.deactivate_node(node, path, state, clear_data)
  xbt.set_result(node, path, state, xbt.inactive())
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
-- called with the node, the path and a state as arguments and has to
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
-- function as reward.
-- @function action
-- @param fun A function invoked with `node`, `path` and `state` as
--  arguments.  It performs the work of this node and returns a number
--  that is returned as the result of the action.
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
  local args = node.args
  local reward = args and args.reward or 0
  assert(type(reward) == "number", "Action result not a number.")
  local res = fun(node, path, state)
  return xbt.succeeded(res)
end)

--- Generate a node that wraps a Boolean result.
-- Boolean nodes are specialized function nodes that return either
-- `failed` or `succeeded`, depending on whether the encapsulated
-- function returns a truthy or falsy value.  The reward of the call
-- has to be provided as `args.reward` when the node is created; it is
-- the same for all invocations of this node.  The evaluated function
-- should not modify the `node.args.reward` value to return different
-- rewards; functions that need to return different rewards for different
-- invocations should instead be defined as `fun` nodes.
-- @function bool
-- @param fun A function invoked with `node`, `path` and `state` as
--  arguments.  It performs the work of this node.
-- @param args The "arguments" for the `fun` parameter.  They are
--  stored as `node.args` so that they can be accessed by the `fun`
--  parameter when it is executing.  These arguments are the same for
--  all invocations of the node, since they are stored in the node
--  itself, not in the path.
-- @return A Boolean node.  This node is serializable if the `fun` and
--  `args` arguments are serializable.  Typically this is the case if
--  `fun` is a string that references a function defined with
--  `define_function_name`.
xbt.define_node_type("bool", {"fun", "args"}, function (node, path, state)
  local fun = xbt.lookup_function(node.fun)
  local reward = node.args and node.args.reward or 0
  local result = fun(node, path, state)
  if result then
    return xbt.succeeded(reward)
  else
    return xbt.failed(reward)
  end
end)

-- The tick function for sequence nodes
local function tick_seq_node (node, path, state)
   -- reward and value for this node
  local reward = 0
  local children = node.children or {}
  for pos, child in pairs(children) do
    local p = path:copy(pos)
    local result = xbt.tick(child, p, state)
    -- Update the total accumulated reward/value
    reward = reward + result.reward
    if xbt.is_failed(result) then
      -- A child node has failed, which means that the sequence node
      -- is failed as well and cannot continue.  Prepare for the next
      -- activation before returning the failed result.
      xbt.deactivate_node(node, path, state)
      return xbt.failed(reward, "A child node failed")
    end
    if xbt.is_running(result) then
      return xbt.running(reward)
    end
    assert(xbt.is_succeeded(result),
      "Evaluation of seq-node child returned bad result.")
  end
  xbt.deactivate_node(node, path, state)
  return xbt.succeeded(reward)
end

--- Generate a sequence node.
-- Sequence ("seq") nodes evaluate their children sequentially and
-- fail as soon as one of their children fails.
-- @function seq
-- @param children The child nodes of the node.
-- @return A sequence node.  This node is serializable if its children
--  are.
xbt.define_node_type("seq", {"children"}, tick_seq_node)

-- The tick function for all-sequence nodes
local function tick_all_node (node, path, state)
   -- reward and value for this node
  local reward = 0
  local children = node.children or {}
  for pos, child in pairs(children) do
    local p = path:copy(pos)
    local result = xbt.tick(child, p, state)
    -- Update the total accumulated reward/value
    reward = reward + result.reward
    if xbt.is_running(result) then
      return xbt.running(reward)
    end
  end
  xbt.deactivate_node(node, path, state)
  -- TODO: Maybe return the result status of the last node?
  return xbt.succeeded(reward)
end

--- Generate an all-sequence node.
-- All-sequence ("all") nodes evaluate their children sequentially.
-- They always evaluate all of their children and return success, no
-- matter whether their children succeed or fail.
-- @function all
-- @param children The child nodes of the node.
-- @return An all-sequence node.  This node is serializable if its children
--  are.
xbt.define_node_type("all", {"children"}, tick_all_node)

local function tick_choice_node (node, path, state)
  local reward = 0
  local children = node.children or {}
  for pos,child in pairs(children) do
    local p = path:copy(pos)
    local result = xbt.tick(child, p, state)
    reward = reward + result.reward
    if xbt.is_succeeded(result) then
      xbt.deactivate_node(node, path, state)
      return xbt.succeeded(reward, result.value)
    end
    if xbt.is_running(result) then
      return xbt.running(reward)
    end
    assert(xbt.is_failed(result),
      "Evaluation of choice node returned bad result.")
  end
  xbt.deactivate_node(node, path, state)
  return xbt.failed(reward, "All children failed")
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
  local reward = 0
  local result = nil
  local child_fun = xbt.lookup_function(node.child_fun)
  -- Don't reorder children whild the node is running.
  if not xbt.is_running(xbt.result(node, path, state)) then
    node.children = child_fun(node, path, state)
  end
  local update_fun = xbt.lookup_function(node.args.update_fun) or
    function () end
  for pos,child in pairs(node.children) do
    local p = path:copy(pos)
    result = xbt.tick(child, p, state)
    reward = reward + result.reward
    if xbt.is_succeeded(result) then
      update_fun(node, path, state, result)
      xbt.deactivate_node(node, path, state)
      return xbt.succeeded(reward, result.value)
    end
    if xbt.is_running(result) then
      return xbt.running(reward)
    end
    assert(xbt.is_failed(result),
      "Evaluation of choice node returned bad result.")
  end
  update_fun(node, path, state, result)
  xbt.deactivate_node(node, path, state)
  return xbt.failed(reward, "All children failed")
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
  {"children", "child_fun", "args"},
  tick_xchoice_node)

--- Epsilon-greedy `child_fun` for `xchoice`.
-- Sort the children of a node and with probability `state.epsilon`
-- or `node.args.epsilon` swap the first element of the result with
-- another one.  The function to generate the sorted list of children
-- is taken from `node.args.sorted_children`.
-- @param node The xchoice node.
-- @param path Path that identifies the instance of the node
-- @param state The current state of the evaluation.
-- @return An epsilon-greedy result list of children.
function xbt.epsilon_greedy_child_fun (node, path, state)
  local children = node.args.sorted_children(node, path, state)
  local r = util.rng:sample()
  local swap = r < (state.epsilon or node.args.epsilon or 0.25)
  if #children >= 2 and swap then
    -- print("Performing epsilon transition.")
    local temp = util.random(2, #children)
    children[1],children[temp] = children[temp],children[1]
  end
  return children
end

-- TODO: Provide a timeout
local function tick_suppress_failure (node, path, state)
  assert(node.child, "Suppress_failure node needs a child node.")
  local child_result = xbt.tick(node.child, path, state)
  if xbt.is_failed(child_result) then
    return xbt.running(child_result.reward)
  else
    return child_result
  end
end

xbt.define_node_type("suppress_failure", {"child"}, tick_suppress_failure)

local function tick_negate (node, path, state)
  assert(node.child, "Negate node needs a child node.")
  local child_result = xbt.tick(node.child, path, state)
  if xbt.is_failed(child_result) then
    local args = node.args
    return xbt.succeeded(child_result.reward)
  elseif xbt.is_succeeded(child_result) then
    return xbt.failed(child_result.reward, "Child node succeeded.")
  else
    return child_result
  end
end

xbt.define_node_type("negate", {"child", "args"}, tick_negate)


-- TODO: Provide a timeout
local function tick_until (node, path, state)
  assert(node.pred, "Until node needs a predicate.")
  assert(node.child, "Until node needs a child node.")
  local pred = xbt.lookup_function(node.pred)
  if pred(node, path, state) then
    return xbt.succeeded(node.args.default_reward or 0)
  end
  local result = xbt.tick(node.child, path, state)
  if pred(node, path, state) then
    return result
  else
    return xbt.running(result.reward)
  end
end

xbt.define_node_type("until", {"pred", "child", "args"}, tick_until)

local function tick_when (node, path, state)
  assert(node.pred, "When node needs a predicate.")
  assert(node.child, "When node needs a child node.")
  local pred = xbt.lookup_function(node.pred)
  if pred(node, path, state) then
    return xbt.tick(node.child, path, state) 
  else
    return xbt.failed(0)
  end
end

xbt.define_node_type("when", {"pred", "child"}, tick_when)

return xbt
