module GraphPPLDistributionsExt
using GraphPPL, Distributions

GraphPPL.NodeBehaviour(::Type{<:Distributions.Distribution}) = GraphPPL.Stochastic()
function GraphPPL.rhs_to_named_tuple(::GraphPPL.Atomic, t::Type{<:Distributions.Distribution}, interface_values) 
    field_names = fieldnames(t)
    @assert length(interface_values) == length(field_names) "Distribution $t has $(length(field_names)) fields $(field_names) but $(length(interface_values)) values were provided."
    return NamedTuple{fieldnames(t)}(interface_values)
end
GraphPPL.interfaces(t::Type{<:Distributions.Distribution}, val) = (:out, fieldnames(t)...)

end