--- Utility functions for XBTs.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.

local util = {}

--- An implementation of version 4 UUIDs.
-- @return A string in UUID V4 format.
function util.uuid ()
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

--- Compute the size of a table.
-- This includes all attributes and array members.
-- @param t A table
-- @return The number of attributes of `t`.
function util.size(t)
  local size = 0
  for _,_ in pairs(t) do
    size = size + 1
  end
  return size
end

--- Value equality for tables.
-- Check whether two tables are equal as values.  Recursively descends
-- into attributes.  All other values are compared using `==`.
-- Ignoeres metatables.
-- @param t1 A table.
-- @param t2 A table.
-- @return `true` if `t1` and `t2` have the same value, `false`
--  otherwise.  Calls itself recursively and may therefore fail for
--  cyclic data structures.
function util.equal(t1, t2)
  if (type(t1) == "table" and type(t2) == "table") then
    for k,v in pairs(t1) do
      if not util.equal(t2[k], v) then return false end
    end
    for k,v in pairs(t2) do
      if not util.equal(t1[k], v) then return false end
    end
    return true
  else
    return t1 == t2
  end
end

--- Return a list containing the keys of a table.
-- @param t A table.
-- @return The keys of `t` sorted alphabetically.
function util.keys(t)
  local n = 1
  local res = {}
  for k,_ in pairs(t) do
    res[n] = k
    n = n + 1
  end
  table.sort(res)
  return res
end

--- Conjoin the members of one table to another.
-- @param t1 The table to which the new values are added.  Modified
--  destructively.
-- @param t2 The table containing the new keys
-- @return `t1`, modified with the key/value bindings of `t2` Keys
--  occurring in both tables get the value of `t2`.
function util.addall(t1, t2)
  for k,v in pairs(t2) do
    t1[k] = v
  end
  return t1
end

--- Append two arrays.
-- @param t1 An array.  Destructively modified.
-- @param t2 An array.
-- @return `t1`, extended with the values of `t2`
function util.append(t1, t2)
  for k,v in ipairs(t2) do
    t1[#t1+1] = v
  end
  return t1
end

--- Add an attribute to a table if it doesn't already exist.
-- @param table The table to which the attribute is added
-- @param attribute The name of the attribute as string
-- @param value The value of the attribute.  Defaults to `{}`
-- @return `table`, with the `attribute`/`value` pair added if no
--  value for `attribute` was present, the unmodified table otherwise.
function util.maybe_add (table, attribute, value)
  if value == nil then
    value = {}
  end
  if not table[attribute] then
    table[attribute] = value
  end
  return table
end

--- Submodule for paths.
-- The submodule `path` contains all operations for
-- operating on paths in the XBT.
util.path = {}

--- Generate a new path starting at the root of the XBT.
-- @param ... Any number of positive integers can be passed as
--  arguments to the function and will be used as the value for the
--  result path.
-- @return A new path.
function util.path.new (...)
  local p = {...}
  setmetatable(p, util.path.meta)
  return p
end

--- The metatable for path objects.
util.path.meta = {__index={}}

--- Paths are compared using value equality.
-- @param p1 A path.
-- @param p2 Another path.
-- @return `true` if `p1` and `p2` point to the same location in the
--  tree, false otherwise.
function util.path.meta.__eq (p1, p2)
  if #p1 ~= #p2 then return false end
  for i,pos in ipairs(p1) do
    if p2[i] ~= pos then return false end
  end
  return true
end

--- Convert a path to string
-- @param p A path.
-- @return A string representation of `p`
function util.path.meta.__tostring (p)
  local res, sep = "[", ""
  for _,pos in ipairs(p) do
    res = res .. sep .. pos
    sep = ","
  end
  res = res .. "]"
  return res 
end

--- Descend one level deeper into the tree.
-- @param p A path pointing to a node `n` in an XBT.
-- @return The value of `p` modified to point to the first child of
--  `n`.
function util.path.meta.__index.down (p)
  p[#p+1] = 1
  return p
end

--- Move to the next sibling of the current node.
-- @param p A path pointing to a node `n` in an XBT.
-- @return The value of `p` modified to point to the right sibling of
--  `n`.
function util.path.meta.__index.right (p)
  assert(#p > 0, "The root node has no right sibling.")
  p[#p] = p[#p] + 1
  return p
end

--- Move up one level in a tree.
-- @param p A path pointing to a non-root node `n` of an XBT.
-- @return The value of `p` modified to point to the parent of `n`.
function util.path.meta.__index.up (p)
  assert(#p > 0, "Cannot move above the root of a tree.")
  p[#p] = nil
  return p
end

--- Copy a path.
-- @param p A path pointing to a node in an XBT.
-- @param extension An extension of the path that will be added to the
--  copy.  Either a positive integer for a single step or an array of
--  positive integers for a relative path.  No extension is added if
--  `extension` is falsy.  Default is `nil`.
-- @return A copy of the path `p`.
function util.path.meta.__index.copy(p, extension)
  local res = util.path.new()
  for i,n in ipairs(p) do
    res[i] = n
  end
  if extension then
    if type(extension) == "number" then
      assert(extension >= 0,
        "Cannot add negative positions to a path")
      res[#res+1] = extension
    else
      util.append(res, extension)
    end
  end
  return res
end

--- Check whether a value represents a path.
-- @param p The value to be tested.
-- @return A Boolean indicating whether `p` is a path.  This decision
--  is made by checking whether the metatable of `p` is the one
--  defined for paths, so path-like objects are not accepted.
function util.is_path (p)
  return getmetatable(p) == util.path.meta
end

--- A flag indicating whether debug output should be shown.
util.debug = false

--- Print arguments when debugging is enabled.
-- @param ... Any number of arguments will be passed on to `print`.
function util.debug_print(...)
  if util.debug then
    print(...)
  end
end

return util;
