readString(x) = read(x, String)
function jitLoad(m::Module, path::String)
    str  = open(readString, path)
    ccall(:jl_toplevel_eval_jit, Any, (Any,Any), m, Meta.parseall(str;filename=path))
end
jitLoad(path::String) = jitLoad(Main, path)
function jiteval(m::Module, s::String)
    ccall(:jl_toplevel_eval_jit, Any, (Any,Any), m, Meta.parseall(s;filename="REPL"))
end
jiteval(s::String) = jiteval(Main, s)
function jiteval(m::Module, e::Expr)
    if e.head != :toplevel
        e = Expr(:toplevel, e)
    end
    ccall(:jl_toplevel_eval_jit, Any, (Any,Any), m, e)
end
jiteval(e::Expr) = jiteval(Main, e)