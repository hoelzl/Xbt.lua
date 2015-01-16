-- xbt.lua
-- Extended Behavior Trees in Lua.
-- Copyright © 2015, Matthias Hölzl
-- Licensed under the MIT license, see the file LICENSE.md.

-- See the [readme file](README.md) for documentation (well, not yet).

xbt = {}

-- A rather inefficient implementation of version 4 UUIDs
-- 
local function uuid()
  local digits = {
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
    "a", "b", "c", "d", "e", "f" }
  local result = {}
  local function append_digit()
    local index = math.random(1, #digits)
    result[#result + 1] = digits[index]
  end
  local function append_n_digits(n)
    for _ = 1, n do
      append_digit()
    end
  end
  append_n_digits(8)
  result[#result + 1] = "-"
  append_n_digits(4)
  result[#result + 1] = "-"
  result[#result + 1] = "4"
  append_n_digits(3)
  result[#result + 1] = "-"
  result[#result + 1] = digits[math.random(8,11)]
  append_n_digits(3)
  result[#result + 1] = "-"
  append_n_digits(8)
  return table.concat(result)
end
xbt.uuid = uuid

--[[
local function table_addall(t1, t2)
  for k,v in pairs(t2) do
    t1[k] = v
  end
  return t1
end
-- table.addall = table_addall
--]]

local function table_append(t1, t2)
  for k,v in ipairs(t2) do
    t1[#t1+1] = v
  end
  return t1
end
-- table.append = table_append

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

-- We sometimes need to check whether a value is a status.

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

-- We define some predicates to check in which state a node
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

local function maybe_add (table, attribute)
  if not table[attribute] then
    table[attribute] = {}
  end
  return table
end
-- States can be arbitrary, but they have to contain a blackboard
-- and a table that maps node ids to the corresponding status values.
local function make_state (table)
  if not table then
    table = {}
  end
  if type(table) == "table" then
    maybe_add(table, "blackboard")
    maybe_add(table, "node_status")
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
  local e = evaluators[node_type]
  local result
  if e then
    result = e(node, state)
  else
    result = failed(xbt.default_failure_value,
      (node_type and 
        "No evaluator for node type " .. node_type .. ".") or
        tostring(node) .. " has no xbt_node_type.")
  end
  state.node_status[node.id] = result
  return result
end
xbt.tick = tick

local function is_done (node, state)
  local status = state.node_status[node.id]
  if status then
    return not status.continue
  else
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
    local node = {xbt_node_type=node_type, id=uuid()}
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
      table_append(result, descendants(child))
    end
    node.descendants = result
    return result
  else
    node.descendants = {}
    return {}
  end
end
xbt.descendants = descendants

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

local function tick_seq_node (node, state)
  if is_done(node, state) then
    return result(node, state)
  end
  local sum = 0
  local status
  for _, child in pairs(node.children) do
    status = tick(child, state)
    if is_failed(status) or is_running(status) then
      return status
    end
    if (not is_succeeded(status)) then
      error("Evaluation of seq node returned " .. 
        tostring(status))
    end
    -- TODO: Need more general handling of result values
    sum = sum + status.value
  end
  -- We have ticked all children with a successful result
  -- Reset the children's results to inactive
  for _, cid in pairs(descendants(node)) do
    state.node_status[cid] = inactive()
  end
  return succeeded(sum)
end

-- Sequence ("seq") nodes evaluate their children sequentially
-- and fail as soon as one of their children fails.
define_node_type("seq", {"children"}, tick_seq_node)

local function tick_choice_node (node, state)
  if is_done(node, state) then
    return result(node, state)
  end
  local sum = 0
  local status
  for _, child in pairs(node.children) do
    status = tick(child, state)
    if is_succeeded(status) then
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
  for _, cid in pairs(descendants(node)) do
    state.node_status[cid] = inactive()
  end
  return failed(sum, "All children failed")
end

-- Choice nodes evaluate their children sequentially and
-- succeed as soon as one of their children succeeds.
define_node_type("choice", {"children"}, tick_choice_node)

print("XBTs are ready to go.")
