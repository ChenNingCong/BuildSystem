# prevent get into type inference...
Core.eval(Base, :(function NamedTuple{names}(nt::NamedTuple) where {names}
    if @generated
        idx = Int[fieldindex(nt, names[n]) for n in 1:length(names)]
        types = Tuple{(fieldtype(nt, idx[n]) for n in 1:length(idx))...}
        Expr(:new, :(NamedTuple{names,$types}), Any[:(getfield(nt, $(idx[n]))) for n in 1:length(idx)]...)
    else
        types = Tuple{(fieldtype(typeof(nt), names[n]) for n in 1:length(names))...}
        NamedTuple{names,types}(map(Fix1(getfield, nt), names))
    end
end))

const StringPool = Any[];
const SymbolPool = Any[];
const BitValuePool = Any[];
const TypePool = Any[]
const MethodBlacklist = [which(Base.return_types, (Any, Any)),
    which(Core.Compiler.return_type, (Any, Any, UInt64)),
    which(Base.return_types, (Any, Any, Core.Compiler.NativeInterpreter)),
    which(Core.Compiler.typeinf, (Core.Compiler.NativeInterpreter, Core.Compiler.InferenceState)),
    which(Core.Compiler.typeinf_type, (Core.Compiler.NativeInterpreter, Method, Any, Core.SimpleVector)),
    which(Core.Compiler.return_type, (Core.Compiler.NativeInterpreter, Any, UInt64)),
    which(Base.CoreLogging.handle_message, (Base.CoreLogging.NullLogger, Any, Any, Any, Any, Any, Any, Any)),
    which(Base.Docs.doc!, (Module, Base.Docs.Binding, Base.Docs.DocStr, Any)),
    which(Base.CoreLogging.env_override_minlevel, (Symbol, Module))]

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

push!(Base.LOAD_PATH, abspath(joinpath(@__DIR__, "../Project.toml")))
using BuildSystem
pop!(Base.LOAD_PATH)

const OutputDir = ENV["SJ_OUTPUTDIR"]::String
const RootDir = joinpath(OutputDir, "../")
const RootProject = ENV["SJ_ROOT_PROJECT"]::String
const BuildDir = ENV["SJ_BUILDDIR"]::String
const IntermediateDir = ENV["SJ_INTERMEDIATEDIR"]::String
# loadLib before any complicated operation

# Step one : set the environment to the provided one root and get dependency graph
if RootProject != ""
    Base.ACTIVE_PROJECT[] = abspath(RootProject)
end
const __env__ = BuildSystem.ImportEnv(RootProject, OutputDir)

function jl_preload_handler(name::Symbol)
    BuildSystem.tryLoadLib(__env__, String(name))
    return
end

ccall(:jl_set_preload_binary_handler, Cvoid, ())
ccall(:jl_set_register_module_handle, Cvoid, ())
ccall(:jl_init_staticjit, Cvoid, (Any,), IntermediateDir)

BuildSystem.tryLoadLib(__env__, "empty.jl")

if !haskey(ENV, "SJ_ROOT_PROJECT")
    error("Build environment is not properly set up!")
end

if !isdir(IntermediateDir)
    mkpath(IntermediateDir)
end
const DebugStream = joinpath(IntermediateDir, "debug.csv")
if !isfile(DebugStream)
    touch(DebugStream)
end

const InputFiles = Vector{String}(split(ENV["SJ_INPUTS"], ';'))
const LibName = ENV["SJ_LIBNAME"]::String
const InputWorlds = map(Symbol, split(ENV["SJ_WORLD"], ';'))::Vector{Symbol}
const IgnoreErr = (ENV["SJ_IGNORE_ERR"] == "true")::Bool
const PreserveNonRelocatable = haskey(ENV, "SJ_PRESERVENONRELOCATABLE") && ENV["SJ_PRESERVENONRELOCATABLE"] == "true"

if haskey(ENV, "SJ_BLACKLIST")
    libs = ENV["SJ_BLACKLIST"]
    for i in split(libs, ';')
        BuildSystem.blackListLib(String(i))
    end
end

if LibName == "empty.jl"
else
    if LibName != "test.jl"
        libPath = joinpath(__env__.outputDir, "test.jl.lib")
        configPath = joinpath(__env__.outputDir, "test.jl.config")
        if isfile(libPath) && isfile(configPath)
            loadLib(__env__, "test.jl")
        end
    end
    # test needs some special handling ...
    BuildSystem.loadPackage(__env__, "Test")
    if LibName == "pkg.jl"
        BuildSystem.loadPackage(__env__, "Pkg")
    end
    if LibName != "test.jl" && LibName != "pkg.jl"
        libPath = joinpath(__env__.outputDir, "pkg.jl.lib")
        configPath = joinpath(__env__.outputDir, "pkg.jl.config")
        if isfile(libPath) && isfile(configPath)
            BuildSystem.loadPackage(__env__,"Pkg")
            loadLib(__env__, "pkg.jl")
        end
    end
end

const CompilationFlag = Ref{Bool}(false)
# triggering compilation
function triggerCompilation()
    if CompilationFlag[] # prevent optimization
        env = BuildSystem.ImportEnv("", "")
        BuildSystem.blackListLib("ABC")
        BuildSystem.tryLoadLib(env, "ABC")
        BuildSystem.loadPackage(env, "ABC")
        BuildSystem.loadPackageDeps(env, "ABC")
        BuildSystem.saveREPL(env, "","",Symbol[])
        loadLib(env, "ABC")
    end
end

ccall(:jl_staticjit_set_cache_geter, Cvoid, (Ptr{Nothing},), cglobal(:jl_simple_multijit))
ccall(:jl_set_get_cfunction_ptr, Cvoid, (Ptr{Nothing},), cglobal(:jl_get_spec_ptr))
ccall(:jl_set_debug_stream, Cvoid, (Any,), DebugStream)

if LibName == "empty.jl"
    Core.eval(Main, :(triggerCompilation()))
end

# This is a slow operation, so we place it here
if !endswith(LibName, ".jl") 
    BuildSystem.loadPackageDeps(__env__, LibName)
end

# after include the standard library, we import the test environment
# if it's a library, then we set up the environment by the copying the environment in the tested pkg
#=
const __test_env__ = if endswith(LibName, ".jl")
    __env__
else
    p = BuildSystem.hasProjectFile(__env__.locations[LibName])
    if p === nothing
        error("Package environment should exist here!")
    end
    # tmpProject = joinpath(@__DIR__, splitdir(p)[2])
    # cp(p, tmpProject;force=true)
    Base.ACTIVE_PROJECT[] = p
    BuildSystem.ImportEnv(p, OutputDir)
end
=#
println("Begin to tracing files :")
for i in InputFiles
    println("  ", i)
end
empty!(ARGS)
const ExtraTestDependency = String[]
if !endswith(LibName, "jl")
    pkgtoml = BuildSystem.hasProjectFile(__env__.locations[LibName])
    if pkgtoml === nothing
        error()
    end
    toml = Base.parsed_toml(pkgtoml)
    if haskey(toml, "extras")
        for (k, uuid) in toml["extras"]
            push!(ExtraTestDependency, k)
            Pkg.add(uuid = uuid)
        end
    end
end

BuildSystem.updateEnv!(__env__)
for i in ExtraTestDependency
    local pkgtoml = BuildSystem.hasProjectFile(__env__.locations[LibName])
    if pkgtoml === nothing
        error()
    end
    BuildSystem.loadPackage(__env__, i)
end

traceFiles(__env__, BuildDir, OutputDir, IntermediateDir, InputFiles, LibName, InputWorlds, PreserveNonRelocatable, IgnoreErr)
