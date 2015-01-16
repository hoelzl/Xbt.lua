-- test_xbt.lua
-- Tests for Extended Behavior Trees.
-- Copyright © 2015, Matthias Hölzl
-- Licensed under the MIT license, see the file LICENSE.md.

xbt = require("xbt")
lunatest = require("lunatest")

local assert_equal = lunatest.assert_equal
local assert_true = lunatest.assert_true
local assert_nil = lunatest.assert_nil
local jit = jit

local t = {}

return t