--- Submodule for paths.
-- The submodule `path` contains all operations for
-- operating on paths in the XBT.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.
-- @module xbt.path

local util = require("xbt.util")

local path = {}

--- The metatable for path objects.
path.meta = {__index={}}

--- Generate a new path starting at the root of the XBT.
-- @param id The ID of the agent which is evaluating the XBT.  If no
--  argument is provided for `id`, then a random UUID is generated,
--  so that empty paths allocated without any arguments are never
--  equal to each other.
-- @param ... Any number of positive integers can be passed as
--  arguments to the function and will be used as the value for the
--  result path.
-- @return A new path.
function path.new (id, ...)
  local p = {...}
  setmetatable(p, path.meta)
  p.id = id or util.uuid()
  return p
end

--- Paths are compared using value equality.
-- @param p1 A path.
-- @param p2 Another path.
-- @return `true` if `p1` and `p2` point to the same location in the
--  tree, false otherwise.
-- @function __eq
function path.meta.__eq (p1, p2)
  if #p1 ~= #p2 then return false end
  if p1.id ~= p2.id then return false end
  for i,pos in ipairs(p1) do
    if p2[i] ~= pos then return false end
  end
  return true
end

--- Convert a path to string
-- @param p A path.
-- @return A string representation of `p`
-- @function __tostring
function path.meta.__tostring (p)
  local res = "[" .. p.id .. ":"
  local sep = ""
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
--  @function down
function path.meta.__index.down (p)
  p[#p+1] = 1
  return p
end

--- Move to the next sibling of the current node.
-- @param p A path pointing to a node `n` in an XBT.
-- @return The value of `p` modified to point to the right sibling of
--  `n`.
--  @function right
function path.meta.__index.right (p)
  assert(#p > 0, "The root node has no right sibling.")
  p[#p] = p[#p] + 1
  return p
end

--- Move up one level in a tree.
-- @param p A path pointing to a non-root node `n` of an XBT.
-- @return The value of `p` modified to point to the parent of `n`.
-- @function up
function path.meta.__index.up (p)
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
-- @function copy
function path.meta.__index.copy(p, extension)
  local function assert_position (pos)
    assert(pos >= 0, "Cannot add negative positions to a path.")
  end
  local res = path.new(p.id)
  for i,n in ipairs(p) do
    res[i] = n
  end
  if extension then
    if type(extension) == "number" then
      -- assert_position(extension)
      res[#res+1] = extension
    else
      for _,pos in ipairs(extension) do
        -- assert_position(pos)
        res[#res+1] = pos
      end
    end
  end
  return res
end

--- Return the root path for a path.
-- When running the same XBT for multiple objects we use the first
-- component of the path as object id, so that we have a forest of
-- execution trees.
-- @return A new path containing only the first element of the given
--  path.
-- @function object_id
function path.meta.__index.object_id (p)
  if p.root_path then
    return p.root_path
  else
    local rp = path.new(p.id)
    p.root_path = rp
    return rp 
  end
end

--- Check whether a value represents a path.
-- @param p The value to be tested.
-- @return A Boolean indicating whether `p` is a path.  This decision
--  is made by checking whether the metatable of `p` is the one
--  defined for paths, so path-like objects are not accepted.
function path.is_path (p)
  return getmetatable(p) == path.meta
end

return path
