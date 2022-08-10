function calculateWorld(v::Any)
    arr = Any[]
    ccall(:jl_calculate_world, Cvoid, (Any, Any), arr, v)
    return Vector{Symbol}(arr)
end

function cmpWorld(m1, m2)
    s1 = Symbol(string(m1)) 
    s2 = Symbol(string(m2))
    rt = ccall(:jl_compare_world, Int32, (Any, Any), s1, s2)
    rts = ("Wrong", "Smaller", "Eq", "Larger", "Uncomparable")
    return rts[rt+3]
end

function isWorldLessEqThan(s1::Symbol, s2::Symbol)
    rt = ccall(:jl_compare_world, Int32, (Any, Any), s1, s2)
    return rt == 0 || rt == -1
end
function isWorldLessEqThan(s1::Vector{Symbol}, s2::Vector{Symbol})
    for i in s1
        for j in s2
            if !isWorldLessEqThan(i,j)
                return false
            end
        end
    end
    return true
end