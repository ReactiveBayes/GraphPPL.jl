module GraphPPL

using MacroTools

include("resizable_array.jl")
include("plugins_collection.jl")

include("graph_engine.jl")
include("model_macro.jl")

include("plugins/node_created_by.jl")
include("plugins/variational_constraints/variational_constraints.jl")
include("plugins/meta/meta.jl")

include("old/old.jl")

end # module
