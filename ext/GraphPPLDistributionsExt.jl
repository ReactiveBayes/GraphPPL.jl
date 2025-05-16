module GraphPPLDistributionsExt

using GraphPPL, Distributions, Static

GraphPPL.get_node_behaviour(::GraphPPL.DefaultBackend, ::Type{<:Distributions.Distribution}) = GraphPPL.Stochastic()

function GraphPPL.get_default_parametrization(
    ::GraphPPL.DefaultBackend, ::GraphPPL.Atomic, t::Type{<:Distributions.Distribution}, interface_values::Tuple
)
    return distributions_ext_default_parametrization(t, distributions_ext_input_interfaces(t), interface_values)
end

function distributions_ext_default_parametrization(
    t::Type{<:Distributions.Distribution}, ::GraphPPL.StaticInterfaces{interfaces}, interface_values
) where {interfaces}
    if !(length(interface_values) == length(interfaces))
        error(lazy"Distribution $t has $(length(interfaces)) fields $(interfaces) but $(length(interface_values)) values were provided.")
    end
    return NamedTuple{interfaces}(interface_values)
end

function GraphPPL.get_interfaces(::GraphPPL.DefaultBackend, T::Type{<:Distributions.Distribution}, _)
    return distributions_ext_interfaces(T)
end

@generated function distributions_ext_input_interfaces(::Type{T}) where {T}
    fnames = fieldnames(T)
    return quote
        GraphPPL.StaticInterfaces(($(map(QuoteNode, fnames)...),))
    end
end

@generated function distributions_ext_interfaces(::Type{T}) where {T}
    fnames = fieldnames(T)
    return quote
        GraphPPL.StaticInterfaces((:out, $(map(QuoteNode, fnames)...)))
    end
end

# Special cases
GraphPPLDistributionsExt.distributions_ext_input_interfaces(::Type{<:Distributions.InverseWishart}) = GraphPPL.StaticInterfaces((:df, :Ψ))
GraphPPLDistributionsExt.distributions_ext_interfaces(::Type{<:Distributions.InverseWishart}) = GraphPPL.StaticInterfaces((:out, :df, :Ψ))

GraphPPLDistributionsExt.distributions_ext_input_interfaces(::Type{<:Distributions.Dirichlet}) = GraphPPL.StaticInterfaces((:α,))
GraphPPLDistributionsExt.distributions_ext_interfaces(::Type{<:Distributions.Dirichlet}) = GraphPPL.StaticInterfaces((:out, :α))

GraphPPLDistributionsExt.distributions_ext_input_interfaces(::Type{<:Distributions.Wishart}) = GraphPPL.StaticInterfaces((:df, :S))
GraphPPLDistributionsExt.distributions_ext_interfaces(::Type{<:Distributions.Wishart}) = GraphPPL.StaticInterfaces((:out, :df, :S))

GraphPPLDistributionsExt.distributions_ext_input_interfaces(::Type{<:Distributions.Categorical}) = GraphPPL.StaticInterfaces((:p,))
GraphPPLDistributionsExt.distributions_ext_interfaces(::Type{<:Distributions.Categorical}) = GraphPPL.StaticInterfaces((:out, :p))

end