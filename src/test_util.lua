--- Tests for the utility functions.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.

local util = require("util")
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

function t.test_uuid ()
  -- Only test for the correct pattern.
  assert_true(string.match(
      util.uuid(),
      "%x%x%x%x%x%x%x%x%-%x%x%x%x%-4%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x"))
  -- Check that freshly generated uuids are distinct
  assert_not_equal(util.uuid(), util.uuid())
end

function t.test_size ()
  assert_equal(util.size({}), 0)
  assert_equal(util.size({1, 2, 3}), 3)
  assert_equal(util.size({1, {2}, {1, 2, 3}, 4}), 4)
  assert_equal(util.size({x = 1, y = "Y"}), 2)
end

function t.test_equal_1 ()
  assert_true(util.equal(1, 1))
  assert_false(util.equal(1, 2))
  assert_true(util.equal("foo", "foo"))
  assert_false(util.equal("foo", "bar"))
end

function t.test_equal_2 ()
  assert_true(util.equal({}, {}))
  assert_false(util.equal({}, {1}))
  assert_false(util.equal({1}, {}))
  assert_false(util.equal({}, {x = "X"}))
  assert_false(util.equal({x = "X"}, {}))
end

function t.test_equal_3 ()
  assert_true(util.equal({1, 2, 3}, {1, 2, 3}))
  assert_false(util.equal({1, 2, 3}, {1, 2, 3, 4}))
  assert_false(util.equal({1, 2}, {1, 2, 3}))
  assert_false(util.equal({1, 2, 3, 4}, {1, 2}))
end

function t.test_equal_4 ()
  assert_false(util.equal({1, 2, 3}, {1, 3, 2}))
  assert_false(util.equal({3, 1, 2}, {1, 2, 3}))
  assert_false(util.equal({1, 2, 3}, {3, 2, 1}))
end

function t.test_equal_5 ()
  assert_true(util.equal({x="X", y="Y", z="Z"}, {x="X", y="Y", z="Z"}))
  assert_false(util.equal({x="X", y="Y", z="Z"}, {x="X", y="Y", z="Z", w="W"}))
  assert_false(util.equal({x="X", y="Y", z="Z"}, {x="X", y="Y"}))
  assert_false(util.equal({x="X", y="Y", z="Z", w="W"}, {x="X", y="Y", z="Z"}))
  assert_false(util.equal({x="X", y="Y"}, {x="X", y="Y", z="Z"}))
end

function t.test_equal_6 ()
  assert_true(util.equal({{1}, {2}, {3}}, {{1}, {2}, {3}}))
  assert_false(util.equal({{1}, {2}, {3}}, {{1}, {3}, {2}}))
end

function t.test_addall_1 ()
  local t1 = {}
  local res = util.addall(t1, {x = "XX", y = "YY"})
  assert_table(res)
  assert_true(util.equal(res, {x = "XX", y = "YY"}))
  assert_true(util.equal(t1, {x = "XX", y = "YY"}))
end

function t.test_addall_2 ()
  local t1 = {a = "AA", b = "BB", x = "XX"}
  local res = util.addall(t1, {x = "xx", y = "YY"})
  assert_table(res)
  assert_true(util.equal(res, {a = "AA", b = "BB", x = "xx", y = "YY"}))
  assert_true(util.equal(t1, {a = "AA", b = "BB", x = "xx", y = "YY"}))
end

function t.test_keys ()
  assert_true(util.equal(util.keys({}), {}))
  assert_true(util.equal(util.keys({10, 20, 30}), {1, 2, 3}))
  assert_true(util.equal(util.keys({x="X", y="Y"}), {"x", "y"}))
end

function t.test_append ()
  assert_true(util.equal(util.append({1,2,3}, {}), {1,2,3}))
  assert_true(util.equal(util.append({}, {1,2,3}), {1,2,3}))
  assert_true(util.equal(util.append({1,2,3}, {4,5,6}), {1,2,3,4,5,6}))
end

function t.test_maybe_add_1 ()
  assert_true(util.equal(util.maybe_add({}, "foo"), {foo={}}))
  assert_true(util.equal(util.maybe_add({bar="bar"}, "foo"),
      {foo={}, bar="bar"}))
  assert_true(util.equal(util.maybe_add({bar="bar"}, "bar"),
      {bar="bar"}))
end

function t.test_maybe_add_2 ()
  assert_true(util.equal(util.maybe_add({}, "foo", true),
      {foo=true}))
  assert_true(util.equal(util.maybe_add({bar="bar"}, "foo", true),
      {foo=true, bar="bar"}))
  assert_true(util.equal(util.maybe_add({bar="bar"}, "bar", true),
      {bar="bar"}))
end

function t.test_maybe_add_3 ()
  assert_true(util.equal(util.maybe_add({}, "foo", false),
      {foo=false}))
  assert_true(util.equal(util.maybe_add({bar="bar"}, "foo", false),
      {foo=false, bar="bar"}))
  assert_true(util.equal(util.maybe_add({bar="bar"}, "bar", false),
      {bar="bar"}))
end

function t.test_path_new ()
  local p = util.path.new()
  assert_true(util.equal(p,{}))
  assert_true(util.equal(getmetatable(p), util.path.meta))
  p = util.path.new(10, 20, 30, 40)
  assert_true(util.equal(p,{10, 20, 30, 40}))
  assert_true(util.equal(getmetatable(p), util.path.meta))
  
end

function t.test_down ()
  local p = util.path.new()
  assert_true(util.equal(p,{}))
  local res = p:down()
  assert_true(util.equal(res, {1}))
  assert_true(util.equal(p, {1}))
  res = p:down()
  assert_true(util.equal(res, {1, 1}))
  assert_true(util.equal(p, {1, 1}))
  p:down()
  p:down()
  p:down()
  assert_true(util.equal(p, {1, 1, 1, 1, 1}))
end

function t.test_up ()
  local p = util.path.new()
  p:down()
  p:down()
  p:down()
  p:down()
  p:down()
  assert_true(util.equal(p, {1, 1, 1, 1, 1}))
  local res = p:up()
  assert_true(util.equal(res, {1, 1, 1, 1}))
  assert_true(util.equal(p, {1, 1, 1, 1}))
  res = p:up()
  assert_true(util.equal(res, {1, 1, 1}))
  assert_true(util.equal(p, {1, 1, 1}))
  p:up()
  p:up()
  assert_true(util.equal(p, {1}))
  res = p:up()
  assert_true(util.equal(res, {}))
  assert_true(util.equal(p, {}))
  assert_error(function () p:up() end)
end

function t.test_right ()
  local p = util.path.new()
  p:down()
  assert_true(util.equal(p, {1}))
  local res = p:right()
  assert_true(util.equal(res, {2}))
  assert_true(util.equal(p, {2}))
  res = p:right()
  assert_true(util.equal(res, {3}))
  assert_true(util.equal(p, {3}))
  p:right()
  assert_true(util.equal(p, {4}))
  res = p:up()
  assert_true(util.equal(res, {}))
  assert_error(function () p:right() end)
end

function t.test_is_path ()
  local p = util.path.new()
  assert_true(util.is_path(p))
  p:down() 
  assert_true(util.is_path(p))
  p:right()
  assert_true(util.is_path(p))
  p:up()
  assert_true(util.is_path(p))
end

function t.test_path_copy_1 ()
  local p = util.path.new()
  p:down(); p:down()
  p:right(); p:right(); p:right()
  p:down()
  p:right(); p:right()
  p:down()
  assert_true(util.equal(p, {1,4,3,1}))
  local c = p:copy()
  assert_true(util.equal(p, {1,4,3,1}))
  assert_true(util.equal(c, {1,4,3,1}))
  c:right()
  assert_true(util.equal(p, {1,4,3,1}))
  assert_true(util.equal(c, {1,4,3,2}))
  p:up(); p:up()
  assert_true(util.equal(p, {1,4}))
  assert_true(util.equal(c, {1,4,3,2}))
  p:right()
  c:up(); c:up(); c:up(); c:up()
  assert_true(util.equal(p, {1,5}))
  assert_true(util.equal(c, {}))
end

function t.test_path_copy_2 ()
  local p = util.path.new()
  p:down(); p:down()
  p:right(); p:right(); p:right()
  p:down()
  p:right(); p:right()
  p:down()
  assert_true(util.equal(p, {1,4,3,1}))
  local c = p:copy(5)
  assert_true(util.equal(p, {1,4,3,1}))
  assert_true(util.equal(c, {1,4,3,1,5}))
  c:right()
  assert_true(util.equal(p, {1,4,3,1}))
  assert_true(util.equal(c, {1,4,3,1,6}))
  p:up(); p:up()
  assert_true(util.equal(p, {1,4}))
  assert_true(util.equal(c, {1,4,3,1,6}))
  p:right()
  c:up(); c:up(); c:up(); c:up()
  assert_true(util.equal(p, {1,5}))
  assert_true(util.equal(c, {1}))
end

function t.test_path_copy_3 ()
  local p = util.path.new()
  p:down(); p:down()
  p:right(); p:right(); p:right()
  p:down()
  p:right(); p:right()
  p:down()
  assert_true(util.equal(p, {1,4,3,1}))
  local c = p:copy({5, 1, 3})
  assert_true(util.equal(p, {1,4,3,1}))
  assert_true(util.equal(c, {1,4,3,1,5,1,3}))
  c:right()
  assert_true(util.equal(p, {1,4,3,1}))
  assert_true(util.equal(c, {1,4,3,1,5,1,4}))
  p:up(); p:up()
  assert_true(util.equal(p, {1,4}))
  assert_true(util.equal(c, {1,4,3,1,5,1,4}))
  p:right()
  c:up(); c:up(); c:up(); c:up()
  assert_true(util.equal(p, {1,5}))
  assert_true(util.equal(c, {1,4,3}))
end

function t.test_path_eq ()
  local p1 = util.path.new(1,3,6,4,5,2)
  local p2 = util.path.new(1,3,6,4,5,2)
  local p3 = p2:copy()
  assert_true(p1 == p2)
  assert_true(p2 == p1)
  assert_true(p1 == p3)
  assert_true(p3 == p1)
  assert_true(p2 == p3)
  assert_true(p3 == p2)
  p2:down()
  p3:up()
  assert_false(p1 == p2)
  assert_false(p2 == p1)
  assert_false(p1 == p3)
  assert_false(p3 == p1)
  assert_false(p2 == p3)
  assert_false(p3 == p2)
  p3:down():right()
  assert_false(p1 == p2)
  assert_false(p2 == p1)
  assert_true(p1 == p3)
  assert_true(p3 == p1)
  assert_false(p2 == p3)
  assert_false(p3 == p2) 
end

function t.test_path_to_string ()
  local p1 = util.path.new()
  local p2 = util.path.new(1,3,6,4,5,2)
  assert_equal(tostring(p1), "[]")
  assert_equal(tostring(p2), "[1,3,6,4,5,2]")
  assert_equal(tostring(p2:copy()), "[1,3,6,4,5,2]")
end

return t