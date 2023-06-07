export MeanField, FullFactorization
struct MeanField end

struct FullFactorization end

"""
    IndexedVariable

`IndexedVariable` represents a variable with index in factorisation specification language. An IndexedVariable is generally part of a vector or tensor of random variables.
"""
struct IndexedVariable
    variable::Symbol
    index::AbstractArray{T} where {T<:Int}
end

"""
    CombinedRange{L, R}

`CombinedRange` represents a range of combined variable in factorisation specification language. Such variables specified to be in the same factorisation cluster.

See also: [`GraphPPL.SplittedRange`](@ref)
"""
struct CombinedRange{L, R}
    from :: L
    to   :: R
end

Base.firstindex(range::CombinedRange) = range.from
Base.lastindex(range::CombinedRange)  = range.to
Base.in(item, range::CombinedRange)   = firstindex(range) <= item <= lastindex(range)

Base.show(io::IO, range::CombinedRange) = print(io, repr(range.from), ":", repr(range.to))

"""
    SplittedRange{L, R}

`SplittedRange` represents a range of splitted variable in factorisation specification language. Such variables specified to be **not** in the same factorisation cluster.

See also: [`GraphPPL.CombinedRange`](@ref)
"""
struct SplittedRange{L, R}
    from :: L
    to   :: R
end

is_splitted(any)                  = false
is_splitted(range::SplittedRange) = true

Base.firstindex(range::SplittedRange) = range.from
Base.lastindex(range::SplittedRange)  = range.to
Base.in(item, range::SplittedRange)   = firstindex(range) <= item <= lastindex(range)

Base.show(io::IO, range::SplittedRange) = print(io, repr(range.from), "..", repr(range.to))

struct FactorizationConstraint{V,F}
    variables::V
    constraint::F
end

struct FunctionalFormConstraint{V,F}
    variables::V
    constraint::F
end

const MaterializedConstraints = Union{FactorizationConstraint,FunctionalFormConstraint}

variables(c::MaterializedConstraints) = c.variables
constraint_data(c::MaterializedConstraints) = c.constraint


struct GeneralSubModelConstraints
    fform::Function
    constraints::Any
end

struct SpecificSubModelConstraints
    tag::Symbol
    constraints::Any
end

const Constraint = Union{
    FactorizationConstraint,
    FunctionalFormConstraint,
    GeneralSubModelConstraints,
    SpecificSubModelConstraints,
}
const Constraints = Vector{Constraint}



SubModelConstraints(x::Symbol, constraints::Constraints) =
    SpecificSubModelConstraints(x, constraints)
SubModelConstraints(fform::Function, constraints::Constraints) =
    GeneralSubModelConstraints(fform, constraints)

function throw_var_not_defined(context::Context, variable::Symbol)
    if !(
        haskey(context.individual_variables, variable) ||
        haskey(context.vector_variables, variable) ||
        haskey(context.tensor_variables, variable)
    )
        error(lazy"Variable $variable does not exist in context")
    end
end

function throw_var_not_defined(context::Context, variable::IndexedVariable)
    if !(
        haskey(context.vector_variables, variable.variable) ||
        haskey(context.tensor_variables, variable.variable)
    )
        error(lazy"Variable $variable does not exist in context")
    end
end

throw_var_not_defined(
    context::Context,
    variables::NTuple{N,Union{Symbol,IndexedVariable}} where {N},
) = throw_var_not_defined.(Ref(context), variables)


function find_applicable_nodes(
    model::Model,
    context::Context,
    constraint::FactorizationConstraint{V,F},
) where {V,F<:Tuple}
    applicable_nodes = intersect(
        GraphPPL.neighbors.(
            Ref(model),
            vec.(_get_from_context.(Ref(context), constraint.variables)),
        )...,
    )
    return applicable_nodes
end


function find_applicable_nodes(
    model::Model,
    context::Context,
    constraint::FunctionalFormConstraint,
)
    return vec(_get_from_context(context, constraint.variables))
end

_get_from_context(context::Context, variable::Symbol) = context[variable]
_get_from_context(context::Context, variable::IndexedVariable) =
    context[variable.variable][variable.index...]


in_neighbors(neighbors::AbstractArray, node::NodeLabel) =
    node ∈ neighbors ? NodeLabel[node] : NodeLabel[]
in_neighbors(neighbors::AbstractArray, node::ResizableArray) =
    intersect!(vec(node), neighbors)

convert_to_edge_names(
    fct,
    neighbors::AbstractArray{T} where {T<:NodeLabel},
    context::Context,
) = in_neighbors(neighbors, _get_from_context(context, fct))

function factorization_constraint_to_bitset(neighbors::AbstractArray, constraint::Tuple)
    integer_constraint = map(factor -> map(dst -> findfirst(dst .== neighbors), factor), constraint)  #convert all constraint statements to integers, this might be faster with a mapping dictionary.
    constraint_sets = BitSet.(integer_constraint)
    for node = 1:length(neighbors)
        if !any(node .∈ constraint_sets)
            push!.(constraint_sets, node)
        end
    end
    result = map(
        node -> union(constraint_sets[findall(node .∈ constraint_sets)]...),
        1:length(neighbors),
    )
    return result
end
function apply!(model::Model, constraints::Constraints)
    apply!(model, context(model), constraints)
    materialize_constraints!(model)
end

function apply!(model::Model, context::Context, constraints::Constraints)
    for constraint in constraints
        apply!(model, context, constraint)
    end
end

function apply!(model::Model, context::Context, constraint::GeneralSubModelConstraints)
    for (_, factor_context) in context.factor_nodes
        if isdefined(factor_context, :fform)
            if factor_context.fform == constraint.fform
                apply!(model, factor_context, constraint.constraints)
            end
        end
    end
end

function apply!(model::Model, context::Context, constraint::SpecificSubModelConstraints)
    for (tag, factor_context) in context.factor_nodes
        if tag == constraint.tag
            apply!(model, factor_context, constraint.constraints)
        end
    end
end


function apply!(model::Model, context::Context, constraint::MaterializedConstraints)
    throw_var_not_defined(context, variables(constraint))
    applicable_nodes = find_applicable_nodes(model, context, constraint)
    if length(applicable_nodes) == 0
        @warn "No applicable nodes found for constraint $constraint"
        return
    end
    apply!(model, context, applicable_nodes, constraint)
end


function apply!(
    model::Model,
    context::Context,
    applicable_nodes::AbstractArray{T},
    constraint::FactorizationConstraint,
) where {T<:NodeLabel}
    for node in applicable_nodes
        @show constraint
        
        apply!(model, context, node, constraint)
    end
end

function apply!(
    model::Model,
    context::Context,
    node::NodeLabel,
    c::FactorizationConstraint{V,F},
) where {V,F<:Tuple}
    @show c
    neighbors = GraphPPL.neighbors(model, node)
    constraint_variables = map(
        factors -> collect(
            Iterators.flatten(
                map(factor -> convert_to_edge_names(factor, neighbors, context), factors),
            ),
        ),
        c.constraint,
    )
    @show constraint_variables
    constraint_bitset = factorization_constraint_to_bitset(neighbors, constraint_variables)
    model[node].options[:q] = intersect.(model[node].options[:q], constraint_bitset)
end

function apply!(model::Model, context::Context, node::NodeLabel, c::FactorizationConstraint{V, F}) where {V, F<:MeanField}
    model[node].options[:q] = Tuple(map(edge -> (edge,), GraphPPL.edges(model, node)))
end

function apply!(model::Model, context::Context, node::NodeLabel, c::FactorizationConstraint{V, F}) where {V, F<:FullFactorization}
    model[node].options[:q] = (Tuple(GraphPPL.edges(model, node)),)
end


function apply!(
    model::Model,
    context::Context,
    nodes::AbstractArray{T},
    constraint::FunctionalFormConstraint,
) where {T}
    for node in nodes
        _store_constraint_data!(model, node, constraint_data(constraint), constraint)
    end
end

function materialize_constraints!(model::Model)
    for node in GraphPPL.vertices(model)
        materialize_constraints!(model, label_for(model.graph, node))
    end
end

materialize_constraints!(model::Model, node::NodeLabel) =
    materialize_constraints!(model, node, model[node])

materialize_constraints!(model::Model, node_label::NodeLabel, node_data::VariableNodeData) =
    nothing

function materialize_constraints!(
    model::Model,
    node_label::NodeLabel,
    node_data::FactorNodeData,
)

    constraint_set = Set(node_options(node_data)[:q]) #TODO test `unique``
    edges = GraphPPL.edges(model, node_label)
    constraint = Tuple(constraint_set)
    constraint = map(factors -> Tuple(getindex.(Ref(edges), factors)), constraint)
    if !is_valid_partition(constraint_set)
        error(
            lazy"Factorization constraint set at node $node_label is not a valid constraint set. Please check your model definition and constraint specification. (Constraint set: $constraint)",
        )
        return
    end
    node_data.options[:q] = constraint
end

function is_valid_partition(set::Set)
    max_element = maximum(Iterators.flatten(set))
    if !issetequal(union(set...), BitSet(1:max_element))
        return false
    end
    for element = 1:max_element
        if !(sum(element .∈ set) == 1)
            return false
        end
    end
    return true
end
