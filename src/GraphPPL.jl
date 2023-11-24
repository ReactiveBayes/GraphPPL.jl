module GraphPPL

using MacroTools

include("resizable_array.jl")
include("indexedvariable.jl")
include("graph_engine.jl")
include("model_macro.jl")
include("constraints_engine.jl")
include("constraints_macro.jl")
include("meta_engine.jl")
include("meta_macro.jl")

include("old/old.jl")

end # module
