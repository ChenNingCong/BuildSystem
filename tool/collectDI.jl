import Pkg
function buildG(x)
    d = Dict{String, Set{String}}()
    for (_, v) in x
        d[v.name] = Set{String}(k for (k,l) in v.dependencies)
    end
    return d
end
function apply_recur(g::Function, d)
    finish = Set{String}()
    for (k, _) in d
        apply_topo(finish, g, d, k)
    end
end
    
function apply_topo(finish, g, d, k)
    if k in finish || isdefined(Main, Symbol(k))
        return
    end
    if haskey(d, k) && length(d[k]) > 0 
        for i in d[k]
            apply_topo(finish, g, d, i)
        end
    end
    g(k)
    push!(finish, k)
end
function applyToD(g, x)
    apply_recur(g, buildG(x))
end
function eee(x::String)
    jiteval(:(import $(Symbol(x))))
end
helper() = applyToD(eee, Pkg.dependencies())
#=
z = []
applyToD(Pkg.dependencies()) do x
    push!(z, x)
end
=#