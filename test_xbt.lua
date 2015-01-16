-- test_xbt.lua
-- Tests for Extended Behavior Trees.
-- Copyright © 2015, Matthias Hölzl
-- Licensed under the MIT license, see the file LICENSE.md.

util = require("util")
xbt = require("xbt")
lunatest = require("lunatest")

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

function t.test_is_status ()
  assert_true(xbt.is_status{status="inactive", continue=true})
  assert_false(xbt.is_status{status="inactive", continue=false})
  assert_true(xbt.is_status{status="running", continue=true})
  assert_false(xbt.is_status{status="running", continue=false})
  assert_true(xbt.is_status{status="succeeded", continue=true})
  assert_true(xbt.is_status{status="succeeded", continue=false})
  assert_true(xbt.is_status{status="failed", continue=false})
  assert_false(xbt.is_status{status="failed", continue=true})
  assert_false(xbt.is_status{status="foo", continue=true})
  assert_false(xbt.is_status{status="foo", continue=false})
  assert_false(xbt.is_status("succeeded"))
end

return t