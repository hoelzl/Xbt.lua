--- Test runner for the XBT module.
-- @copyright 2015, Matthias Hölzl
-- @author Matthias Hölzl
-- @license MIT, see the file LICENSE.md.

lunatest = require("lunatest")

lunatest.suite("test.test_util")
lunatest.suite("test.test_path")
lunatest.suite("test.test_xbt")

lunatest.run()
