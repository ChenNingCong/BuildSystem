# ../usr/bin/julia -t 1 -O 2 --image-codegen -L newTest.jl
include("testhelper.jl")
include("BuildSystem/include.jl")
load_object(objname::String) = ccall(:jl_compile_objects,Cvoid,(Any,),String[objname])
function load_object(objnames::Vector)
    retypearray = String[]
    for i in objnames
        if isa(i,String)
            push!(retypearray,i)
        else
            error("Not a string.")
        end
    end
    ccall(:jl_compile_objects,Cvoid,(Any,),retypearray)
end
ccall(:jl_staticjit_set_cache_geter,Cvoid,(Ptr{Nothing},),cglobal(:jl_simple_multijit))
ccall(:jl_set_get_cfunction_ptr,Cvoid,(Ptr{Nothing},),cglobal(:jl_get_spec_ptr))
ccall(:jl_set_debug_stream,Cvoid,(Any,), joinpath(pwd(),"objs/debug.csv"))
# inferred doesn't play well static compiler
macro inferred(x)
    return esc(x)
end
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
import JLLWrappers
import LazyArtifacts
import LibCURL
import LibGit2
import Libdl
import LinearAlgebra
import Logging
import Markdown
import Mmap
import Printf
import Profile
import REPL
import Random
import Random.shuffle
import RelocatableFolders
import SHA
import Scratch
import Serialization
import SharedArrays
import Sockets
import SparseArrays
import TOML
import Test
import UUIDs
import Unicode

setOutput() = ccall(:jl_setoutput_dir,Cvoid,(Any,), joinpath("/home/chenningcong/Documents/Code/StaticCompiler/julia/Parser/","objs"))
disableOutput()