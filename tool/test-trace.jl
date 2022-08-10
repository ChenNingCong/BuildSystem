
setOutput()
disableOutput()
Core.eval(Base,:(function NamedTuple{names}(nt::NamedTuple) where {names}
if @generated
    idx = Int[ fieldindex(nt, names[n]) for n in 1:length(names) ]
    types = Tuple{(fieldtype(nt, idx[n]) for n in 1:length(idx))...}
    Expr(:new, :(NamedTuple{names, $types}), Any[ :(getfield(nt, $(idx[n]))) for n in 1:length(idx) ]...)
else
    types = Tuple{(fieldtype(typeof(nt), names[n]) for n in 1:length(names))...}
    NamedTuple{names, types}(map(Fix1(getfield, nt), names))
end
end))
if length(Base.ARGS) != 1
    s = open(x->read(x,String), "commute")
    p = splitdir(s)[1]
    cd(p)
    path = splitdir(s)[2]
elseif length(Base.ARGS) == 1
    cd("../../test/")
    path = Base.ARGS[1]
else
end
using Test
module Main_test
    const __private_jit_include_path__ = Main.path
    import Main.@inferred
    using Test
    include("../../test/jithelper.jl")
end

