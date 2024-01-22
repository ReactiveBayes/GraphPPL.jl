module GraphPPL

using MacroTools

include("resizable_array.jl")
include("plugins_engine.jl")
include("graph_engine.jl")
include("model_macro.jl")

# include("meta_engine.jl")
# include("meta_macro.jl")

include("plugins/node_created_by.jl")
include("plugins/variational_constraints/constraints.jl")

include("old/old.jl")

end # module
