module GraphPPL

using MacroTools

include("resizable_array.jl")
include("plugins_collection.jl")

include("graph_engine.jl")
include("model_generator.jl")
include("model_macro.jl")

include("plugins/node_created_by.jl")
include("plugins/node_id.jl")
include("plugins/variational_constraints/variational_constraints.jl")
include("plugins/meta/meta.jl")

include("backends/default.jl")

"""
    @model function model_name(model_arguments)
        ...
    end

Note that the `@model` macro is not exported by default and the recommended way of using it is 
in the combination with some inference backend. The `GraphPPL` package provides the `DefaultGraphPPLBackend` structure 
for plotting and test purposes, but some backends may specify different behaviour for different structures. For example,
the interface names of a node `Normal` or its behaviour may (and should) depend on the specified backend. 

The recommended way of using the `GraphPPL.@model` macro from other backend-based packages is to define their own 
`@model` macro, which will call the `GraphPPL.model_macro_interior` function with the specified backend. For example 

```julia
module SamplingBasedInference

struct SamplingBasedBackend end

macro model(model_specification)
    return esc(GraphPPL.model_macro_interior(SamplingBasedBackend(), model_specification))
end

end
```

Read more about the backend inteface in the corresponding section of the documentation.

To use `GraphPPL` package as a standalone package for plotting and testing, use the `import GraphPPL: @model` explicitly to add 
the `@model` macro to the current scope. 
"""
macro model(model_specification)
    return esc(GraphPPL.model_macro_interior(DefaultBackend, model_specification))
end

function __init__()
    if isdefined(Base.Experimental, :register_error_hint)
        Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
            if any(x -> x <: VariableRef, argtypes)
                print(io, "\nOne of the arguments to ")
                printstyled(io, "`$(exc.f)`", color = :cyan)
                print(io, " is of type ")
                printstyled(io, "`GraphPPL.VariableRef`", color = :cyan)
                print(io, ". Did you mean to create a new random variable with ")
                printstyled(io, "`:=`", color = :cyan)
                print(io, " operator instead?")
            end
        end
    end
end

end # module
