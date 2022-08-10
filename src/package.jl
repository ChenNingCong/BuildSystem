import Pkg
function collectPaths(d)
    result = Dict{String, String}()
    for (_, info) in d
        result[info.name] = info.source
    end
    return result
end
function constructDependency(d)
    result = Dict{String, Vector{String}}()
    for (uuid, info) in d
        dep = info.dependencies
        names = [name for (name, uuid) in dep]
        result[info.name] = names
    end
    return result
end

function runtest(arg::String)
    # We look through current environment and get the source code location
    srcpath = splitdir(Base.find_package(arg))[1]
    # package/src/X.jl 
    testpath = joinpath(srcpath, "../test/runtests.jl")
    if !isfile(testpath)
        # package/X.jl
        println(testpath)
        testpath = joinpath(srcpath, "../test/runtests.jl")
        if !isfile(testpath)
            println(testpath)
            return testpath
        end
    end
    return testpath
end

function hasProjectFile(rootPath::String)
    for proj in Base.project_names
        maybe_project_file = joinpath(rootPath, proj)
        if Base.isfile_casesensitive(maybe_project_file)
            return maybe_project_file
        end
    end
    return nothing
end

# can also be used for script ...
struct PkgParameter
    perPkgParameter::Dict{String, Dict{String, String}}
    allParameter::Vector{Pair{String, String}}
    function PkgParameter()
        return new(Dict{String, Dict{String, String}}(),[])
    end
end

const GlobalOverwriteParameter = PkgParameter()
function setParameter!(pkg::String, k::String, v::String)
    if !haskey(GlobalOverwriteParameter.perPkgParameter, pkg)
        GlobalOverwriteParameter.perPkgParameter[pkg] = Dict{String, String}()
    end
    GlobalOverwriteParameter.perPkgParameter[pkg][k] = v
end

function setAllParameter!(k::String, v::String)
    push!(GlobalOverwriteParameter.allParameter, k=>v)
end

function applyOverwrite!(pkg::String, old::Dict{String, String}, param::PkgParameter)
    # firstly we apply the all parameter
    # then we apply per package parameter
    for (k, v) in param.allParameter
        old[k] = v
    end
    if haskey(param.perPkgParameter, pkg)
        for (k, v) in param.perPkgParameter[pkg]
            old[k] = v
        end
    end
end

function buildPkg(env::BuildEnv, pkgName::String)
    d = Pkg.dependencies()
    depGraph = constructDependency(d)
    locations = collectPaths(d)
    buildPkgRecursively(env, pkgName, depGraph, locations)
end

function buildPkgRecursively(env::BuildEnv, pkgName::String, depGraph::Dict{String, Vector{String}}, locations)::Union{TraceResult, Nothing}
    if pkgName in BinaryBlackedList
        return
    end
    depsResult = Any[]
    for i in depGraph[pkgName]
        r = buildPkgRecursively(env, i, depGraph, locations)
        if r !== nothing
            push!(depsResult, r)
        end
    end
    println("Tracing recursively : $pkgName")
    rootPath = locations[pkgName]
    maybeFile = hasProjectFile(rootPath)
    println(rootPath)
    if maybeFile === nothing
        error("$pkgName has not project file")
    end
    defaultParameter = Dict{String, String}(
                                      "SJ_BUILDDIR"=>joinpath(locations[pkgName], "test"),
                                      "SJ_PRESERVENONRELOCATABLE" => "false",
                                      "SJ_WORLD"=>pkgName,
                                      "SJ_IGNORE_ERR"=>"false",
                                      "SJ_BLACKLIST"=>"REPL")
    applyOverwrite!(pkgName, defaultParameter, GlobalOverwriteParameter)
    return tracePkg(env, pkgName, Vector{String}(["runtests.jl"]), depsResult, defaultParameter)
end

function buildScript(env::BuildEnv, pkgName::String, scriptDir::String, scriptName::String, deps::Vector{BuildResult})
    defaultParameter = Dict{String, String}(
        "SJ_BUILDDIR"=>scriptDir,
        "SJ_PRESERVENONRELOCATABLE" => "false",
        "SJ_WORLD"=>"Main",
        "SJ_IGNORE_ERR"=>"false",
        "SJ_BLACKLIST"=>"REPL")
    applyOverwrite!(pkgName, defaultParameter, GlobalOverwriteParameter)
    return tracePkg(env, pkgName, Vector{String}([scriptName]), deps, defaultParameter)
end
