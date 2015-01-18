# Extended Behavior Trees (XBTs)

This is an implementation of XBTs in Lua.  See the paper
in the ASCENS book for the description of XBTs.

The implementation is in the file [xbt.lua](src/xbt.lua)

Run the tests by invoking
```
$ lua ./test_all.lua
```
in the `src` folder.

The file [main.lua](src/main.lua) holds a small example
program.  You can invoke it from the source folder as

```
$ lua ./main.lua
```

It currently runs two behaviors sequentially; the first one always
succeeds in the fifth step, the second one randomly fails or succeeds
after a random number of steps.
