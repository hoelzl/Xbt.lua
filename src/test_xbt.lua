--- Tests for Extended Behavior Trees.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license Licensed under the MIT license, see the file LICENSE.md.

local util = require("util")
local xbt = require("xbt")
local lunatest = require("lunatest")

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

function t.test_is_result_1 ()
  assert_true(xbt.is_result{status="inactive", continue=true, cost=0})
  assert_false(xbt.is_result{status="inactive", continue=true, cost=true})
  assert_false(xbt.is_result{status="inactive", continue=false, cost=0})
  assert_true(xbt.is_result{status="running", continue=true, cost=0})
  assert_false(xbt.is_result{status="running", continue=false, cost=0})
  assert_true(xbt.is_result{status="succeeded", continue=true, cost=0})
  assert_true(xbt.is_result{status="succeeded", continue=false, cost=0})
  assert_true(xbt.is_result{status="failed", continue=false, cost=0})
  assert_false(xbt.is_result{status="failed", continue=true, cost=0})
  assert_false(xbt.is_result{status="foo", continue=true, cost=0})
  assert_false(xbt.is_result{status="foo", continue=false, cost=0})
  assert_false(xbt.is_result("succeeded"))
end

function t.test_is_result_2 ()
  assert_true(xbt.is_result(xbt.inactive()))
  assert_true(xbt.is_result(xbt.running()))
  assert_true(xbt.is_result(xbt.succeeded()))
  assert_true(xbt.is_result(xbt.failed()))
end
  
function t.test_is_result_3 ()
  assert_false(xbt.is_result(xbt.inactive(false)))
  assert_false(xbt.is_result(xbt.inactive({x = 1})))
  assert_false(xbt.is_result(xbt.running(true)))
  assert_false(xbt.is_result(xbt.succeeded("foo")))
  assert_false(xbt.is_result(xbt.failed({})))
end

function t.test_is_inactive ()
  assert_true(xbt.is_inactive(xbt.inactive()))
  assert_false(xbt.is_inactive(xbt.succeeded()))
end

function t.test_is_running ()
  assert_true(xbt.is_running(xbt.running()))
  assert_false(xbt.is_running(xbt.succeeded()))
end

function t.test_is_succeeded ()
  assert_true(xbt.is_succeeded(xbt.succeeded()))
  assert_false(xbt.is_succeeded(xbt.running()))
end

function t.test_is_failed ()
  assert_true(xbt.is_failed(xbt.failed()))
  assert_false(xbt.is_failed(xbt.succeeded()))
end

function t.test_make_state_1 ()
  assert_true(util.equal(xbt.make_state(),
      {blackboard={}, node_results={}, improve=false}))
end

function t.test_make_state_2 ()
  assert_true(util.equal(xbt.make_state({blackboard={x=1}}),
    {blackboard={x=1}, node_results={}, improve=false}))
end

function t.test_is_done ()
  local node = {id="node-1"}
  local state = xbt.make_state()
  local path = util.path.new()
  state.node_results[path] = xbt.succeeded()
  assert_true(xbt.is_done(node, state, path))
  state.node_results[path] = xbt.failed()
  assert_true(xbt.is_done(node, state, path))
  state.node_results[path] = xbt.running()
  assert_false(xbt.is_done(node, state, path))
  state.node_results[path] = xbt.inactive()
  assert_false(xbt.is_done(node, state, path))
end

function t.test_can_continue ()
  local node = {id="node-1"}
  local state = xbt.make_state()
  local path = util.path.new()
  state.node_results[path] = xbt.succeeded()
  assert_false(xbt.can_continue(node, state, path))
  state.node_results[path].continue = true
  -- assert_true(xbt.can_continue(node, state, path))
  state.node_results[path] = xbt.failed()
  assert_false(xbt.can_continue(node, state, path))
  state.node_results[path] = xbt.running()
  assert_true(xbt.can_continue(node, state, path))
  state.node_results[path] = xbt.inactive()
  assert_true(xbt.can_continue(node, state, path))
end

return t