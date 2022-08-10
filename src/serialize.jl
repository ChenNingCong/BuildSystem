struct JITMethodInstance
    mi::Core.MethodInstance
    miName::String
    dependencies::Vector{Any}
    isRelocatable::Bool
    symbolTable::Vector{Any}
    unOptIRFilePath::String
    optIRFilePath::String
    objectFilePath::String
end

struct CachedMethodInstance
    miName::String
    libName::String
    objName::String
end

struct PluginMethodInstance
    miName::String
    pluginName::String
end
