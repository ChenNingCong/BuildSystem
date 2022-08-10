
setOutput()
s = names(Core.Compiler, all=true)
l = [getfield(Core.Compiler, i) for i in s]
l = filter(x->isa(x,Function), l)
function collectMI!(d::Vector{Pair{Method, Vector{Core.MethodInstance}}}, i)
    t = methods(i)
    for i::Method in t
        if !(i.module == Core || i.module == Core.Compiler)
            continue
        end
        mis = Core.MethodInstance[]
        push!(d, (i=>mis))
        for k in eachindex(i.specializations)
            if isassigned(i.specializations, k) && i.specializations[k] != nothing
                push!(mis, i.specializations[k])
            end
        end
    end
end
function collectMI(v::Vector)
    d = Vector{Pair{Method, Vector{Core.MethodInstance}}}()
    for i in v
        collectMI!(d, i)
    end
    return d
end


function flat(o)
    k = Core.MethodInstance[]
    for (l, v) in o
        append!(k, v)
    end
    k
end
function unwrap_un_size(t)
    s = 0
    while isa(t, UnionAll)
        s += 1
        t = t.body
    end
    return s
end
function needSparams(mi::Core.MethodInstance)
    if isa(mi.def, Method)
        if unwrap_un_size(mi.def.sig) != length(mi.sparam_vals)
            return true
        else 
            for i in mi.sparam_vals
                if isa(i, TypeVar)
                    return true
                end
            end
        end
    end
    return false
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
end
mis = flat(collectMI(l))
for i in mis
    if needSparams(i)
        continue
    end
    #w = calculateWorld(i) 
    #if length(w) == 1 && w[1] == Core
        println(i)
        ccall(:jl_force_jit, UInt64, (Any, UInt64), i, Base.get_world_counter())
    #end
end
disableOutput()