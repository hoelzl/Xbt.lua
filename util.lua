-- util.lua
-- Utility functions for XBTs.
-- Copyright © 2015, Matthias Hölzl
-- Licensed under the MIT license, see the file LICENSE.md.

local util = {}

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
util.uuid = uuid

local function table_size(t)
  local size = 0
  for _,_ in pairs(t) do
    size = size + 1
  end
  return size
end
util.size = table_size

local function table_equal(t1, t2)
  if (type(t1) == "table" and type(t2) == "table") then
    for k,v in pairs(t1) do
      if not table_equal(t2[k], v) then return false end
    end
    for k,v in pairs(t2) do
      if not table_equal(t1[k], v) then return false end
    end
    return true
  else
    return t1 == t2
  end
end
util.equal = table_equal

local function table_keys(t)
  local n = 1
  local res = {}
  for k,_ in pairs(t) do
    res[n] = k
    n = n + 1
  end
  table.sort(res)
  return res
end
util.keys = table_keys

local function table_addall(t1, t2)
  for k,v in pairs(t2) do
    t1[k] = v
  end
  return t1
end
-- table.addall = table_addall
util.addall = table_addall

local function table_append(t1, t2)
  for k,v in ipairs(t2) do
    t1[#t1+1] = v
  end
  return t1
end
-- table.append = table_append
util.append = table_append

local function maybe_add (table, attribute)
  if not table[attribute] then
    table[attribute] = {}
  end
  return table
end
util.maybe_add = maybe_add

return util;