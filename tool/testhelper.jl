# This file is a helper to compile and invoke compiled code from staticjit.cpp
# I decide not to modify Julia's current codegen pipeline
# So we manually convert every function call to a ccall with the compiled function pointer (by function replace_call)
# This is fine since currently we only use this compiler to test object codegen. 
# To test the compiler, I simply reuse the test file from the package and convert the `@test` to compile function

# Global constant pool, refered in staticjit.cpp
# used to root constant value
const StringPool = Any[];
const SymbolPool = Any[];
const BitValuePool = Any[];
const TypePool = Any[]
# prevent get into type inference...
const MethodBlacklist = [which(Base.return_types,(Any,Any)),
which(Core.Compiler.return_type,(Any,Any,UInt64)),
which(Core.Compiler.return_type,(Core.Compiler.NativeInterpreter,Any,UInt64)),
which(Base.CoreLogging.handle_message,(Base.CoreLogging.NullLogger, Any, Any, Any, Any, Any, Any, Any)),
which(Base.Docs.doc!,(Module, Base.Docs.Binding, Base.Docs.DocStr, Any)),
which(Base.CoreLogging.env_override_minlevel,(Symbol, Module))]
const SharedString = "shared!";
ccall(:jl_set_restored_module_handle_setter,Cvoid,())
#
# Helper to get method instance for a function call
# 
import Core.Compiler: SimpleVector,normalize_typevars,get_compileable_sig,svec
import Base.getindex
function get_method_instances(@nospecialize(f), @nospecialize(t), world::UInt = Core.Compiler.typemax(UInt))
    if isa(f,Function)
        tt = Tuple{Core.typeof(f),t...}
    else
        tt = Tuple{Type{f},t...}
    end
    mi_matches = Core.Compiler._methods_by_ftype(tt, -1, world)
    if Core.Compiler.:(>=)(Core.Compiler.length(mi_matches),1)
        instance = Core.Compiler.specialize_method(Core.Compiler.getindex(mi_matches,1)#=MethodMatch=#)
        return instance
    else
        error("Not a unique match for $f with input type $t")
    end
end


function get_all_method_instances(@nospecialize(f), @nospecialize(t), world::UInt = Core.Compiler.typemax(UInt))
    if isa(f,Function)
        tt = Tuple{Core.typeof(f),t...}
    else
        tt = Tuple{Type{f},t...}
    end
    #results = Core.MethodInstance[]
    # _methods_by_ftype(fsign,method_num_limit,world)
    # return a vector of function that matches the function call
    # _methods_by_ftype also `jl_matching_methods` defined in `gf.c` 
    mi_matches = Core.Compiler._methods_by_ftype(tt, -1, world)
    instances = Core.Compiler.Array{Any,1}(Core.Compiler.undef, Core.Compiler.length(mi_matches))
    for i in 1:Core.Compiler.length(mi_matches)
        instances[i] = Core.Compiler.specialize_method(Core.Compiler.getindex(mi_matches,i))
    end
    return instances
end
#
#   A simple code lower procedure to lower function call to sinvoke
#
struct Failed end
# blacklist to filter out some functions we can't handle now
blacklist = [rand,isa,(===),typeof]

mutable struct LowerCtx
    id::Int
    result::Vector{Any}
    status::Bool
end
LowerCtx() = LowerCtx(0,[],true)
function simple_lower(expr)
    ctx = LowerCtx()
    simple_lower!(ctx,  expr)
    if ctx.status
        Expr(:block,ctx.result...)
    else
        expr
    end
end
function wrap_call(m,args...)
    if shouldBeBlacked(m)
        return m(args...)
    else
        argtyps = Any[]
        for i in args
            if i isa DataType
                tt = Type{i}
            else
                tt = typeof(i)
            end
            push!(argtyps, tt)
        end
        mi = get_method_instances(m,tuple(argtyps...)) 
        world = Base.get_world_counter()
        fptr = ccall(:jl_force_jit,Ptr{Nothing},(Any, UInt64), mi, world)
        arr = Any[args...]
        ptr = Base.unsafe_convert(Ptr{UInt8},arr)
        #print("Warning: we don't eval")
        mptr = ccall(:jl_value_ptr,Ptr{Cvoid},(Any,),m)
        return ccall(fptr,Any,(Ptr{Cvoid},Ptr{Cvoid},Int32),mptr,ptr,length(arr))
    end
end
function simple_lower!(ctx::LowerCtx, expr)
    if !ctx.status
        return :(nothing)
    end
    newname = gensym(string("v",ctx.id))
    ctx.id += 1
    local newexpr::Any
    if isa(expr, Expr)
        if expr.head == :call
            if string(expr.args[1])[1] == '.'
                ctx.status = false
                return :(nothing)
            end
            varnames = similar(expr.args,Symbol)
            for i in 1:length(expr.args)
                subexpr = expr.args[i]
                if isa(subexpr,Expr) && subexpr.head == :kw
                    ctx.status = false
                    return :(nothing)
                else
                    varnames[i]= simple_lower!(ctx, subexpr)
                end
            end
            body = Expr(:call, :wrap_call, varnames...)
            callexpr = Expr(:(=), newname, body)
            push!(ctx.result, callexpr)
        elseif expr.head == :(=)
            varnames = Symbol[]
            for i in 2:length(expr.args)
                push!(varnames, simple_lower!(ctx, expr.args[i]))
            end
            assignexpr = Expr(:(=), expr.args[1], varnames...)
            push!(ctx.result, assignexpr)
            # assign shouldn't have value...
        else
            newexpr = Expr(:(=), newname, expr)
            push!(ctx.result, newexpr)
        end
    else
        newexpr = Expr(:(=), newname, expr)
        push!(ctx.result, newexpr)
    end
    return newname
end

blacklist_set = String[
    "exp function",
    "exp10 function"
]
function shouldBeBlacked(m)
    if m in blacklist
        return true
    end
    return false
end
function shouldBeBlackedSet(name::String)
    return name in blacklist_set
end

#=
macro testset(name::String,expr)
    if shouldBeBlackedSet(name)
        return true
    end
    return Expr(:let,Expr(:block),Expr(:block,:(println($name))),:(Base.GC.gc()),esc(expr),:(Base.GC.gc()))
end

macro testset(expr)
    return esc(expr)
end

macro test_eval(expr)
    return expr
end


# currently we don't test error, since stack unwind is not implemented.
struct Pass
    value::Any
end
macro test_throws(err, expr)
    return Expr(:try, esc(expr), :e, Expr(:block, 
     Expr(:if, Expr(:call,:isa, :e, err),Expr(:call, :Pass, :e),Expr(:call, :error))))
end

macro test(expr)
    return quote
        #cond = $(esc(simple_lower(expr)))
        Base.GC.gc()
        println($(string(expr)))
        cond = $(esc(expr))
        Base.GC.gc()
        if !(cond)
            print("Failed: ")
            println($(string(expr)))
        end
    end
end
macro test(expr, exprs...)
    return true
end
macro inferred(expr)
    return esc(expr)
end

# sinvoke is a helper to invoke code by jl_invoke(*{}, **{}, int) api 
function sinvoke(f,args...)
    arr = Vector{Any}(Any[args...])
    argptr = ccall(:jl_array_ptr,Ptr{Cvoid},(Any,),arr)
    Base.GC.@preserve argptr begin
        ccall(f,Any,(Ptr{Cvoid},Ptr{Cvoid},Int32),C_NULL,argptr,length(arr))
    end
end


function test_typed(f,args)
    mi = get_method_instances(f,tuple(args...)) 
    world = Base.get_world_counter()
    fptr = ccall(:jl_force_jit,Ptr{Nothing},(Any, UInt64), mi, world)
end
macro test_typed(expr)
    @assert expr.head == :call
    f = expr.args[1]
    args = expr.args[2:end]
    return :(test_typed($f,$(Expr(:vect,args...))))
end
=#
ccall(:jl_init_staticjit,Cvoid,())