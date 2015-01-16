-- xbt.lua
-- Extended Behavior Trees in Lua.
-- Copyright © 2015, Matthias Hölzl
-- Licensed under the MIT license, see the file LICENSE.md.

-- See the [readme file](README.md) for documentation (well, not yet).

local util = require("util")

local xbt = {}

-- A node can either be inactive, running, succeeded or failed.
-- We define functions that return the correspondig status as
-- tables.  The continue flag indicates whether a process can
-- continue.  Inactive and running processes can always continue;
-- failed processes never can.  Succeeded processes may set this
-- flag to true if they can improve the result they returned
-- given more time.

local function inactive ()
  return {status="inactive", continue=true}
end
xbt.inactive = inactive

local function running ()
  return {status="running", continue=true}
end
xbt.running = running

local function succeeded (value, continue)
  continue = continue or false
  if type(value) ~= "number" then
    -- TODO: Remove this once we have more complete handling
    -- of values
    value = 0
  end
  return {status="succeeded", value=value, continue=continue}
end
xbt.succeeded = succeeded

local function failed (value, reason)
  return {status="failed", continue=false, value=value, reason=reason}
end
xbt.failed = failed

-- Check whether a value is a status.
local function is_status (val)
  if type(val) == "table" then
    local status, cont = val.status, val.continue
    return ((status == "inactive" and cont)
            or (status == "running" and cont)
            or status == "succeeded"
            or (status == "failed" and not cont))
  else
    return false
  end
end
xbt.is_status = is_status  

-- Predicates that check in which state a node
-- (or rather a status returned by evaluating a node) is.

local function is_inactive (status)
  return status.status == "inactive"
end
xbt.is_inactive = is_inactive

local function is_running (status)
  return status.staus == "running"
end
xbt.is_running = is_running

local function is_succeeded (status)
  return status.status == "succeeded"
end
xbt.is_succeeded = is_succeeded

local function is_failed (status)
  return status.status == "failed"
end
xbt.is_failed = is_failed

-- States can be arbitrary, but they have to contain certain
-- attributes:
-- * a `blackboard` for use by the nodes
-- * `node_status`, a table mapping node ids to the corresponding
--   status values.
-- * `improve`, a Boolean flag that indicates whether the nodes
--   that can improve their values should restart the computation
--   or return their previous values.
-- `make_state` takes a table and adds these attributes if necessry.
-- It can also be called without argument (or with a falsy value)
-- to generate a new state.
local function make_state (table)
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
xbt.make_state = make_state

-- Ticking is the fundamental operation on nodes.  To make the node
-- types extensible we look up the ticking function in a table.

local evaluators = {}
xbt.evaluators = evaluators
xbt.default_failure_value = -1

local function tick (node, state)
  state = make_state(state)
  local node_type = node.xbt_node_type
  assert(node_type, tostring(node) .. " has no xbt_node_type.")
  local e = evaluators[node_type]
  assert(e, "No evaluator for node type " .. node_type .. ".")
  local result
  result = e(node, state)
  assert(is_status(result),
    tostring(result) .. " is not a valid status.")
  state.node_status[node.id] = result
  return result
end
xbt.tick = tick

local function is_done (node, state)
  local status = state.node_status[node.id]
  -- This should be unnecessary since we should never store an invalid
  -- status in the `node_status` table.  But let's check just in case.
  assert(is_status(result),
    tostring(result) .. " is not a valid status.")
  if status then
    -- Since `status` is valid the `continue` attribute correctly represents
    -- whether we are done or not.
    return not status.continue
  else
    -- No status for `node` is available, i.e., node has never been
    -- ticked in `state`. 
    return false
  end
end
xbt.is_done = is_done

-- Define an evaluation function and a constructor for `node_type`.
-- `node_type` is stored as `xbt_node_type` in all instances.
-- `arg_names` are the names under which the arguments to the 
--   constructor are stored in the resulting node.
--   For example, if `node_type` is `"foo"` and `arg_names` is
--   `{"bar", "baz"}`, `define_node_type` will define a function
--   `foo` that takes two arguments `arg1` and `arg2` and returns
--   a table `{xbt_node_type="foo", bar=arg1, baz=arg2, id=...}`.
--   Composite nodes must have an argument named `children`.
-- `evaluator` is an evaluator function.  It is called with
--   two arguments: a node and a state.  The state always
--   contains a blackboard attribute.
local function define_node_type(node_type, arg_names, evaluator)
  xbt[node_type] = function (...)
    local args = {...}
    local node = {xbt_node_type=node_type, id=util.uuid()}
    for i, arg_name in ipairs(arg_names) do
      node[arg_name] = args[i]
    end
    return node
  end
  evaluators[node_type] = evaluator
end
xbt.define_node_type = define_node_type

-- Compute the descendants of a node.  This assumes that composite
-- nodes define an attribute `children` that evaluates to a list of
-- all children.

local function descendants (node)
  if node.descendants then
    return node.descendants
  end
  local result = {}
  if node.children then
    for i,child in pairs(node.children) do
      result[#result+1] = child.id
      util.append(result, descendants(child))
    end
    node.descendants = result
    return result
  else
    node.descendants = {}
    return {}
  end
end
xbt.descendants = descendants

-- Set all descendants of a node to their initial state
local function deactivate_descendants (node)
  for _, cid in pairs(descendants(node)) do
    state.node_status[cid] = inactive()
  end
end
xbt.deactivate_descendants = deactivate_descendants

-- We often want to serialize XBTs.  To make this more convenient
-- we allow functions appearing in leaf nodes to be specified as
-- strings, in which case we look up the function value in 
-- `xbt.actions`.
local actions = {}
xbt.actions = actions;

local function define_function_name (name, fun)
  if type(name) ~= "string" then
    error("Action name must be a string.")
  end
  actions[name] = fun
end
xbt.define_function_name = define_function_name
xbt.define_action_name = define_function_name

-- For testing purposes.
---[[
define_function_name("print", print)
define_function_name("print1", function (state)
    print(state)
    return 1
  end)
define_function_name("print_and_succeed", function (state)
    print(state)
    return succeeded("Yeah!")
  end)
--]]

local function lookup_function (f)
  if type(f) == "string" then
    local result = actions[f]
    if result then
      return result
    else
      error("Action " .. f .. " is not defined.")
    end
  else
    return f
  end
end
xbt.lookup_function = lookup_function

-- An XBT node is represented by a table containing an xbt_node_type
-- attribute.  Nodes can either be composite (have child nodes) or 
-- atomic (encapsulate a function or coroutine).  Each node has a
-- unique ID.

-- Function ("fun") nodes encapsulate a function.
-- The function has to return a valid status.

define_node_type("fun", {"fun"}, function (node, state)
    local fun = lookup_function(node.fun)
    local result = fun(state)
    if is_status(result) then
      return result
    else
      return failed(xbt.default_failure_value,
        "Function didn't return a status")
    end
  end)

-- Action nodes are similar to functions, but they wrap the return
-- value of the function into a success status.
define_node_type("action", {"fun"}, function (node, state)
    local fun = lookup_function(node.fun)
    return succeeded(fun(state))
  end)

-- The tick function for sequence nodes
local function tick_seq_node (node, state)
  -- If `node` has already returned a status indicating that it
  -- cannot continue in `state` then return the previous result.
  if is_done(node, state) then
    return result(node, state)
  end
  local sum = 0
  local status
  for _, child in pairs(node.children) do
    status = tick(child, state)
    if is_failed(status) then
      -- A child node has failed, which means that the sequence
      -- node is failed as well and cannot continue.  Prepare
      -- for the next activation before returning the failed
      -- status.
      deactivate_descendants(node)
      return status
    end
    if is_running(status) then
      return status
    end
    assert(is_succeeded(status),
      "Evaluation of seq-node child returned " ..
      tostring(status))
    -- TODO: Need more general handling of result values
    sum = sum + status.value
  end
  -- We have ticked all children with a successful result
  -- Reset the children's results to inactive
  deactivate_descendants(node)
  return succeeded(sum)
end

-- Sequence ("seq") nodes evaluate their children sequentially
-- and fail as soon as one of their children fails.
define_node_type("seq", {"children"}, tick_seq_node)

local function tick_choice_node (node, state)
  -- If `node` has already returned a status indicating that it
  -- cannot continue in `state` then return the previous result.
  if is_done(node, state) then
    return result(node, state)
  end
  local sum = 0
  local status
  for _, child in pairs(node.children) do
    status = tick(child, state)
    if is_succeeded(status) then
      -- We have succeeded; reset the children before
      -- returning
      deactivate_descendants(node)
      return succeeded(status.value + sum)
    end
    if is_running(status) then
      return status
    end
    if (not is_failed(status)) then
      error("Evaluation of choice node returned " .. 
        tostring(status))
    end
    -- TODO: Need more general handling of result values
    sum = sum + status.value
  end
  -- We have ticked all children with a successful result
  -- Reset the children's results to inactive
  deactivate_descendants(node)
  return failed(sum, "All children failed")
end

-- Choice nodes evaluate their children sequentially and
-- succeed as soon as one of their children succeeds.
define_node_type("choice", {"children"}, tick_choice_node)

print("XBTs are ready to go.")

return xbt
