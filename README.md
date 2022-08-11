# BuildSystem : A simple experimental makefile system for Julia
# Instructions on how to use BuildSystem package
To use this package, you must use our modified version of Julia compiler.

Due to some technical limitations, Julia fails to build system image in our modified compiler. So we need to first build the system image in an unmodified Julia, then apply our patch.

## Build a modified Julia

Firstly download our fork of Julia `https://github.com/ChenNingCong/julia.git`, then checkout to commit `55808a56e0fcd147b10e35d64721a1849c841196`. Build Julia normally following official documents. Then switch to `master` and run `make julia-noimage-release`. This will build julia without running system image build process. After this you can run `make binary-dist` to get a packed julia distribution (not necessary).

## Build a binary cacche

Firstly ensure that you install this package `BuildSytem` in the same directory where you install you julia executable. For example, if you unpack your julia installation (or build) at path `/home/username/julia`, then you also need to install the package with path `/home/username/BuildSystem`.

To run the demo, follow these steps:
1. At root path of `BuildSystem`, run `source test/help.sh` in shell. This script creates two shortcuts `ju18` and `jbuild`. `ju18` is used to start julia in the image-codegen mode, and `jbuild` drives the makefile system for julia.
2. At root path of `BuildSystem`, run `jbuild test/json_ninja.jl`. This will build a compiled cache of `JSON` package. You need to wait a couple of time because we need to firstly compile `BuildSystem`, `Test` and `Pkg`, on which the build system depends. You need to compile them only once because the results are cached and can be reused. The actual time spend on compiling JSON is small.
3. If you encounter no error at step 1 and 2, you can check the directory of `test/binary`, where you can find a bundle of compiled binary files. 

Now you have the compiled binary generated from test files, it's time to use these binaries!
1. At root path of `BuildSystem`, run `ju18`. This command will start a new Julia (version 1.8.0-DEV). 
2. `Pkg.activate("test")` to activate the environment at `test` folder. Run `Pkg.instantiate()` to install dependencies. This may take some time, for `Pkg.instantiate` is not compiled due to some technical limitation.
3. Now excecute `@use JSON`, to import both the package and the binary.
4. Run `x = JSON.parse("123")`, you can notice that the latency is completely gone.
5. Run
    ```
    s = "{\"a_number\" : 5.0, \"an_array\" : [\"string\", 9]}"
    JSON.parse(s)
    ```
6. You may notice that step 5 still have latency. This is largely due to the compilation of `display` in the REPL, which is generally not touched in test file. To conquer this problem, run `saveWork([:JSON])`. This will magically save all the compiled code in JSON generated in this REPL session.
7. To use the REPL cache, the next time you open REPL, ***after*** you load JSON library (after step 3, this is very important), run `loadREPL()` to bring in the binary cache you save, repeat step 5,6 and now you can see that the latency is completely gone!!!

