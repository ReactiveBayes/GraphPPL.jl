module GraphPPL

using MacroTools

include("backends/reactivemp.jl")

__get_current_backend() = ReactiveMPBackend()

include("utils.jl")
include("model.jl")
include("constraints.jl")
include("meta.jl")

end # module
