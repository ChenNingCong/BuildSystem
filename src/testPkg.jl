function testOnePkg(pkgtoml::String)
    toml = Base.parsed_toml(pkgtoml)
    deps = Vector{String}()
    if haskey(toml, "deps")
        for (k, _) in pkgtoml["dep"]
            push!(deps, k)
        end
    end
    if haskey(toml, "extras")
        for (k, _) in pkgtoml["extras"]
            push!(deps, k)
        end
    end
    unique!(deps)
end