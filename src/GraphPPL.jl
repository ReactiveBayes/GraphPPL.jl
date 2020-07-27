module GraphPPL

using MacroTools
using Distributions
using InteractiveUtils: subtypes

# Graph
include("graph/node.jl")
include("graph/graph.jl")
include("graph/generate_nodes.jl")

# Compiler
include("compiler/model.jl")

end # module
