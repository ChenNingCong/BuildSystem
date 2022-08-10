import Pkg
Pkg.activate(joinpath(@__DIR__, "../"))
using BuildSystem
const buildSysPath = splitdir(Base.find_package("BuildSystem"))[1]
const driverPath = abspath(joinpath(buildSysPath, "../test/buildDriver.jl"))
const rootDir = abspath(joinpath(buildSysPath, "../test/"))

const exePath = ENV["ju18exe"]::String
env = BuildEnv(joinpath(@__DIR__, "Project.toml"), rootDir, exePath, driverPath, joinpath(@__DIR__, "json.ninja"))

Pkg.activate(env.tomlPath)
setParameter!("empty.jl", "SJ_PRESERVENONRELOCATABLE", "true")
emptyResult = buildScript(env, "empty.jl", @__DIR__, "empty.jl", [])
setParameter!("test.jl", "SJ_WORLD", "Test")
setParameter!("test.jl", "SJ_PRESERVENONRELOCATABLE", "true")

testResult = buildScript(env, "test.jl", splitdir(BuildSystem.runtest("Test"))[1], "runtests.jl", Any[emptyResult])
setParameter!("pkg.jl", "SJ_PRESERVENONRELOCATABLE", "false")
pkgResult = buildScript(env, "pkg.jl", @__DIR__, "pkg.jl", Any[testResult])
gcCache!(env)

stdlibs = String["ArgTools" ,"Artifacts" ,"Base64" ,"CRC32c" ,"CompilerSupportLibraries_jll" ,
"Dates" ,"DelimitedFiles" ,"Distributed" ,"Downloads" ,"FileWatching" ,"Future" ,"GMP_jll" ,
"InteractiveUtils" ,"LLVMLibUnwind_jll" ,"LazyArtifacts" ,"LibCURL" ,"LibCURL_jll" ,"LibGit2" ,
"LibGit2_jll" ,"LibSSH2_jll" ,"LibUV_jll" ,"LibUnwind_jll" ,"Libdl" ,"LinearAlgebra" ,
"Logging" ,"MPFR_jll" ,"Markdown" ,"MbedTLS_jll" ,"Mmap" ,"MozillaCACerts_jll" ,"NetworkOptions" ,
"OpenBLAS_jll" ,"OpenLibm_jll" ,"PCRE2_jll" ,"Pkg" ,"Printf" ,"Profile" ,"REPL" ,"Random" ,"SHA" ,
"Serialization" ,"SharedArrays" ,"Sockets" ,"SparseArrays" ,"Statistics" ,"SuiteSparse" ,"SuiteSparse_jll" ,
"TOML" ,"Tar" ,"Test" ,"UUIDs" ,"Unicode" ,"Zlib_jll" ,"dSFMT_jll" ,"libLLVM_jll" ,"libblastrampoline_jll" ,
"nghttp2_jll" ,"p7zip_jll" ,"srccache"]
for i in stdlibs
    blackListLib(i)
end

BuildSystem.buildPkg(env, "JSON")

#=
setParameter!("LibGit2", "SJ_IGNORE_ERR", "true")
setParameter!("DocStringExtensions", "SJ_IGNORE_ERR", "true")
setParameter!("CodeTracking", "SJ_IGNORE_ERR", "true")
setParameter!("LoggingExtras", "SJ_IGNORE_ERR", "true")

blackListLib("TranscodingStreams")
blackListLib("MbedTLS")
blackListLib("SimpleBufferStream")
BuildSystem.buildPkg(env, "GR")

gcCache!(env)
=#