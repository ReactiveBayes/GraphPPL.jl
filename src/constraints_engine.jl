export MeanField, FullFactorization

using TupleTools
using StaticArrays
using Unrolled
using BitSetTuples
using MetaGraphsNext
using DataStructures
using Memoization

struct MeanField end

struct FullFactorization end

"""
    CombinedRange{L, R}

`CombinedRange` represents a range of combined variable in factorization specification language. Such variables specified to be in the same factorization cluster.

See also: [`GraphPPL.SplittedRange`](@ref)
"""
struct CombinedRange{L, R}
    from::L
    to::R
end

Base.firstindex(range::CombinedRange) = range.from
Base.lastindex(range::CombinedRange) = range.to
Base.in(item, range::CombinedRange) = firstindex(range) <= item <= lastindex(range)
Base.in(item::NTuple{N, Int} where {N}, range::CombinedRange) = CartesianIndex(item...) ∈ firstindex(range):lastindex(range)
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
Base.in(item::NTuple{N, Int} where {N}, range::SplittedRange) = CartesianIndex(item...) ∈ firstindex(range):lastindex(range)
Base.length(range::SplittedRange) = lastindex(range) - firstindex(range) + 1

Base.show(io::IO, range::SplittedRange) = print(io, repr(range.from), "..", repr(range.to))

"""
    __factorization_specification_resolve_index(index, collection)

This function materializes index from constraints specification to something we can use `Base.in` function to. For example constraint specification index may return `begin` or `end`
placeholders in a form of the `FunctionalIndex` structure. This function correctly resolves all indices and check bounds as an extra step.
"""
function __factorization_specification_resolve_index end

__factorization_specification_resolve_index(index::Any, collection::NodeLabel) = error("Attempt to access a single variable $(getname(collection)) at index [$(index)].") # `index` here is guaranteed to be not `nothing`, because of dispatch. `Nothing, Nothing` version will dispatch on the method below
__factorization_specification_resolve_index(index::Nothing, collection::NodeLabel) = nothing
__factorization_specification_resolve_index(index::Nothing, collection::AbstractArray{<:NodeLabel}) = nothing
__factorization_specification_resolve_index(index::Integer, collection::AbstractArray{<:NodeLabel}) =
    if (firstindex(collection) <= index <= lastindex(collection))
        index
    else
        error(
            "Index out of bounds happened during indices resolution in factorization constraints. Attempt to access collection $(collection) of variable $(getname(collection)) at index [$(index)]."
        )
    end
__factorization_specification_resolve_index(index::FunctionalIndex, collection::AbstractArray{<:NodeLabel}) =
    __factorization_specification_resolve_index(index(collection)::Integer, collection)::Integer
__factorization_specification_resolve_index(index::CombinedRange, collection::AbstractArray{<:NodeLabel}) = CombinedRange(
    __factorization_specification_resolve_index(firstindex(index), collection)::Integer, __factorization_specification_resolve_index(lastindex(index), collection)::Integer
)
__factorization_specification_resolve_index(index::SplittedRange, collection::AbstractArray{<:NodeLabel}) = SplittedRange(
    __factorization_specification_resolve_index(firstindex(index), collection)::Integer, __factorization_specification_resolve_index(lastindex(index), collection)::Integer
)

# Only these combinations are allowed to be merged
__factorization_split_merge_range(a::Int, b::Int) = SplittedRange(a, b)
__factorization_split_merge_range(a::FunctionalIndex, b::Int) = SplittedRange(a, b)
__factorization_split_merge_range(a::Int, b::FunctionalIndex) = SplittedRange(a, b)
__factorization_split_merge_range(a::FunctionalIndex, b::FunctionalIndex) = SplittedRange(a, b)
__factorization_split_merge_range(a::Any, b::Any) = error("Cannot merge $(a) and $(b) indexes in `factorization_split`")

"""
    FactorizationConstraintEntry

A `FactorizationConstraintEntry` is a group of variables (represented as a `Vector` of `IndexedVariable` objects) that represents a factor group in a factorization constraint.

See also: [`GraphPPL.FactorizationConstraint`](@ref)
"""
struct FactorizationConstraintEntry
    entries::Tuple
end

entries(entry::FactorizationConstraintEntry) = entry.entries
getvariables(entry::FactorizationConstraintEntry) = getvariable.(entry.entries)

# These functions convert the multiplication in q(x)q(y) to a collection of `FactorizationConstraintEntry`s
Base.:(*)(left::FactorizationConstraintEntry, right::FactorizationConstraintEntry) = (left, right)
Base.:(*)(left::NTuple{N, <:FactorizationConstraintEntry} where {N}, right::FactorizationConstraintEntry) = (left..., right)
Base.:(*)(left::FactorizationConstraintEntry, right::NTuple{N, <:FactorizationConstraintEntry} where {N}) = (left, right...)
Base.:(*)(left::NTuple{N, <:FactorizationConstraintEntry} where {N}, right::NTuple{N, <:FactorizationConstraintEntry} where {N}) = (left..., right...)

function Base.show(io::IO, constraint_entry::FactorizationConstraintEntry)
    print(io, "q(")
    print(io, join(constraint_entry.entries, ", "))
    print(io, ")")
end

Base.iterate(e::FactorizationConstraintEntry, state::Int = 1) = iterate(e.entries, state)

Base.:(==)(lhs::FactorizationConstraintEntry, rhs::FactorizationConstraintEntry) =
    length(lhs.entries) == length(rhs.entries) && all(pair -> pair[1] == pair[2], zip(lhs.entries, rhs.entries))

getnames(entry::FactorizationConstraintEntry) = [e.variable for e in entry.entries]
getindices(entry::FactorizationConstraintEntry) = Tuple([e.index for e in entry.entries])

"""
    factorization_split(left, right)

Creates a new `FactorizationConstraintEntry` that contains a `SplittedRange` splitting `left` and `right`. 
This function is used to convert two `FactorizationConstraintEntry`s (for example `q(x[begin])..q(x[end])`) into a single `FactorizationConstraintEntry` containing the `SplittedRange`.

    See also: [`GraphPPL.SplittedRange`](@ref)
"""
function factorization_split(left::FactorizationConstraintEntry, right::FactorizationConstraintEntry)
    (getnames(left) == getnames(right)) || error("Cannot split $(left) and $(right). Names or their order does not match.")
    (length(getnames(left)) === length(Set(getnames(left)))) || error("Cannot split $(left) and $(right). Names should be unique.")
    lindices = getindices(left)
    rindices = getindices(right)
    split_merged = unrolled_map(__factorization_split_merge_range, lindices, rindices)
    return FactorizationConstraintEntry(Tuple([IndexedVariable(var, split) for (var, split) in zip(getnames(left), split_merged)]))
end

function factorization_split(left::NTuple{N, FactorizationConstraintEntry} where {N}, right::FactorizationConstraintEntry)
    left_last = last(left)
    entry = factorization_split(left_last, right)
    return (left[1:(end - 1)]..., entry)
end

function factorization_split(left::FactorizationConstraintEntry, right::NTuple{N, FactorizationConstraintEntry} where {N})
    right_first = first(right)
    entry = factorization_split(left, right_first)
    return (entry, right[(begin + 1):end]...)
end

function factorization_split(left::NTuple{N, FactorizationConstraintEntry} where {N}, right::NTuple{N, FactorizationConstraintEntry} where {N})
    left_last = last(left)
    right_first = first(right)
    entry = factorization_split(left_last, right_first)

    return (left[1:(end - 1)]..., entry, right[(begin + 1):end]...)
end

"""
    FactorizationConstraint{V, F}

A `FactorizationConstraint` represents a single factorization constraint in a variational posterior constraint specification. We use type parametrization 
to dispatch on different types of constraints, for example `q(x, y) = MeanField()` is treated different from `q(x, y) = q(x)q(y)`. 

The `FactorizationConstraint` constructor checks for obvious errors, such as duplicate variables in the constraint specification and checks if the left hand side and right hand side contain the same variables.

    See also: [`GraphPPL.FactorizationConstraintEntry`](@ref)
"""
struct FactorizationConstraint{V, F}
    variables::V
    constraint::F
    function FactorizationConstraint(variables::V, constraint::Tuple) where {V}
        if !issetequal(Set(getvariable.(variables)), unique(collect(Iterators.flatten(getvariables.(constraint)))))
            error("Variables in constraint and variables should be the same")
        end
        rhs_variables = collect(Iterators.flatten(constraint))
        if length(rhs_variables) != length(unique(rhs_variables))
            error("Variables in right hand side of constraint ($(constraint...)) can only occur once")
        end
        return new{V, typeof(constraint)}(variables, constraint)
    end
    function FactorizationConstraint(variables::V, constraint::F) where {V, F}
        return new{V, F}(variables, constraint)
    end
end

FactorizationConstraint(variables::V, constriant::FactorizationConstraintEntry) where {V} = FactorizationConstraint(variables, (constriant,))

Base.:(==)(left::FactorizationConstraint, right::FactorizationConstraint) = left.variables == right.variables && left.constraint == right.constraint

"""
    FunctionalFormConstraint{V, F}

A `FunctionalFormConstraint` represents a single functional form constraint in a variational posterior constraint specification. We use type parametrization
to dispatch on different types of constraints, for example `q(x, y) :: MvNormal` should be treated different from `q(x) :: Normal`.
"""
struct FunctionalFormConstraint{V, F}
    variables::V
    constraint::F
end

"""
    MessageConstraint

A `MessageConstraint` represents a single constraint on the messages in a message passing schema. These constraints closely resemble the `FunctionalFormConstraint` but are used to specify constraints on the messages in a message passing schema.
See also: [`GraphPPL.FunctionalFormConstraint`](@ref)
"""
struct MessageConstraint
    variables::IndexedVariable
    constraint::Any
end

const MaterializedConstraints = Union{FactorizationConstraint, FunctionalFormConstraint, MessageConstraint}

getvariables(c::MaterializedConstraints) = c.variables
getconstraint(c::MaterializedConstraints) = c.constraint

function Base.show(io::IO, constraint::FactorizationConstraint{V, F} where {V, F <: Union{Tuple, FactorizationConstraintEntry}})
    print(io, "q(")
    print(io, join(getvariables(constraint), ", "))
    print(io, ") = ")
    print(io, join(getconstraint(constraint), ""))
end

Base.show(io::IO, constraint::FunctionalFormConstraint{V, F} where {V <: AbstractArray, F}) = print(io, "q(", join(getvariables(constraint), ", "), ") :: ", constraint.constraint)
Base.show(io::IO, constraint::FunctionalFormConstraint{V, F} where {V <: IndexedVariable, F}) = print(io, "q(", getvariables(constraint), ") :: ", constraint.constraint)

"""
    GeneralSubModelConstraints

A `GeneralSubModelConstraints` represents a set of constraints to be applied to a set of submodels. The submodels are specified by the `fform` field, which contains the identifier of the submodel. 
The `constraints` field contains the constraints to be applied to all instances of this submodel on this level in the model hierarchy.

See also: [`GraphPPL.SpecificSubModelConstraints`](@ref)
"""
struct GeneralSubModelConstraints
    fform::Function
    constraints::Any
end

GeneralSubModelConstraints(fform::Function) = GeneralSubModelConstraints(fform, Constraints())

fform(c::GeneralSubModelConstraints) = c.fform
Base.show(io::IO, constraint::GeneralSubModelConstraints) = print(io, "q(", getsubmodel(constraint), ") :: ", getconstraint(constraint))

getsubmodel(c::GeneralSubModelConstraints) = c.fform
getconstraint(c::GeneralSubModelConstraints) = c.constraints

"""
    SpecificSubModelConstraints

A `SpecificSubModelConstraints` represents a set of constraints to be applied to a specific submodel. The submodel is specified by the `tag` field, which contains the identifier of the submodel. 

See also: [`GraphPPL.GeneralSubModelConstraints`](@ref)
"""
struct SpecificSubModelConstraints
    submodel::FactorID
    constraints::Any
end

SpecificSubModelConstraints(submodel::FactorID) = SpecificSubModelConstraints(submodel, Constraints())

Base.show(io::IO, constraint::SpecificSubModelConstraints) = print(io, "q(", getsubmodel(constraint), ") :: ", getconstraint(constraint))

getsubmodel(c::SpecificSubModelConstraints) = c.submodel
getconstraint(c::SpecificSubModelConstraints) = c.constraints

"""
    Constraints

An instance of `Constraints` represents a set of constraints to be applied to a variational posterior in a factor graph model. These constraints can be applied using `apply!`.

See also: [`GraphPPL.apply!`](@ref)
"""
struct Constraints
    factorization_constraints::Vector{FactorizationConstraint}
    functional_form_constraints::Vector{FunctionalFormConstraint}
    message_constraints::Vector{MessageConstraint}
    general_submodel_constraints::Dict{Function, GeneralSubModelConstraints}
    specific_submodel_constraints::Dict{FactorID, SpecificSubModelConstraints}
end

factorization_constraints(c::Constraints) = c.factorization_constraints
functional_form_constraints(c::Constraints) = c.functional_form_constraints
message_constraints(c::Constraints) = c.message_constraints
general_submodel_constraints(c::Constraints) = c.general_submodel_constraints
specific_submodel_constraints(c::Constraints) = c.specific_submodel_constraints

Constraints() = Constraints([], [], [], Dict(), Dict())
Constraints(constraints::Vector) = begin
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

function Base.push!(c::Constraints, constraint::FactorizationConstraint{V, F} where {V, F})
    if any(issetequal.(Set(getvariables.(c.factorization_constraints)), Ref(getvariables(constraint))))
        error("Cannot add $(constraint) to constraint set as this combination of variable names is already in use.")
    end
    push!(c.factorization_constraints, constraint)
end

function Base.push!(c::Constraints, constraint::FunctionalFormConstraint)
    if any(issetequal.(Set(getvariables.(c.functional_form_constraints)), Ref(getvariables(constraint))))
        error("Cannot add $(constraint) to constraint set as these variables already have a functional form constraint applied.")
    end
    push!(c.functional_form_constraints, constraint)
end

function Base.push!(c::Constraints, constraint::MessageConstraint)
    if any(getvariables.(c.message_constraints) .== Ref(getvariables(constraint)))
        error("Cannot add $(constraint) to constraint set as message on edge $(getvariables(constraint)) is already defined.")
    end
    push!(c.message_constraints, constraint)
end

function Base.push!(c::Constraints, constraint::GeneralSubModelConstraints)
    if any(keys(general_submodel_constraints(c)) .== Ref(getsubmodel(constraint)))
        error("Cannot add $(constraint) to constraint set as constraints are already specified for submodels of type $(getsubmodel(constraint)).")
    end
    general_submodel_constraints(c)[getsubmodel(constraint)] = constraint
end

function Base.push!(c::Constraints, constraint::SpecificSubModelConstraints)
    if any(keys(specific_submodel_constraints(c)) .== Ref(getsubmodel(constraint)))
        error("Cannot add $(constraint) to $(c) to constraint set as constraints are already specified for submodel $(getsubmodel(constraint)).")
    end
    specific_submodel_constraints(c)[getsubmodel(constraint)] = constraint
end

Base.:(==)(left::Constraints, right::Constraints) =
    left.factorization_constraints == right.factorization_constraints &&
    left.functional_form_constraints == right.functional_form_constraints &&
    left.message_constraints == right.message_constraints &&
    left.general_submodel_constraints == right.general_submodel_constraints &&
    left.specific_submodel_constraints == right.specific_submodel_constraints
getconstraints(c::Constraints) = vcat(
    factorization_constraints(c),
    functional_form_constraints(c),
    message_constraints(c),
    values(general_submodel_constraints(c))...,
    values(specific_submodel_constraints(c))...
)

Base.push!(c_set::GeneralSubModelConstraints, c) = push!(getconstraint(c_set), c)
Base.push!(c_set::SpecificSubModelConstraints, c) = push!(getconstraint(c_set), c)

default_constraints(any) = Constraints()

struct ResolvedIndexedVariable{T}
    variable::IndexedVariable{T}
    context::Context
end

ResolvedIndexedVariable(variable::Symbol, index, context::Context) = ResolvedIndexedVariable(IndexedVariable(variable, index), context)
getvariable(var::ResolvedIndexedVariable) = var.variable
getname(var::ResolvedIndexedVariable) = getvariable(var).variable
index(var::ResolvedIndexedVariable) = getvariable(var).index
getcontext(var::ResolvedIndexedVariable) = var.context

Base.show(io::IO, var::ResolvedIndexedVariable{T}) where {T} = print(io, getvariable(var))

Base.in(data::VariableNodeData, var::ResolvedIndexedVariable{T} where {T <: Union{Int, NTuple{N, Int} where N}}) =
    (getname(var) == getname(data)) && (index(var) == index(data)) && (getcontext(var) == getcontext(data))

Base.in(data::VariableNodeData, var::ResolvedIndexedVariable{T} where {T <: Nothing}) = (getname(var) == getname(data)) && (getcontext(var) == getcontext(data))

Base.in(data::VariableNodeData, var::ResolvedIndexedVariable{T} where {T <: Union{SplittedRange, CombinedRange, UnitRange}}) =
    (getname(data) == getname(var)) && (index(data) ∈ index(var)) && (getcontext(var) == getcontext(data))

struct ResolvedConstraintLHS
    variables::Tuple
end

getvariables(var::ResolvedConstraintLHS) = var.variables

Base.in(data::VariableNodeData, var::ResolvedConstraintLHS) = any(map(v -> (data ∈ v)::Bool, getvariables(var)))

Base.:(==)(left::ResolvedConstraintLHS, right::ResolvedConstraintLHS) = getvariables(left) == getvariables(right)

struct ResolvedFactorizationConstraintEntry
    variables::Tuple
end

getvariables(var::ResolvedFactorizationConstraintEntry) = var.variables

Base.in(data::VariableNodeData, var::ResolvedFactorizationConstraintEntry) = any(map(v -> (data ∈ v)::Bool, getvariables(var)))

struct ResolvedFactorizationConstraint{V <: ResolvedConstraintLHS, F}
    lhs::V
    rhs::F
end

Base.:(==)(left::ResolvedFactorizationConstraint{V, F} where {V <: ResolvedConstraintLHS, F}, right::ResolvedFactorizationConstraint{V, F} where {V <: ResolvedConstraintLHS, F}) =
    left.lhs == right.lhs && left.rhs == right.rhs

lhs(constraint::ResolvedFactorizationConstraint) = constraint.lhs
rhs(constraint::ResolvedFactorizationConstraint) = constraint.rhs

function in_lhs(constraint::ResolvedFactorizationConstraint, node::VariableNodeData)
    return in(node, lhs(constraint)) || (!isnothing(getlink(node)) && any(l -> in_lhs(constraint, l), getlink(node)))
end

struct ResolvedFunctionalFormConstraint{V <: ResolvedConstraintLHS, F}
    lhs::V
    rhs::F
end

lhs(constraint::ResolvedFunctionalFormConstraint) = constraint.lhs
rhs(constraint::ResolvedFunctionalFormConstraint) = constraint.rhs

const ResolvedConstraint = Union{ResolvedFactorizationConstraint, ResolvedFunctionalFormConstraint}

struct ConstraintStack{T}
    constraints::Stack{T}
    context_counts::AbstractDict{Context, Int}
end

constraints(stack::ConstraintStack) = stack.constraints
context_counts(stack::ConstraintStack) = stack.context_counts
Base.getindex(stack::ConstraintStack, context::Context) = context_counts(stack)[context]

ConstraintStack() = ConstraintStack(Stack{ResolvedConstraint}(), Dict{Context, Int}())

function Base.push!(stack::ConstraintStack, constraint::Any, context::Context)
    push!(stack.constraints, constraint)
    if haskey(context_counts(stack), context)
        context_counts(stack)[context] += 1
    else
        context_counts(stack)[context] = 1
    end
end

function Base.pop!(stack::ConstraintStack, context::Context)
    if haskey(context_counts(stack), context)
        if context_counts(stack)[context] == 0
            return false
        end
        context_counts(stack)[context] -= 1
        pop!(constraints(stack))
        return true
    end
    return false
end

Base.iterate(stack::ConstraintStack, state = 1) = iterate(constraints(stack), state)

function save_constraint!(node_data::FactorNodeData, constraint_data::BitSetTuple)
    intersect!(node_data.factorization_constraint, constraint_data)
end

function save_fform_constraint!(node_data::VariableNodeData, constraint_data)
    opt = options(node_data)
    if !isnothing(opt.functional_form)
        @warn lazy"Node $node already has functional form constraint $(opt[:q]) applied, therefore $constraint_data will not be applied"
        return nothing
    end
    opt.functional_form = constraint_data
end

function save_message_constraint!(node_data::VariableNodeData, constraint_data)
    opt = options(node_data)
    if !isnothing(message_constraint(opt))
        @warn lazy"Node $node already has message constraint $(opt[:μ]) applied, therefore $constraint_data will not be applied"
        return nothing
    end
    opt.message_constraint = constraint_data
end

"""
    is_valid_partition(set::Set)

Returns `true` if `set` is a valid partition of the set `{1, 2, ..., maximum(Iterators.flatten(set))}`, false otherwise.
"""
function is_valid_partition(partition::Set)
    max_element = maximum(Iterators.flatten(partition))
    # bvdmitri note: perhaps we can still improve this
    if !issetequal(reduce(union, partition), BitSet(1:max_element))
        return false
    end
    for element in 1:max_element
        if sum(cluster -> element ∈ cluster, partition) != 1
            return false
        end
    end
    return true
end

@memoize function constant_constraint(num_neighbors::Int, index_constant::Int)
    constraint = BitSetTuple(num_neighbors)
    intersect!(constraint[index_constant], BitSet([index_constant]))
    for i in 1:num_neighbors
        if i != index_constant
            delete!(constraint[i], index_constant)
        end
    end
    return constraint
end

@memoize function mean_field_constraint(num_neighbors::Int)
    return BitSetTuple([[i] for i in 1:num_neighbors])
end

@memoize function mean_field_constraint(num_neighbors::Int, referenced_indices::NTuple{N, Int} where {N})
    constraint = BitSetTuple(num_neighbors)
    for i in referenced_indices
        intersect!(constraint, constant_constraint(num_neighbors, i))
    end
    return constraint
end

"""
    materialize_constraints!(model::Model)

Materializes all constraints in `Model`. This function should be called before running inference as it converts the BitSet representation of a constraint in individual nodes to the tuple representation containing all interface names.

# Arguments
- `model::Model`: The probabilistic model to materialize constraints for.

"""
function materialize_constraints!(model::Model)
    for node in Graphs.vertices(model.graph)
        materialize_constraints!(model, MetaGraphsNext.label_for(model.graph, node))
    end
end

materialize_constraints!(model::Model, node::NodeLabel) = materialize_constraints!(model, node, model[node])
materialize_constraints!(model::Model, node::NodeLabel, node_data::VariableNodeData) = nothing

"""
    materialize_constraints!(model::Model, node_label::NodeLabel, node_data::FactorNodeData)

Materializes the factorization constraint in `node_data` in `model` at `node_label`. This function converts the BitSet representation of a constraint in `node_data` to the tuple representation containing all interface names.
"""
materialize_constraints!(model::Model, node_label::NodeLabel, node_data::FactorNodeData) =
    materialize_constraints!(model, node_label, node_data, factorization_constraint(node_data))

function materialize_constraints!(model::Model, node_label::NodeLabel, node_data::FactorNodeData, constraint::BitSetTuple)
    for (i, neighbor) in enumerate(GraphPPL.neighbors(model, node_label))
        neighbor_data = model[neighbor]
        if is_factorized(neighbor_data)
            save_constraint!(node_data, constant_constraint(length(constraint), i))
        end
    end

    constraint_set = Set(BitSetTuples.contents(constraint)) #TODO test `unique`

    if !is_valid_partition(constraint_set)
        error(
            lazy"Factorization constraint set at node $node_label is not a valid constraint set. Please check your model definition and constraint specification. (Constraint set: $constraint)"
        )
    end

    edges = GraphPPL.edges(model, node_label)
    constraint = Tuple(sort!(collect(constraint_set), by = first))
    constraint = map(clusters -> Tuple(getindex.(Ref(edges), clusters)), constraint)

    node_data.factorization_constraint = constraint
end

materialize_constraints!(model::Model, node_label::NodeLabel, node_data::FactorNodeData, constraint) = nothing

get_constraint_names(constraint::NTuple{N, Tuple} where {N}) = map(entry -> GraphPPL.getname.(entry), constraint)

function __resolve(data::VariableNodeData)
    return ResolvedIndexedVariable(getname(data), index(data), getcontext(data))
end

function __resolve(data::AbstractArray{T} where {T <: VariableNodeData})
    firstdata = first(data)
    lastdata = last(data)
    return ResolvedIndexedVariable(getname(firstdata), CombinedRange(index(firstdata), index(lastdata)), getcontext(firstdata))
end

function resolve(model::Model, context::Context, variable::IndexedVariable{SplittedRange})
    global_label = unroll(context[getvariable(variable)])
    resolved_indices = __factorization_specification_resolve_index(index(variable), global_label)
    global_node_data = model[global_label[firstindex(resolved_indices):lastindex(resolved_indices)]]
    firstdata = first(global_node_data)
    lastdata = last(global_node_data)
    return ResolvedIndexedVariable(getname(firstdata), SplittedRange(index(firstdata), index(lastdata)), getcontext(firstdata))
end

function resolve(model::Model, context::Context, variable::IndexedVariable{Nothing})
    global_label = unroll(context[getvariable(variable)])
    global_node_data = model[global_label]
    return __resolve(global_node_data)
end

function resolve(model::Model, context::Context, variable::IndexedVariable)
    global_label = unroll(context[getvariable(variable)])[index(variable)]
    global_node_data = model[global_label]
    return __resolve(global_node_data)
end

function resolve(model::Model, context::Context, constraint::FactorizationConstraint)
    vfiltered = filter(variable -> haskey(context, getvariable(variable)), getvariables(constraint))
    lhs = map(variable -> resolve(model, context, variable), vfiltered)
    rhs = map(entry -> begin
        fentries = filter(var -> haskey(context, getvariable(var)), entries(entry))
        ResolvedFactorizationConstraintEntry(map(variable -> resolve(model, context, variable), fentries))
    end, getconstraint(constraint))
    return ResolvedFactorizationConstraint(ResolvedConstraintLHS(lhs), rhs)
end

function apply!(model::Model, context::Context, fform_constraint::FunctionalFormConstraint{T, F} where {T <: IndexedVariable, F})
    applicable_nodes = unroll(context[getvariables(fform_constraint)])
    for node in applicable_nodes
        save_fform_constraint!(model[node], getconstraint(fform_constraint))
    end
end

function apply!(model::Model, context::Context, fform_constraint::FunctionalFormConstraint{T, F} where {T <: AbstractArray, F})
    throw("Not implemented")
end

function apply!(model::Model, context::Context, fform_constraint::MessageConstraint)
    applicable_nodes = unroll(context[getvariables(fform_constraint)])
    for node in applicable_nodes
        save_message_constraint!(model[node], getconstraint(fform_constraint))
    end
end

"""
    apply!(model::Model, constraints::Constraints)

Applies the constraints in `constraints` to `model`. This function materializes the constraints in `constraints` and applies them to `model`.
"""
function apply!(model::Model, constraints::Constraints)
    apply!(model, GraphPPL.get_principal_submodel(model), constraints, ConstraintStack())
    materialize_constraints!(model)
end

function apply!(model::Model, context::Context, constraint_set::Constraints, resolved_factorization_constraints::ConstraintStack)
    for fc in factorization_constraints(constraint_set)
        push!(resolved_factorization_constraints, resolve(model, context, fc), context)
    end
    for ffc in functional_form_constraints(constraint_set)
        apply!(model, context, ffc)
    end
    for mc in message_constraints(constraint_set)
        apply!(model, context, mc)
    end
    for rfc in constraints(resolved_factorization_constraints)
        apply!(model, context, rfc)
    end
    for (factor_id, child) in children(context)
        if factor_id ∈ keys(specific_submodel_constraints(constraint_set))
            apply!(model, child, getconstraint(specific_submodel_constraints(constraint_set)[factor_id]), resolved_factorization_constraints)
        elseif fform(factor_id) ∈ keys(general_submodel_constraints(constraint_set))
            apply!(model, child, getconstraint(general_submodel_constraints(constraint_set)[fform(child)]), resolved_factorization_constraints)
        else
            apply!(model, child, default_constraints(fform(factor_id)), resolved_factorization_constraints)
        end
    end
    while pop!(resolved_factorization_constraints, context)
        continue
    end
end

function is_applicable(neighbors, constraint::ResolvedFactorizationConstraint)
    lhsc = lhs(constraint)
    return any(neighbors) do neighbor
        # The constraint is potentially applicable if any of the neighbor is directly listed in the LHS of the constraint
        # OR if any of its links 
        return neighbor ∈ lhsc || (!isnothing(getlink(neighbor)) && any(link -> link ∈ lhsc, getlink(neighbor)))
    end
end

function is_decoupled(var_1::VariableNodeData, var_2::VariableNodeData, constraint::ResolvedFactorizationConstraint)::Bool
    if !in_lhs(constraint, var_1) || !in_lhs(constraint, var_2)
        return false
    end
    linkvar_1 = getlink(var_1)
    linkvar_2 = getlink(var_2)

    if !isnothing(linkvar_1)
        return is_decoupled_one_linked(linkvar_1, var_2, constraint)
    elseif !isnothing(linkvar_2)
        return is_decoupled_one_linked(linkvar_2, var_1, constraint)
    end

    for entry in rhs(constraint)
        if var_1 ∈ entry
            return is_decoupled(var_2, entry)
        end
    end

    return false
end

function is_decoupled_one_linked(links, unlinked::VariableNodeData, constraint::ResolvedFactorizationConstraint)::Bool
    # Check only links that are actually relevant to the factorization constraint,
    # We skip links that are already factorized explicitly since there is no need to check them again
    flinks = Iterators.filter(link -> !is_factorized(link), links)
    # Check if all linked variables have exactly the same "is_decoupled" output
    # Otherwise we are being a bit conservative here and throw an ambiguity error
    allequal, result = lazy_bool_allequal(link -> is_decoupled(link, unlinked, constraint), flinks)
    if allequal
        return result
    else
        # Perhaps, this is possible to resolve automatically, but that would required 
        # quite some difficult graph traversal logic, so for now we just throw an error
        error(lazy"""
            Cannot resolve factorization constraint $(constraint) for an anonymous variable connected to variables $(join(links, ',')).
            As a workaround specify the name and the factorization constraint for the anonymous variable explicitly.
        """)
    end
end

function is_decoupled(var::VariableNodeData, entry::ResolvedFactorizationConstraintEntry)::Bool
    # This function checks if the `variable` is not a part of the `entry`
    for entryvar in entry.variables
        if var ∈ entryvar
            if entryvar isa ResolvedIndexedVariable{SplittedRange}
                return true # It can technically still be a prt of the `entry`, but `SplittedRange` is a special case
            else
                return false
            end
        end
    end
    return true
end

# In comparison to the standard `allequal` also supports `f -> Bool` 
# and returns the result of the very first invocation
# throws an error if the itr is empty
function lazy_bool_allequal(f, itr)::Tuple{Bool, Bool}
    started::Bool = false
    result::Bool = false
    for item in itr
        if !started
            result = f(item)::Bool
            started = true
        else
            if result !== f(item)::Bool
                return false, result
            end
        end
    end
    started || error("Empty iterator in the `lazy_bool_allequal` fucntion is not supported.")
    return true, result
end

function convert_to_bitsets(model::Model, node::NodeLabel, neighbors, constraint::ResolvedFactorizationConstraint)
    result = BitSetTuple(length(neighbors))
    for (i, v1) in enumerate(neighbors)
        for (j, v2) in enumerate(view(neighbors, (i + 1):lastindex(neighbors)))
            if is_decoupled(v1, v2, constraint)
                delete!(@inbounds(result[i]), j + i)
                delete!(@inbounds(result[j + i]), i)
            end
        end
    end
    return result
end

function apply!(model::Model, node::NodeLabel, constraint::ResolvedFactorizationConstraint)
    node_data = model[node]
    return apply!(NodeBehaviour(fform(node_data)), model, node, node_data, constraint)
end

function apply!(::Deterministic, model::Model, node::NodeLabel, node_data::FactorNodeData, constraint::ResolvedFactorizationConstraint)
    return nothing
end

function apply!(::Stochastic, model::Model, node::NodeLabel, node_data::FactorNodeData, constraint::ResolvedFactorizationConstraint)
    # Get data for the neighbors of the node and check if the constraint is applicable
    neighbors = model[GraphPPL.neighbors(model, node)]
    if is_applicable(neighbors, constraint)
        constraint = convert_to_bitsets(model, node, neighbors, constraint)
        save_constraint!(node_data, constraint)
    end
    return nothing
end

function apply!(model::Model, context::Context, constraint::ResolvedFactorizationConstraint)
    for node in values(factor_nodes(context))
        apply!(model, node, constraint)
    end
    return nothing
end
