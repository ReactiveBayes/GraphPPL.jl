module GraphPPL

using MacroTools
using ForneyLab
using ForneyLab: generateId, SoftFactor, addNode!, associate!
using Distributions
using InteractiveUtils: subtypes
using ReactiveMP

const FFG = false
const REACTIVE = true

if FFG
    include("ffg-compiler/helpers.jl")
    include("ffg-compiler/variable.jl")
    include("ffg-compiler/generate_nodes.jl")
    include("ffg-compiler/ffg-model.jl")
elseif REACTIVE
    include("reactive-compiler/helpers.jl")
    include("reactive-compiler/variable.jl")
    include("reactive-compiler/generate_nodes.jl")
    include("reactive-compiler/reactive-model.jl")
end

end # module
