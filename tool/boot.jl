#include("newTest.jl")
Core.include(Core.Compiler, "../base/compiler/bootstrap.jl")
info = Set{Any}(dumpGraph());
freezeDependency();
legals = filterUpperWorld(info, Symbol[:Core]);
writeConfig(abspath("corecompiler.config"), legals)
objPaths = String[]
for i in info
    if i isa JITMethodInstance
        push!(objPaths, i.objectFilePath)
    end
end
libPath = "corecompiler.lib"
command = `ar rcs $libPath $objPaths`;
run(command);