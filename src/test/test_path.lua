--- Tests for the XBT path functions.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.

local util = require("xbt.util")
local xbt_path = require("xbt.path")
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

function t.test_path_new ()
  local id = util.uuid()
  local p = xbt_path.new(id)
  assert_true(util.equal(p,{id=id}))
  assert_false(util.equal(xbt_path.new(), p))
  assert_false(util.equal(xbt_path.new(), xbt_path.new()))
  assert_true(util.equal(getmetatable(p), xbt_path.meta))
  p = xbt_path.new(id, 10, 20, 30, 40)
  assert_true(util.equal(p,{id=id, 10, 20, 30, 40}))
  assert_true(util.equal(getmetatable(p), xbt_path.meta))
end

function t.test_down ()
  local id = util.uuid()
  local p = xbt_path.new(id)
  assert_true(util.equal(p,{id=id}))
  local res = p:down()
  assert_true(util.equal(res, {id=id, 1}))
  assert_true(util.equal(p, {id=id, 1}))
  res = p:down()
  assert_true(util.equal(res, {id=id, 1, 1}))
  assert_true(util.equal(p, {id=id, 1, 1}))
  p:down()
  p:down()
  p:down()
  assert_true(util.equal(p, {id=id, 1, 1, 1, 1, 1}))
end

function t.test_up ()
  local id = util.uuid()
  local p = xbt_path.new(id)
  p:down()
  p:down()
  p:down()
  p:down()
  p:down()
  assert_true(util.equal(p, {id=id, 1, 1, 1, 1, 1}))
  local res = p:up()
  assert_true(util.equal(res, {id=id, 1, 1, 1, 1}))
  assert_true(util.equal(p, {id=id, 1, 1, 1, 1}))
  res = p:up()
  assert_true(util.equal(res, {id=id, 1, 1, 1}))
  assert_true(util.equal(p, {id=id, 1, 1, 1}))
  p:up()
  p:up()
  assert_true(util.equal(p, {id=id, 1}))
  res = p:up()
  assert_true(util.equal(res, {id=id}))
  assert_true(util.equal(p, {id=id}))
  assert_error(function () p:up() end)
end

function t.test_right ()
  local id = util.uuid()
  local p = xbt_path.new(id)
  p:down()
  assert_true(util.equal(p, {id=id, 1}))
  local res = p:right()
  assert_true(util.equal(res, {id=id, 2}))
  assert_true(util.equal(p, {id=id, 2}))
  res = p:right()
  assert_true(util.equal(res, {id=id, 3}))
  assert_true(util.equal(p, {id=id, 3}))
  p:right()
  assert_true(util.equal(p, {id=id, 4}))
  res = p:up()
  assert_true(util.equal(res, {id=id}))
  assert_error(function () p:right() end)
end

function t.test_is_path ()
  local p = xbt_path.new()
  assert_true(xbt_path.is_path(p))
  p:down() 
  assert_true(xbt_path.is_path(p))
  p:right()
  assert_true(xbt_path.is_path(p))
  p:up()
  assert_true(xbt_path.is_path(p))
end

function t.test_path_copy_1 ()
  local id = util.uuid()
  local p = xbt_path.new(id)
  p:down(); p:down()
  p:right(); p:right(); p:right()
  p:down()
  p:right(); p:right()
  p:down()
  assert_true(util.equal(p, {id=id, 1, 4, 3, 1}))
  local c = p:copy()
  assert_true(util.equal(p, {id=id, 1, 4, 3, 1}))
  assert_true(util.equal(c, {id=id, 1, 4, 3, 1}))
  c:right()
  assert_true(util.equal(p, {id=id, 1, 4, 3, 1}))
  assert_true(util.equal(c, {id=id, 1, 4, 3, 2}))
  p:up(); p:up()
  assert_true(util.equal(p, {id=id, 1, 4}))
  assert_true(util.equal(c, {id=id, 1, 4, 3, 2}))
  p:right()
  c:up(); c:up(); c:up(); c:up()
  assert_true(util.equal(p, {id=id, 1, 5}))
  assert_true(util.equal(c, {id=id}))
end

function t.test_path_copy_2 ()
  local id = util.uuid()
  local p = xbt_path.new(id)
  p:down(); p:down()
  p:right(); p:right(); p:right()
  p:down()
  p:right(); p:right()
  p:down()
  assert_true(util.equal(p, {id=id, 1, 4, 3, 1}))
  local c = p:copy(5)
  assert_true(util.equal(p, {id=id, 1, 4, 3, 1}))
  assert_true(util.equal(c, {id=id, 1, 4, 3, 1, 5}))
  c:right()
  assert_true(util.equal(p, {id=id, 1, 4, 3, 1}))
  assert_true(util.equal(c, {id=id, 1, 4, 3, 1, 6}))
  p:up(); p:up()
  assert_true(util.equal(p, {id=id, 1,4}))
  assert_true(util.equal(c, {id=id, 1, 4, 3, 1, 6}))
  p:right()
  c:up(); c:up(); c:up(); c:up()
  assert_true(util.equal(p, {id=id, 1, 5}))
  assert_true(util.equal(c, {id=id, 1}))
end

function t.test_path_copy_3 ()
  local id = util.uuid()
  local p = xbt_path.new(id)
  p:down(); p:down()
  p:right(); p:right(); p:right()
  p:down()
  p:right(); p:right()
  p:down()
  assert_true(util.equal(p, {id=id, 1, 4, 3, 1}))
  local c = p:copy({5, 1, 3})
  assert_true(util.equal(p, {id=id, 1, 4, 3, 1}))
  assert_true(util.equal(c, {id=id, 1, 4, 3, 1, 5, 1, 3}))
  c:right()
  assert_true(util.equal(p, {id=id, 1, 4, 3, 1}))
  assert_true(util.equal(c, {id=id, 1, 4, 3, 1, 5, 1, 4}))
  p:up(); p:up()
  assert_true(util.equal(p, {id=id, 1, 4}))
  assert_true(util.equal(c, {id=id, 1, 4, 3, 1, 5, 1, 4}))
  p:right()
  c:up(); c:up(); c:up(); c:up()
  assert_true(util.equal(p, {id=id, 1, 5}))
  assert_true(util.equal(c, {id=id, 1, 4, 3}))
end

function t.test_path_eq ()
  local id = util.uuid()
  local p1 = xbt_path.new(id, 1, 3, 6, 4, 5, 2)
  local p2 = xbt_path.new(id, 1, 3, 6, 4, 5, 2)
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
  local id1 = util.uuid()
  local p1 = xbt_path.new(id1)
  local id2 = util.uuid()
  local p2 = xbt_path.new(id2, 1,3,6,4,5,2)
  assert_equal("[" .. id1 .. ":]", tostring(p1))
  assert_equal("[" .. id2 .. ":1,3,6,4,5,2]", tostring(p2))
  assert_equal("[" .. id2 .. ":1,3,6,4,5,2]", tostring(p2:copy()))
end

return t