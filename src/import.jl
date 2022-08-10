mutable struct ImportEnv
    # Pkg environment, used for activation
    tomlPath::String
    outputDir::String
    depGraph::Dict{String, Vector{String}}
    locations::Dict{String, String}
    function ImportEnv(tomlPath::String, outputDir::String)
        d = Pkg.dependencies()
        new(tomlPath, outputDir, constructDependency(d), collectPaths(d))
    end
end

function updateEnv!(env::ImportEnv)
    d = Pkg.dependencies()
    env.depGraph = constructDependency(d)
    env.locations = collectPaths(d)
    return env
end

const LOAD_CACHE_IMPORT_ENV =Set{String}([])

function loadDepsRecursively(env::ImportEnv, pkgName::String)::Bool
    if pkgName in LOAD_CACHE_IMPORT_ENV
        return true
    end
    push!(LOAD_CACHE_IMPORT_ENV, pkgName)
    l = env.locations[pkgName]
    p = hasProjectFile(l)
    if p !== nothing
        push!(Base.LOAD_PATH, p)
    end
    for i in env.depGraph[pkgName]
        loadDepsRecursively(env, i)
    end
    s = Symbol(pkgName)
    Core.eval(Main, :(import $s))
    succ = loadLib(env, pkgName, true)
    return succ
end

function loadPackageDeps(env::ImportEnv, pkgName::String)
    # println("Dep end loading")
    # load current package
    p = hasProjectFile(env.locations[pkgName])
    if p !== nothing
        push!(Base.LOAD_PATH, p)
    end
    for i in env.depGraph[pkgName]
        loadDepsRecursively(env, i)
    end
    s = Symbol(pkgName)
    Core.eval(Main, :(import $s))
    return
end

function loadPackage(env::ImportEnv, pkgName::String)
    return loadDepsRecursively(env, pkgName)
end

const LoadedLibs = Vector{String}()
function loadLibInternal(libPath::String, configPath::String)
    if !(libPath in LoadedLibs)
        #logMsg("Loading $(libPath)")
        ccall(:jl_add_static_libs, Cvoid, (Any,), [(libPath, configPath)])
        push!(LoadedLibs, libPath)
        #logMsg("Finish loading!")
    else
        #logMsg("$(libPath) is already loaded and cached!")
    end
end
const BinaryBlackedList = String[]
function blackListLib(libName::String)
    push!(BinaryBlackedList, libName)
end
@noinline function loadLib(env::ImportEnv, libName::String, isTry::Bool = false)::Bool
    if libName in BinaryBlackedList
        return false
    end
    libPath = joinpath(env.outputDir, libName *".lib")
    configPath = joinpath(env.outputDir,libName *".config")
    if isfile(libPath) && isfile(configPath)
        loadLibInternal(libPath, configPath)
        return true
    elseif !isTry
        #error("Unable to load library $(libName).lib")
        return false
    end
    return false
end

function tryLoadLib(env::ImportEnv, libName::String)
    loadLib(env, libName, true)
end


const isREPLSaved = Ref{Bool}(false)

function saveREPL(env::ImportEnv, libName::String, intermediateDir::String, UpAge::Vector{Symbol})
    if isREPLSaved[]
        error("REPL can only be saved once!")
    end
    isREPLSaved[] = true
    libPath = abspath(joinpath(env.outputDir, libName * ".lib"))
    info = Set{Any}(dumpGraph())
    info = removeNonRelocatale(info)
    freezeDependency(env, libName)
    ages = Set{Vector{Symbol}}()
    for i in info
        if i isa JITMethodInstance
            push!(ages, calculateWorld(i.mi))
        end
    end
    worlds = String[]
    for i in ages
        for j in i
            push!(worlds, string(j))
        end
    end
    unique!(worlds)
    println("Produced worlds : $worlds")
    legals::Set{Any} = filterUpperWorld(info, UpAge)
    writeConfig(abspath(joinpath(env.outputDir, libName * ".config")), legals)
    objPaths = String[]
    for i in info
        if i isa JITMethodInstance
            push!(objPaths, i.objectFilePath)
        end
    end
    command = `ar rcs $libPath $objPaths`;
    run(command);
    run(`/usr/bin/rm $intermediateDir -rf`)
    println("Finish saving REPL\n\n")
end