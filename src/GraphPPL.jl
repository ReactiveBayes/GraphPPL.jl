module GraphPPL

using MacroTools
using ForneyLab
using ForneyLab: generateId, SoftFactor, addNode!, associate!
using Distributions
using InteractiveUtils: subtypes

const FFG = true

if FFG
    include("ffg-compiler/variable.jl")
    include("ffg-compiler/generate_nodes.jl")
    include("ffg-compiler/ffg-model.jl")
else
    # Compiler
    include("compiler/model.jl")

    # Graph
    include("graph/node.jl")
    include("graph/graph.jl")
    include("graph/generate_nodes.jl")
end

end # module
