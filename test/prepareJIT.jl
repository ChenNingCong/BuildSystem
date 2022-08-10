# prevent get into type inference...
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

const StringPool = Any[];
const SymbolPool = Any[];
const BitValuePool = Any[];
const TypePool = Any[]
const MethodBlacklist = [which(Base.return_types,(Any,Any)),
which(Core.Compiler.return_type,(Any,Any,UInt64)),
which(Base.return_types,(Any, Any, Core.Compiler.NativeInterpreter)),
which(Core.Compiler.typeinf,(Core.Compiler.NativeInterpreter, Core.Compiler.InferenceState)),
which(Core.Compiler.typeinf_type,(Core.Compiler.NativeInterpreter, Method, Any, Core.SimpleVector)),
which(Core.Compiler.return_type,(Core.Compiler.NativeInterpreter,Any,UInt64)),
which(Base.CoreLogging.handle_message,(Base.CoreLogging.NullLogger, Any, Any, Any, Any, Any, Any, Any)),
which(Base.Docs.doc!,(Module, Base.Docs.Binding, Base.Docs.DocStr, Any)),
which(Base.CoreLogging.env_override_minlevel,(Symbol, Module))]

# special handling to load REPL, since it's not dependencies of many packages
import InteractiveUtils.@which
import InteractiveUtils.@code_lowered
import InteractiveUtils.@code_typed
import ArgTools
import Artifacts
import Base64
import CRC32c
import Dates
import DelimitedFiles
import Distributed
import Downloads
import FileWatching
import Future
import InteractiveUtils
import LazyArtifacts
import LibCURL
import LibGit2
import Libdl
import LinearAlgebra
import Logging
import Markdown
import Mmap
import NetworkOptions
import Pkg
import Printf
import Profile
import REPL
import Random
import SHA
import Serialization
import SharedArrays
import Sockets
import SparseArrays
import Statistics
import SuiteSparse
import TOML
import Tar
import Test
import UUIDs
import Unicode
import InteractiveUtils.@which
import InteractiveUtils.@code_lowered
import InteractiveUtils.@code_typed

const OutputDir = joinpath(@__DIR__, "binary")
import Dates
const LibName = "repl@$(Dates.now())"
const IntermediateDir = joinpath(joinpath(@__DIR__, "cache/"), LibName)
const DebugStream = joinpath(IntermediateDir, "debug.csv")
if !isdir(IntermediateDir)
    mkdir(IntermediateDir)
end
if !isfile(DebugStream)
    touch(DebugStream)
end
push!(Base.LOAD_PATH, abspath(joinpath(@__DIR__, "../Project.toml")))
using BuildSystem
pop!(Base.LOAD_PATH)
RootProject = abspath(joinpath(@__DIR__, "./Project.toml"))
Base.ACTIVE_PROJECT[] = RootProject
const env = BuildSystem.ImportEnv(RootProject, OutputDir)
function jl_preload_handler(name::Symbol)
    BuildSystem.tryLoadLib(env, String(name))
    return
end
ccall(:jl_set_preload_binary_handler, Cvoid, ())
ccall(:jl_set_register_module_handle, Cvoid, ())
ccall(:jl_init_staticjit,Cvoid,(Any,), IntermediateDir)

macro use(pkg::Union{Symbol, String})
    RootProject = Base.active_project()
    env = BuildSystem.ImportEnv(RootProject, OutputDir)
    if pkg isa String
        return :(BuildSystem.tryLoadLib($env, $(QuoteNode(pkg))))
    else
        return :(BuildSystem.loadPackage($env, $(String(pkg))))
    end
end

macro useall()
    return quote
        RootProject = Base.active_project()
        env = BuildSystem.ImportEnv(RootProject, OutputDir)
        for (k, v) in env.locations
            BuildSystem.loadPackage(env, k)
        end
        loadREPL()
    end
end

prelibs = ["empty.jl", "test.jl", "pkg.jl"]
for i in prelibs
    if i == "pkg.jl"
        BuildSystem.loadPackage(env,"Pkg")
    end
    BuildSystem.tryLoadLib(env, i)
end

ccall(:jl_staticjit_set_cache_geter,Cvoid,(Ptr{Nothing},),cglobal(:jl_simple_multijit))
ccall(:jl_set_get_cfunction_ptr,Cvoid,(Ptr{Nothing},),cglobal(:jl_get_spec_ptr))
ccall(:jl_set_debug_stream, Cvoid, (Any,), DebugStream)
function saveWork(UpAge::Vector{Symbol})
    RootProject = Base.active_project()
    Base.ACTIVE_PROJECT[] = abspath(RootProject)
    env = BuildSystem.ImportEnv(RootProject, OutputDir)
    BuildSystem.saveREPL(env, "__repl__.jl", IntermediateDir, UpAge)
end

function saveEmptyREPL(UpAge::Vector{Symbol})
    RootProject = Base.active_project()
    Base.ACTIVE_PROJECT[] = abspath(RootProject)
    env = BuildSystem.ImportEnv(RootProject, OutputDir)
    BuildSystem.saveREPL(env, "__empty__repl.jl", IntermediateDir, UpAge)
end

function loadREPL()
    RootProject = Base.active_project()
    env = BuildSystem.ImportEnv(RootProject, OutputDir)
    BuildSystem.tryLoadLib(env, "__repl__.jl")
end
import REPL
#BuildSystem.tryLoadLib(env, "__empty__repl")