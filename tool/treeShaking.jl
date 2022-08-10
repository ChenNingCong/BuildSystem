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
mis = filter(mis) do f
    f.def.module != Core || f.def.module != Core.Compiler
end
