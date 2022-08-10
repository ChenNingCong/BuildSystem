gfs = Vector{Any}();
for i in names(Core.Compiler, all = true)
    v = Core.getfield(Core.Compiler, i)
    if isa(v, Function)
        append!(gfs, methods(v).ms)
    elseif isa(v, UnionAll)
        v = Core.Compiler.unwrap_unionall(v)
    else 
        continue
    end
    if isa(v, DataType)
        append!(gfs, Base.MethodList(v.name.mt).ms)
    end
end
unique!(gfs);
mis = Core.MethodInstance[];
for i in gfs
    s::Core.SimpleVector = i.specializations
    for p in 1:length(s)
        if isassigned(s, p)
            v = s[p]
            if v !== nothing
                push!(mis,v )
            end
        end
    end
end
#=
    bool needsparams = false;
    if (jl_is_method(lam->def.method)) {
        if ((size_t)jl_subtype_env_size(lam->def.method->sig) != jl_svec_len(lam->sparam_vals))
            needsparams = true;
        for (size_t i = 0; i < jl_svec_len(lam->sparam_vals); ++i) {
            if (jl_is_typevar(jl_svecref(lam->sparam_vals, i)))
                needsparams = true;
        }
    }
=#
function needSparam(mi::Core.MethodInstance)
    i = 0
    x = mi.def.sig
    while x isa UnionAll
        i += 1
        x = x.body
    end
    if i != length(mi.sparam_vals)
        return true
    end
    for i in 1:length(mi.sparam_vals)
        t = mi.sparam_vals[i]
        if isa(t, Core.TypeVar)
            return true
        end
    end
    return false
end
world = Base.get_world_counter()
for mi in mis
    if !needSparam(mi)
        ccall(:jl_force_jit,Ptr{Nothing},(Any, UInt64), mi, world)
    end
end
info = Set{Any}(dumpGraph());
removeNonRelocatale!(info);
freezeDependency();
ages = Set{Vector{Symbol}}();
legals = filterUpperWorld(info, [:Core]);
outputDir = "./"
libName = "corecompiler"
writeConfig(abspath(joinpath(outputDir, libName * ".config")), legals);
objPaths = String[];
for i in info
    if i isa JITMethodInstance
        push!(objPaths, i.objectFilePath)
    end
end
libPath = "corecompiler.lib"
command = `ar rcs $libPath $objPaths`;
run(command);
nothing
