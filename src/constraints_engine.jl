export MeanField, FullFactorization

using StaticArrays
using Unrolled
# import Base: +, ==, *, firstindex, lastindex, in

struct MeanField end

struct FullFactorization end

"""
    FunctionalIndex

A special type of an index that represents a function that can be used only in pair with a collection. 
An example of a `FunctionalIndex` can be `firstindex` or `lastindex`, but more complex use cases are possible too, 
e.g. `firstindex + 1`. Important part of the implementation is that the resulting structure is `isbitstype(...) = true`, that allows to store it in parametric type as valtype.

One use case for this structure is to dispatch on and to replace `begin` or `end` (or more complex use cases, e.g. `begin + 1`) markers in constraints specification language.
"""
struct FunctionalIndex{R,F}
    f::F

    FunctionalIndex{R}(f::F) where {R,F} = new{R,F}(f)
end

(index::FunctionalIndex{R,F})(collection) where {R,F} =
    __functional_index_apply(R, index.f, collection)::Integer

__functional_index_apply(::Symbol, f, collection) = f(collection)
__functional_index_apply(
    subindex::FunctionalIndex,
    f::Tuple{typeof(+),<:Integer},
    collection,
) = subindex(collection) .+ f[2]
__functional_index_apply(
    subindex::FunctionalIndex,
    f::Tuple{typeof(-),<:Integer},
    collection,
) = subindex(collection) .- f[2]

Base.:(+)(left::FunctionalIndex, index::Integer) = FunctionalIndex{left}((+, index))
Base.:(-)(left::FunctionalIndex, index::Integer) = FunctionalIndex{left}((-, index))

__functional_index_print(io::IO, f::typeof(firstindex)) = nothing
__functional_index_print(io::IO, f::typeof(lastindex)) = nothing
__functional_index_print(io::IO, f::Tuple{typeof(+),<:Integer}) = print(io, " + ", f[2])
__functional_index_print(io::IO, f::Tuple{typeof(-),<:Integer}) = print(io, " - ", f[2])

function Base.show(io::IO, index::FunctionalIndex{R,F}) where {R,F}
    print(io, "(")
    print(io, R)
    __functional_index_print(io, index.f)
    print(io, ")")
end


"""
    IndexedVariable

`IndexedVariable` represents a variable with index in factorization specification language. An IndexedVariable is generally part of a vector or tensor of random variables.
"""
struct IndexedVariable{T}
    variable::Symbol
    index::T
end

Base.length(index::IndexedVariable{T} where T) = 1
Base.iterate(index::IndexedVariable{T} where T) = (index, nothing)
Base.iterate(index::IndexedVariable{T} where T, any) = nothing
getvariable(index::IndexedVariable) = index.variable

Base.getindex(context::Context, index::IndexedVariable{Nothing}) = context[index.variable]
Base.getindex(context::Context, index::IndexedVariable) =
    context[index.variable][index.index]

Base.:(==)(left::IndexedVariable, right::IndexedVariable) =
    (left.variable == right.variable && left.index == right.index)

Base.show(io::IO, variable::IndexedVariable{Nothing}) = print(io, variable.variable)
Base.show(io::IO, variable::IndexedVariable) =
    print(io, variable.variable, "[", variable.index, "]")

"""
    CombinedRange{L, R}

`CombinedRange` represents a range of combined variable in factorization specification language. Such variables specified to be in the same factorization cluster.

See also: [`GraphPPL.SplittedRange`](@ref)
"""
struct CombinedRange{L,R}
    from::L
    to::R
end

Base.firstindex(range::CombinedRange) = range.from
Base.lastindex(range::CombinedRange) = range.to
Base.in(item, range::CombinedRange) = firstindex(range) <= item <= lastindex(range)
Base.length(range::CombinedRange) = lastindex(range) - firstindex(range) + 1

Base.show(io::IO, range::CombinedRange) = print(io, repr(range.from), ":", repr(range.to))

"""
    SplittedRange{L, R}

`SplittedRange` represents a range of splitted variable in factorization specification language. Such variables specified to be **not** in the same factorization cluster.

See also: [`GraphPPL.CombinedRange`](@ref)
"""
struct SplittedRange
    from::Any
    to::Any
end

is_splitted(any) = false
is_splitted(range::SplittedRange) = true

Base.firstindex(range::SplittedRange) = range.from
Base.lastindex(range::SplittedRange) = range.to
Base.in(item, range::SplittedRange) = firstindex(range) <= item <= lastindex(range)
Base.length(range::SplittedRange) = lastindex(range) - firstindex(range) + 1

Base.show(io::IO, range::SplittedRange) = print(io, repr(range.from), "..", repr(range.to))



"""
    __factorization_specification_resolve_index(index, collection)

This function materializes index from constraints specification to something we can use `Base.in` function to. For example constraint specification index may return `begin` or `end`
placeholders in a form of the `FunctionalIndex` structure. This function correctly resolves all indices and check bounds as an extra step.
"""
function __factorization_specification_resolve_index end

__factorization_specification_resolve_index(index::Any, collection::NodeLabel) =
    error("Attempt to access a single variable $(name(collection)) at index [$(index)].") # `index` here is guaranteed to be not `nothing`, because of dispatch. `Nothing, Nothing` version will dispatch on the method below
__factorization_specification_resolve_index(index::Nothing, collection::NodeLabel) = nothing
__factorization_specification_resolve_index(
    index::Nothing,
    collection::AbstractArray{<:NodeLabel},
) = nothing
__factorization_specification_resolve_index(
    index::Integer,
    collection::AbstractArray{<:NodeLabel},
) =
    (firstindex(collection) <= index <= lastindex(collection)) ? index :
    error(
        "Index out of bounds happened during indices resolution in factorization constraints. Attempt to access collection $(collection) of variable $(name(first(collection))) at index [$(index)].",
    )
__factorization_specification_resolve_index(
    index::FunctionalIndex,
    collection::AbstractArray{<:NodeLabel},
) = __factorization_specification_resolve_index(
    index(collection)::Integer,
    collection,
)::Integer
__factorization_specification_resolve_index(
    index::CombinedRange,
    collection::AbstractArray{<:NodeLabel},
) = CombinedRange(
    __factorization_specification_resolve_index(firstindex(index), collection)::Integer,
    __factorization_specification_resolve_index(lastindex(index), collection)::Integer,
)
__factorization_specification_resolve_index(
    index::SplittedRange,
    collection::AbstractArray{<:NodeLabel},
) = SplittedRange(
    __factorization_specification_resolve_index(firstindex(index), collection)::Integer,
    __factorization_specification_resolve_index(lastindex(index), collection)::Integer,
)

# Only these combinations are allowed to be merged
__factorization_split_merge_range(a::Int, b::Int) = SplittedRange(a, b)
__factorization_split_merge_range(a::FunctionalIndex, b::Int) = SplittedRange(a, b)
__factorization_split_merge_range(a::Int, b::FunctionalIndex) = SplittedRange(a, b)
__factorization_split_merge_range(a::FunctionalIndex, b::FunctionalIndex) =
    SplittedRange(a, b)
__factorization_split_merge_range(a::Any, b::Any) =
    error("Cannot merge $(a) and $(b) indexes in `factorization_split`")

struct FactorizationConstraintEntry{T<:IndexedVariable}
    entries::Vector{T}
end

getvariables(entry::FactorizationConstraintEntry{T} where {T}) = getvariable.(entry.entries)

Base.:(*)(left::FactorizationConstraintEntry, right::FactorizationConstraintEntry) =
    [left, right]
Base.:(*)(
    left::AbstractArray{<:FactorizationConstraintEntry},
    right::FactorizationConstraintEntry,
) = [left..., right]
Base.:(*)(
    left::FactorizationConstraintEntry,
    right::AbstractArray{<:FactorizationConstraintEntry},
) = [left, right...]
Base.:(*)(
    left::AbstractArray{<:FactorizationConstraintEntry},
    right::AbstractArray{<:FactorizationConstraintEntry},
) = [left, right...]


function Base.show(io::IO, constraint_entry::FactorizationConstraintEntry)
    print(io, "q(")
    print(io, join(constraint_entry.entries, ", "))
    print(io, ")")
end

Base.iterate(e::FactorizationConstraintEntry, i::Int = 1) = Base.iterate(e.entries, i)

Base.:(==)(lhs::FactorizationConstraintEntry, rhs::FactorizationConstraintEntry) =
    length(lhs.entries) == length(rhs.entries) &&
    all(pair -> pair[1] == pair[2], zip(lhs.entries, rhs.entries))

getnames(entry::FactorizationConstraintEntry) = [e.variable for e in entry.entries]
getindices(entry::FactorizationConstraintEntry) = Tuple([e.index for e in entry.entries])

function factorization_split(
    left::FactorizationConstraintEntry,
    right::FactorizationConstraintEntry,
)
    (getnames(left) == getnames(right)) || error(
        "Cannot split $(left_last) and $(right_first). Names or their order does not match.",
    )
    (length(getnames(left)) === length(Set(getnames(left)))) ||
        error("Cannot split $(left) and $(right). Names should be unique.")
    lindices = getindices(left)
    rindices = getindices(right)
    split_merged = unrolled_map(__factorization_split_merge_range, lindices, rindices)
    return FactorizationConstraintEntry([
        IndexedVariable(var, split) for (var, split) in zip(getnames(left), split_merged)
    ])
end

function factorization_split(
    left::AbstractArray{<:FactorizationConstraintEntry},
    right::FactorizationConstraintEntry,
)
    left_last = last(left)
    entry = factorization_split(left_last, right)
    return [left[1:(end-1)]..., entry]
end

function factorization_split(
    left::FactorizationConstraintEntry,
    right::AbstractArray{<:FactorizationConstraintEntry},
)
    right_first = first(right)
    entry = factorization_split(left, right_first)
    return [entry, right[(begin+1):end]...]
end


function factorization_split(
    left::AbstractArray{<:FactorizationConstraintEntry},
    right::AbstractArray{<:FactorizationConstraintEntry},
)
    left_last = last(left)
    right_first = first(right)
    entry = factorization_split(left_last, right_first)

    return [left[1:(end-1)]..., entry, right[(begin+1):end]...]
end



struct FactorizationConstraint{V,F}
    variables::V
    constraint::F
    function FactorizationConstraint(
        variables::V,
        constraint::Vector{<:FactorizationConstraintEntry},
    ) where {V}
        
        if !issetequal(
            Set(getvariable.(variables)),
            unique(collect(Iterators.flatten(getvariables.(constraint)))),
        )
            error("Variables in constraint and variables should be the same")
        end
        rhs_variables = collect(Iterators.flatten(constraint))
        if length(rhs_variables) != length(unique(rhs_variables))
            error("Variables in right hand side of constraint ($(constraint...)) can only occur once")
        end
        return new{V,typeof(constraint)}(variables, constraint)
    end
    function FactorizationConstraint(variables::V, constraint::F) where {V,F}
        return new{V,F}(variables, constraint)
    end
end

Base.:(==)(left::FactorizationConstraint, right::FactorizationConstraint) =
    left.variables == right.variables && left.constraint == right.constraint

struct FunctionalFormConstraint{V,F}
    variables::V
    constraint::F
end

struct MessageConstraint
    variables::IndexedVariable
    constraint::Any
end

const MaterializedConstraints =
    Union{FactorizationConstraint,FunctionalFormConstraint,MessageConstraint}

getvariables(c::MaterializedConstraints) = c.variables
getconstraint(c::MaterializedConstraints) = c.constraint

function Base.show(
    io::IO,
    constraint::FactorizationConstraint{V,F} where {V,F<:AbstractArray},
)
    print(io, "q(")
    print(io, join(getvariables(constraint), ", "))
    print(io, ") = ")
    print(io, join(getconstraint(constraint), ""))
end

Base.show(io::IO, constraint::FunctionalFormConstraint{V,F} where {V<:AbstractArray,F}) =
    print(io, "q(", join(getvariables(constraint), ", "), ") :: ", constraint.constraint)
Base.show(io::IO, constraint::FunctionalFormConstraint{V,F} where {V<:Symbol,F}) =
    print(io, "q(", getvariables(constraint), ") :: ", constraint.constraint)


struct GeneralSubModelConstraints
    fform::Function
    constraints::Any
end

Base.show(io::IO, constraint::GeneralSubModelConstraints) =
    print(io, "q(", getsubmodel(constraint), ") :: ", getconstraint(constraint))

getsubmodel(c::GeneralSubModelConstraints) = c.fform
getconstraint(c::GeneralSubModelConstraints) = c.constraints


struct SpecificSubModelConstraints
    tag::Symbol
    constraints::Any
end

Base.show(io::IO, constraint::SpecificSubModelConstraints) =
    print(io, "q(", getsubmodel(constraint), ") :: ", getconstraint(constraint))

getsubmodel(c::SpecificSubModelConstraints) = c.tag
getconstraint(c::SpecificSubModelConstraints) = c.constraints

const Constraint = Union{
    FactorizationConstraint,
    FunctionalFormConstraint,
    MessageConstraint,
    GeneralSubModelConstraints,
    SpecificSubModelConstraints,
}
struct Constraints
    factorization_constraints::Vector{FactorizationConstraint}
    functional_form_constraints::Vector{FunctionalFormConstraint}
    message_constraints::Vector{MessageConstraint}
    submodel_constraints::Vector{Constraint}
end

Constraints() = Constraints([], [], [], [])
Constraints(constraints::Vector{<:Constraint}) = begin
    c = Constraints()
    for constraint in constraints
        Base.push!(c, constraint)
    end
    return c
end

function Base.show(io::IO, c::Constraints)
    print(io, "Constraints: \n")
    for constraint in getconstraints(c)
        print(io, "    ")
        print(io, constraint)
        print(io, "\n")
    end
end

function Base.push!(c::Constraints, constraint::FactorizationConstraint{V,F} where {V,F})
    if any(
        issetequal.(
            Set(getvariables.(c.factorization_constraints)),
            Ref(getvariables(constraint)),
        ),
    )
        error(
            "Cannot add $(constraint) to constraint set as this combination of variable names is already in use.",
        )
    end
    Base.push!(c.factorization_constraints, constraint)
end

function Base.push!(c::Constraints, constraint::FunctionalFormConstraint)
    if any(
        issetequal.(
            Set(getvariables.(c.functional_form_constraints)),
            Ref(getvariables(constraint)),
        ),
    )
        error(
            "Cannot add $(constraint) to constraint set as these variables already have a functional form constraint applied.",
        )
    end
    Base.push!(c.functional_form_constraints, constraint)
end

function Base.push!(c::Constraints, constraint::MessageConstraint)
    if any(getvariables.(c.message_constraints) .== Ref(getvariables(constraint)))
        error(
            "Cannot add $(constraint) to constraint set as message on edge $(getvariables(constraint)) is already defined.",
        )
    end
    Base.push!(c.message_constraints, constraint)
end

function Base.push!(c::Constraints, constraint::GeneralSubModelConstraints)
    if any(getsubmodel.(c.submodel_constraints) .== Ref(getsubmodel(constraint)))
        error(
            "Cannot add $(constraint) to constraint set as constraints are already specified for submodels of type $(getsubmodel(constraint)).",
        )
    end
    Base.push!(c.submodel_constraints, constraint)
end

function Base.push!(c::Constraints, constraint::SpecificSubModelConstraints)
    if any(getsubmodel.(c.submodel_constraints) .== Ref(getsubmodel(constraint)))
        error(
            "Cannot add $(constraint) to $(c) to constraint set as constraints are already specified for submodel $(getsubmodel(constraint)).",
        )
    end
    Base.push!(c.submodel_constraints, constraint)
end



Base.:(==)(left::Constraints, right::Constraints) =
    left.factorization_constraints == right.factorization_constraints &&
    left.functional_form_constraints == right.functional_form_constraints &&
    left.message_constraints == right.message_constraints &&
    left.submodel_constraints == right.submodel_constraints
getconstraints(c::Constraints) = vcat(
    c.factorization_constraints,
    c.functional_form_constraints,
    c.message_constraints,
    c.submodel_constraints,
)

Base.push!(c_set::GeneralSubModelConstraints, c::Constraint) =
    Base.push!(getconstraint(c_set), c)
Base.push!(c_set::SpecificSubModelConstraints, c::Constraint) =
    Base.push!(getconstraint(c_set), c)



SubModelConstraints(x::Symbol, constraints = Constraints()::Constraints) =
    SpecificSubModelConstraints(x, constraints)
SubModelConstraints(fform::Function, constraints = Constraints()::Constraints) =
    GeneralSubModelConstraints(fform, constraints)

function applicable_nodes(
    model::Model,
    context::Context,
    constraint::FactorizationConstraint,
)
    return union(
        neighbors.(
            Ref(model),
            collect(Iterators.flatten(vec.(getindex.(Ref(context), constraint.variables)))),
        )...,
    )
end

function applicable_nodes(
    model::Model,
    context::Context,
    constraint::Union{
        FunctionalFormConstraint{V,F} where {V<:IndexedVariable,F},
        MessageConstraint,
    },
)
    return vec(context[getvariables(constraint)])
end

function applicable_nodes(
    model::Model,
    context::Context,
    constraint::FunctionalFormConstraint{V,F} where {V<:AbstractArray,F},
)
    return intersect(
        neighbors.(
            Ref(model),
            collect(Iterators.flatten(vec.(getindex.(Ref(context), constraint.variables)))),
        )...,
    )
end

__meanfield_split(name::IndexedVariable, var::NodeLabel) = name
__meanfield_split(name::IndexedVariable, var::ResizableArray{<:NodeLabel,V,N}) where {V,N} =
    begin
        @assert N == 1 "MeanField factorization only implemented for 1-dimensional arrays."
        IndexedVariable(
            name.variable,
            SplittedRange(
                FunctionalIndex{:begin}(firstindex),
                FunctionalIndex{:end}(lastindex),
            ),
        )
    end


prepare_factorization_constraint(
    context::Context,
    constraint::FactorizationConstraint{
        V,
        F,
    } where {V,F<:AbstractArray{<:FactorizationConstraintEntry}},
) = constraint

function prepare_factorization_constraint(
    context::Context,
    constraint::FactorizationConstraint{V,F} where {V,F<:MeanField},
)
    return FactorizationConstraint(
        constraint.variables,
        [
            FactorizationConstraintEntry([__meanfield_split(v, context[v])]) for
            v in constraint.variables
        ],
    )
end

function prepare_factorization_constraint(
    context::Context,
    constraint::FactorizationConstraint{V,F} where {V,F<:FullFactorization},
)
    return FactorizationConstraint(
        constraint.variables,
        [FactorizationConstraintEntry([v for v in constraint.variables])],
    )
end

__resolve_index(index::Nothing, collection::AbstractArray) = vec(collection)
__resolve_index(index::Nothing, collection::NodeLabel) = collection

function __get_variable(context::Context, var::IndexedVariable{Nothing})
    return __resolve_index(nothing, context[var.variable])
end

__get_variable(context::Context, var::IndexedVariable{<:Int}) =
    context[var.variable][var.index]

function __get_variable(context::Context, var::IndexedVariable{<:CombinedRange})
    array = context[var.variable]
    index = __factorization_specification_resolve_index(var.index, array)
    return array[firstindex(index):lastindex(index)]
end

__get_variable(context::Context, var::IndexedVariable{<:AbstractArray{<:Int}}) =
    context[var.variable][var.index...]
function __get_variable(context::Context, var::IndexedVariable{FunctionalIndex})
    array = context[var.variable]
    index = var.index(array)
    return array[index]
end

function get_variables(context::Context, var::FactorizationConstraintEntry)
    result = [__get_variable(context, v) for v in var.entries]
    return Vector{GraphPPL.NodeLabel}[collect(Iterators.flatten(result))]
end

function get_variables(
    context::Context,
    var::FactorizationConstraintEntry{<:IndexedVariable{<:SplittedRange}},
)
    result = []
    variables = [context[v.variable] for v in var.entries]
    ranges = [v.index for v in var.entries]
    ranges = __factorization_specification_resolve_index.(ranges, variables)
    range_lengths = length.(ranges)
    @assert all(y -> y == range_lengths[1], range_lengths) lazy"All ranges in a Factorization constraint entry $([(string(v.variable) * '[' * string(range) * ']') for v in var.entries]) should have the same length."
    range_start_indices = firstindex.(ranges)
    for i = 1:range_lengths[1]
        indices = range_start_indices .+ (i - 1)
        Base.push!(result, [variables[j][indices[j]] for j = 1:length(variables)])
    end
    return result
end

function convert_to_nodelabels(context::Context, constraint_data::FactorizationConstraint)
    result = Vector{GraphPPL.NodeLabel}[]
    for entry in getconstraint(constraint_data)
        variables = get_variables(context, entry)
        result = vcat(result, variables)
    end
    all_variables = collect(Iterators.flatten(result))

    length(unique(all_variables)) == length(all_variables) ||
        error(lazy"Factorization constraint $constraint_data contains duplicate variables.")
    return result
end

"""
    convert_to_bitsets(neighbors, constraint_labels)

Converts the constraint encoded in `constraint_labels` to a `BitSet` representation. This representation contains for every neighbor a `BitSet` of all the other neighbors that are in the same factorization cluster according to this constraint.
"""
function convert_to_bitsets(neighbors::AbstractArray, constraint_labels::AbstractArray)
    constraint_labels = intersect.(Ref(neighbors), constraint_labels)
    num_neighbors = length(neighbors)
    mapping = Dict(neighbors .=> 1:num_neighbors)
    label_indices = map(group -> map(x -> mapping[x], group), constraint_labels)        #Apparently this is faster than calling findall, but be sure to benchmark this in actual production code.
    constraint_sets = BitSet.(label_indices)
    for (node, _) in enumerate(neighbors)
        if !any(node .∈ constraint_sets)    #If a variable does not occur in any group
            Base.push!.(constraint_sets, node)   #Add it to all groups
        end
    end
    result = map(
        node -> union(constraint_sets[findall(node .∈ constraint_sets)]...),
        1:num_neighbors,
    )
    return result
end

function apply!(model::Model, constraints::Constraints)
    apply!(model, GraphPPL.get_principal_submodel(model), constraints)
end

function apply!(model::Model, context::Context, constraints::Constraints)
    for constraint in getconstraints(constraints)
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
    nodes = applicable_nodes(model, context, constraint)
    apply!(model, context, constraint, nodes)
end

function apply!(
    model::Model,
    context::Context,
    constraint::FactorizationConstraint,
    nodes::AbstractArray{K} where {K<:NodeLabel},
)
    constraint = prepare_factorization_constraint(context, constraint)
    constraint_labels = convert_to_nodelabels(context, constraint)
    for node in nodes
        constraint_bitsets = convert_to_bitsets(
            GraphPPL.neighbors(model, node; sorted = true),
            constraint_labels,
        )
        save_constraint!(model, node, constraint_bitsets, :q)
    end
end

function apply!(
    model::Model,
    context::Context,
    constraint::FunctionalFormConstraint{V,F} where {V<:IndexedVariable,F},
    nodes::AbstractArray{K} where {K<:NodeLabel},
)
    for node in nodes
        save_constraint!(model, node, getconstraint(constraint), :q)
    end
end

function apply!(
    model::Model,
    context::Context,
    constraint::MessageConstraint,
    nodes::AbstractArray{K} where {K<:NodeLabel},
)
    for node in nodes
        save_constraint!(model, node, getconstraint(constraint), :μ)
    end
end

combine_factorization_constraints(
    left::AbstractArray{<:BitSet},
    right::AbstractArray{<:BitSet},
) = intersect.(left, right)

save_constraint!(model::Model, node::NodeLabel, constraint_data, symbol::Symbol) =
    save_constraint!(model, node, model[node], constraint_data, symbol)

function save_constraint!(
    model::Model,
    node::NodeLabel,
    node_data::FactorNodeData,
    constraint_data::AbstractArray{T} where {T<:BitSet},
    symbol::Symbol,
)
    node_data_options = node_options(node_data)
    node_data_options[symbol] =
        combine_factorization_constraints(node_data_options[:q], constraint_data)
end

function save_constraint!(
    model::Model,
    node::NodeLabel,
    node_data::VariableNodeData,
    constraint_data,
    symbol::Symbol,
)
    node_options(model[node])[symbol] = constraint_data
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

function materialize_constraints!(model::Model)
    for node in Graphs.vertices(model.graph)
        materialize_constraints!(model, MetaGraphsNext.label_for(model.graph, node))
    end
end

materialize_constraints!(model::Model, node::NodeLabel) =
    materialize_constraints!(model, node, model[node])
materialize_constraints!(model::Model, node::NodeLabel, node_data::VariableNodeData) =
    nothing

function materialize_constraints!(
    model::Model,
    node_label::NodeLabel,
    node_data::FactorNodeData,
)
    constraint_set = Set(node_options(node_data)[:q]) #TODO test `unique``
    edges = GraphPPL.edges(model, node_label; sorted = true)
    constraint = SA[constraint_set...]
    constraint = Tuple(sort(constraint, by = first))
    constraint = map(factors -> Tuple(getindex.(Ref(edges), factors)), constraint)
    if !is_valid_partition(constraint_set)
        error(
            lazy"Factorization constraint set at node $node_label is not a valid constraint set. Please check your model definition and constraint specification. (Constraint set: $constraint)",
        )
        return
    end
    node_options(node_data)[:q] = constraint
end
