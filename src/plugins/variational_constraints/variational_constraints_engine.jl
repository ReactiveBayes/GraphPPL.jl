import Base: showerror, Exception

struct UnresolvableFactorizationConstraintError <: Exception
    message::String
end

Base.showerror(io::IO, e::UnresolvableFactorizationConstraintError) = println(io, "Unresolvable factorization constraint: " * e.message)

const VariationalConstraintsFactorizationIndicesKey = NodeDataExtraKey{:factorization_constraint_indices, Tuple}()
const VariationalConstraintsFactorizationBitSetKey = NodeDataExtraKey{:factorization_constraint_bitset, BoundedBitSetTuple}()
const VariationalConstraintsMarginalFormConstraintKey = NodeDataExtraKey{:marginal_form_constraint, Any}()
const VariationalConstraintsMessagesFormConstraintKey = NodeDataExtraKey{:messages_form_constraint, Any}()

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
Base.length(range::CombinedRange) = lastindex(range) - firstindex(range) + 1

Base.show(io::IO, range::CombinedRange) = print(io, repr(range.from), ":", repr(range.to))

"""
    SplittedRange{L, R}

`SplittedRange` represents a range of splitted variable in factorization specification language. Such variables specified to be **not** in the same factorization cluster.

See also: [`GraphPPL.CombinedRange`](@ref)
"""
struct SplittedRange{L, R}
    from::L
    to::R
end

is_splitted(any) = false
is_splitted(range::SplittedRange) = true

Base.firstindex(range::SplittedRange) = range.from
Base.lastindex(range::SplittedRange) = range.to
Base.in(item, range::SplittedRange) = firstindex(range) <= item <= lastindex(range)
Base.in(item::NTuple{N, Int} where {N}, range::SplittedRange) = CartesianIndex(item...) ∈ firstindex(range):lastindex(range)
Base.length(range::SplittedRange) = lastindex(range) - firstindex(range) + 1

Base.show(io::IO, range::SplittedRange) = print(io, repr(range.from), "..", repr(range.to))

# This function materializes index from constraints specification to something we can use `Base.in` function to. For example constraint specification index may return `begin` or `end`
# placeholders in a form of the `FunctionalIndex` structure. This function correctly resolves all indices and check bounds as an extra step.
function __factorization_specification_resolve_index end

__factorization_specification_resolve_index(index::Any, collection::NodeLabel) =
    error("Attempt to access a single variable $(getname(collection)) at index [$(index)].") # `index` here is guaranteed to be not `nothing`, because of dispatch. `Nothing, Nothing` version will dispatch on the method below
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
    __factorization_specification_resolve_index(firstindex(index), collection)::Integer,
    __factorization_specification_resolve_index(lastindex(index), collection)::Integer
)
__factorization_specification_resolve_index(index::SplittedRange, collection::AbstractArray{<:NodeLabel, N}) where {N} =
    throw(NotImplementedError("Splitted ranges are not supported for more than 1 dimension."))
__factorization_specification_resolve_index(index::SplittedRange, collection::AbstractArray{<:NodeLabel, 1}) = SplittedRange(
    __factorization_specification_resolve_index(firstindex(index), collection)::Integer,
    __factorization_specification_resolve_index(lastindex(index), collection)::Integer
)

# Only these combinations are allowed to be merged
__factorization_split_merge_range(a::Int, b::Int) = SplittedRange(a, b)
__factorization_split_merge_range(a::FunctionalIndex, b::Int) = SplittedRange(a, b)
__factorization_split_merge_range(a::Int, b::FunctionalIndex) = SplittedRange(a, b)
__factorization_split_merge_range(a::FunctionalIndex, b::FunctionalIndex) = SplittedRange(a, b)
__factorization_split_merge_range(a::NTuple{N, Int}, b::NTuple{N, Int}) where {N} = throw(
    NotImplementedError("q(var[firstindex])..q(var[lastindex]) for index dimension $N (constraint specified with $a and $b as endpoints)")
)
__factorization_split_merge_range(a::Any, b::Any) = error("Cannot merge $(a) and $(b) indexes in `factorization_split`")

"""
    FactorizationConstraintEntry

A `FactorizationConstraintEntry` is a group of variables (represented as a `Vector` of `IndexedVariable` objects) that represents a factor group in a factorization constraint.

See also: [`GraphPPL.FactorizationConstraint`](@ref)
"""
struct FactorizationConstraintEntry{E}
    entries::E
end

entries(entry::FactorizationConstraintEntry) = entry.entries
getvariables(entry::FactorizationConstraintEntry) = map(getvariable, entries(entry)) # TODO: (bvdmitri) getvariable -> getname, is this affected?
getnames(entry::FactorizationConstraintEntry) = map(getname, entries(entry))
getindices(entry::FactorizationConstraintEntry) = map(index, entries(entry))

# These functions convert the multiplication in q(x)q(y) to a collection of `FactorizationConstraintEntry`s
Base.:(*)(left::FactorizationConstraintEntry, right::FactorizationConstraintEntry) = (left, right)
Base.:(*)(left::NTuple{N, FactorizationConstraintEntry} where {N}, right::FactorizationConstraintEntry) = (left..., right)
Base.:(*)(left::FactorizationConstraintEntry, right::NTuple{N, FactorizationConstraintEntry} where {N}) = (left, right...)
Base.:(*)(left::NTuple{N, FactorizationConstraintEntry} where {N}, right::NTuple{N, FactorizationConstraintEntry} where {N}) =
    (left..., right...)

# Because of a parsing issue, q(x)(q(y)) is not parsed as q(x) * q(y), but as (q(x))(q(y)) (function call). So we implement the function call as multiplication. 
(left::FactorizationConstraintEntry)(right::FactorizationConstraintEntry) = left * right
(left::NTuple{N, FactorizationConstraintEntry} where {N})(right::FactorizationConstraintEntry) = left * right
(left::NTuple{N, FactorizationConstraintEntry} where {N})(right::NTuple{M, FactorizationConstraintEntry} where {M}) = left * right
(left::FactorizationConstraintEntry)(right::NTuple{M, FactorizationConstraintEntry} where {M}) = left * right

function Base.show(io::IO, constraint_entry::FactorizationConstraintEntry)
    print(io, "q(")
    print(io, join(constraint_entry.entries, ", "))
    print(io, ")")
end

Base.iterate(e::FactorizationConstraintEntry, state::Int = 1) = iterate(e.entries, state)

Base.:(==)(lhs::FactorizationConstraintEntry, rhs::FactorizationConstraintEntry) =
    length(lhs.entries) == length(rhs.entries) && all(pair -> pair[1] == pair[2], zip(lhs.entries, rhs.entries))

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

function factorization_split(
    left::NTuple{N, FactorizationConstraintEntry} where {N}, right::NTuple{N, FactorizationConstraintEntry} where {N}
)
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
        if !issetequal(Set(getname.(variables)), unique(collect(Iterators.flatten(getnames.(constraint)))))
            error("Names of the variables should be the same")
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

FactorizationConstraint(variables::V, constriant::FactorizationConstraintEntry) where {V} =
    FactorizationConstraint(variables, (constriant,))

Base.:(==)(left::FactorizationConstraint, right::FactorizationConstraint) =
    left.variables == right.variables && left.constraint == right.constraint

function Base.show(io::IO, constraint::FactorizationConstraint{V, F} where {V, F <: Union{Tuple, FactorizationConstraintEntry}})
    print(io, "q(")
    print(io, join(getvariables(constraint), ", "))
    print(io, ") = ")
    print(io, join(getconstraint(constraint), ""))
end

function Base.show(io::IO, constraint::FactorizationConstraint{V, F} where {V, F})
    print(io, "q(")
    print(io, join(getvariables(constraint), ", "))
    print(io, ") = ")
    print(io, getconstraint(constraint))
end

"""
A `MarginalFormConstraint` represents a single functional form constraint in a variational marginal constraint specification. We use type parametrization
to dispatch on different types of constraints, for example `q(x, y) :: MvNormal` should be treated different from `q(x) :: Normal`.
"""
struct MarginalFormConstraint{V, F}
    variables::V
    constraint::F
end

Base.show(io::IO, constraint::MarginalFormConstraint{V, F} where {V <: AbstractArray, F}) =
    print(io, "q(", join(getvariables(constraint), ", "), ") :: ", constraint.constraint)
Base.show(io::IO, constraint::MarginalFormConstraint{V, F} where {V <: IndexedVariable, F}) =
    print(io, "q(", getvariables(constraint), ") :: ", constraint.constraint)

"""
A `MessageConstraint` represents a single constraint on the messages in a message passing schema. 
These constraints closely resemble the `MarginalFormConstraint` but are used to specify constraints on the messages in a message passing schema.
"""
struct MessageFormConstraint{V, F}
    variables::V
    constraint::F
end

Base.show(io::IO, constraint::MessageFormConstraint{V, F} where {V <: AbstractArray, F}) =
    print(io, "μ(", join(getvariables(constraint), ", "), ") :: ", constraint.constraint)
Base.show(io::IO, constraint::MessageFormConstraint{V, F} where {V <: IndexedVariable, F}) =
    print(io, "μ(", getvariables(constraint), ") :: ", constraint.constraint)

const MaterializedConstraints = Union{FactorizationConstraint, MarginalFormConstraint, MessageFormConstraint}

getvariables(c::MaterializedConstraints) = c.variables
getconstraint(c::MaterializedConstraints) = c.constraint

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

function Base.show(io::IO, constraint::Union{SpecificSubModelConstraints, GeneralSubModelConstraints})
    print(
        IOContext(io, (:indent => get(io, :indent, 0) + 2), (:head => false)),
        "q(",
        getsubmodel(constraint),
        ") = ",
        getconstraint(constraint)
    )
end

getsubmodel(c::SpecificSubModelConstraints) = c.submodel
getconstraint(c::SpecificSubModelConstraints) = c.constraints

"""
    Constraints

An instance of `Constraints` represents a set of constraints to be applied to a variational posterior in a factor graph model.
"""
struct Constraints{F, P, M, G, S, C}
    factorization_constraints::F
    marginal_form_constraints::P
    message_form_constraints::M
    general_submodel_constraints::G
    specific_submodel_constraints::S
    source_code::C
end

factorization_constraints(c::Constraints) = c.factorization_constraints
marginal_form_constraints(c::Constraints) = c.marginal_form_constraints
message_form_constraints(c::Constraints) = c.message_form_constraints
general_submodel_constraints(c::Constraints) = c.general_submodel_constraints
specific_submodel_constraints(c::Constraints) = c.specific_submodel_constraints
source_code(c::Constraints) = c.source_code

# By default `Constraints` are being created with an empty source code
Constraints() = Constraints("")

Constraints(source_code::String) = Constraints(
    Vector{FactorizationConstraint}(),
    Vector{MarginalFormConstraint}(),
    Vector{MessageFormConstraint}(),
    Dict{Function, GeneralSubModelConstraints}(),
    Dict{FactorID, SpecificSubModelConstraints}(),
    source_code
)

Constraints(constraints::Vector) = begin
    c = Constraints()
    for constraint in constraints
        Base.push!(c, constraint)
    end
    return c
end

function Base.show(io::IO, c::Constraints)
    indent = get(io, :indent, 1)
    head = get(io, :head, true)
    if head
        print(io, "Constraints: \n")
    else
        print(io, "\n")
    end
    for constraint in getconstraints(c)
        print(io, "  "^indent)
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

function Base.push!(c::Constraints, constraint::MarginalFormConstraint)
    if any(issetequal.(Set(getvariables.(c.marginal_form_constraints)), Ref(getvariables(constraint))))
        error("Cannot add $(constraint) to constraint set as these variables already have a functional form constraint applied.")
    end
    push!(c.marginal_form_constraints, constraint)
end

function Base.push!(c::Constraints, constraint::MessageFormConstraint)
    if any(getvariables.(c.message_form_constraints) .== Ref(getvariables(constraint)))
        error("Cannot add $(constraint) to constraint set as message on edge $(getvariables(constraint)) is already defined.")
    end
    push!(c.message_form_constraints, constraint)
end

function Base.push!(c::Constraints, constraint::GeneralSubModelConstraints)
    if any(keys(general_submodel_constraints(c)) .== Ref(getsubmodel(constraint)))
        error(
            "Cannot add $(constraint) to constraint set as constraints are already specified for submodels of type $(getsubmodel(constraint))."
        )
    end
    general_submodel_constraints(c)[getsubmodel(constraint)] = constraint
end

function Base.push!(c::Constraints, constraint::SpecificSubModelConstraints)
    if any(keys(specific_submodel_constraints(c)) .== Ref(getsubmodel(constraint)))
        error(
            "Cannot add $(constraint) to $(c) to constraint set as constraints are already specified for submodel $(getsubmodel(constraint))."
        )
    end
    specific_submodel_constraints(c)[getsubmodel(constraint)] = constraint
end

Base.:(==)(left::Constraints, right::Constraints) =
    left.factorization_constraints == right.factorization_constraints &&
    left.marginal_form_constraints == right.marginal_form_constraints &&
    left.message_form_constraints == right.message_form_constraints &&
    left.general_submodel_constraints == right.general_submodel_constraints &&
    left.specific_submodel_constraints == right.specific_submodel_constraints

getconstraints(c::Constraints) = Iterators.flatten((
    factorization_constraints(c),
    marginal_form_constraints(c),
    message_form_constraints(c),
    values(general_submodel_constraints(c)),
    values(specific_submodel_constraints(c))
))

Base.push!(c_set::GeneralSubModelConstraints, c) = push!(getconstraint(c_set), c)
Base.push!(c_set::SpecificSubModelConstraints, c) = push!(getconstraint(c_set), c)

struct ResolvedIndexedVariable{T}
    variable::IndexedVariable{T}
    context::Context
end

ResolvedIndexedVariable(variable::Symbol, index, context::Context) = ResolvedIndexedVariable(IndexedVariable(variable, index), context)

getvariable(var::ResolvedIndexedVariable) = var.variable
getname(var::ResolvedIndexedVariable) = getname(getvariable(var))
index(var::ResolvedIndexedVariable) = index(getvariable(var))
getcontext(var::ResolvedIndexedVariable) = var.context

Base.show(io::IO, var::ResolvedIndexedVariable{T}) where {T} = print(io, getvariable(var))

Base.in(nodedata::NodeData, var::ResolvedIndexedVariable) = in(nodedata, getproperties(nodedata), var)

Base.in(
    nodedata::NodeData, properties::VariableNodeProperties, var::ResolvedIndexedVariable{T} where {T <: Union{Int, NTuple{N, Int} where N}}
) = Base.in(nodedata, properties, var, index(properties))

Base.in(
    nodedata::NodeData,
    properties::VariableNodeProperties,
    var::ResolvedIndexedVariable{T} where {T <: Union{Int, NTuple{N, Int} where N}},
    i::Union{Int, Nothing}
) = (getname(var) == getname(properties)) && (index(var) == index(properties)) && (getcontext(var) == getcontext(nodedata))

Base.in(
    nodedata::NodeData,
    properties::VariableNodeProperties,
    var::ResolvedIndexedVariable{T} where {T <: Union{Int, NTuple{N, Int} where N}},
    i::NTuple{M, Int} where {M}
) =
    (getname(properties) == getname(var)) &&
    (flattened_index(getcontext(var)[getname(var)], i) ∈ index(var)) &&
    (getcontext(var) == getcontext(nodedata))

Base.in(nodedata::NodeData, properties::VariableNodeProperties, var::ResolvedIndexedVariable{T} where {T <: Nothing}) =
    (getname(var) == getname(properties)) && (getcontext(var) == getcontext(nodedata))

Base.in(
    nodedata::NodeData,
    properties::VariableNodeProperties,
    var::ResolvedIndexedVariable{T} where {T <: Union{SplittedRange, CombinedRange, UnitRange}}
) = Base.in(nodedata, properties, var, index(properties))

Base.in(
    nodedata::NodeData,
    properties::VariableNodeProperties,
    var::ResolvedIndexedVariable{T} where {T <: Union{SplittedRange, CombinedRange, UnitRange}},
    i::NTuple{N, Int} where {N}
) =
    (getname(properties) == getname(var)) &&
    (flattened_index(getcontext(var)[getname(var)], i) ∈ index(var)) &&
    (getcontext(var) == getcontext(nodedata))

Base.in(
    nodedata::NodeData,
    properties::VariableNodeProperties,
    var::ResolvedIndexedVariable{T} where {T <: Union{SplittedRange, CombinedRange, UnitRange}},
    i::Int
) = (getname(properties) == getname(var)) && (i ∈ index(var)) && (getcontext(var) == getcontext(nodedata))

Base.in(
    nodedata::NodeData,
    properties::VariableNodeProperties,
    var::ResolvedIndexedVariable{T} where {T <: Union{SplittedRange, CombinedRange, UnitRange}},
    i::Nothing
) = false

struct ResolvedConstraintLHS{V}
    variables::V
end

getvariables(var::ResolvedConstraintLHS) = var.variables

Base.in(nodedata::NodeData, var::ResolvedConstraintLHS) = any(map(v -> (nodedata ∈ v)::Bool, getvariables(var)))

Base.:(==)(left::ResolvedConstraintLHS, right::ResolvedConstraintLHS) = getvariables(left) == getvariables(right)

struct ResolvedFactorizationConstraintEntry{V}
    variables::V
end

getvariables(var::ResolvedFactorizationConstraintEntry) = var.variables

Base.in(nodedata::NodeData, var::ResolvedFactorizationConstraintEntry) = any(map(v -> (nodedata ∈ v)::Bool, getvariables(var)))

struct ResolvedFactorizationConstraint{V <: ResolvedConstraintLHS, F}
    lhs::V
    rhs::F
end

Base.:(==)(
    left::ResolvedFactorizationConstraint{V, F} where {V <: ResolvedConstraintLHS, F},
    right::ResolvedFactorizationConstraint{V, F} where {V <: ResolvedConstraintLHS, F}
) = left.lhs == right.lhs && left.rhs == right.rhs

lhs(constraint::ResolvedFactorizationConstraint) = constraint.lhs
rhs(constraint::ResolvedFactorizationConstraint) = constraint.rhs

function in_lhs(constraint::ResolvedFactorizationConstraint, node::NodeData)
    return in_lhs(constraint, node, getproperties(node))
end

function in_lhs(constraint::ResolvedFactorizationConstraint, node::NodeData, properties::VariableNodeProperties)
    return (in(node, lhs(constraint)) || !isnothing(getlink(properties)) && any(l -> in_lhs(constraint, l), getlink(properties)))::Bool
end

struct ResolvedFunctionalFormConstraint{V <: ResolvedConstraintLHS, F}
    lhs::V
    rhs::F
end

lhs(constraint::ResolvedFunctionalFormConstraint) = constraint.lhs
rhs(constraint::ResolvedFunctionalFormConstraint) = constraint.rhs

const ResolvedConstraint = Union{ResolvedFactorizationConstraint, ResolvedFunctionalFormConstraint}

struct ConstraintStack
    constraints::Stack{ResolvedConstraint}
    context_counts::Dict{Context, Int}
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

function mean_field_constraint!(constraint::BoundedBitSetTuple)
    fill!(contents(constraint), false)
    for i in 1:length(constraint)
        constraint[i, i] = true
    end
    return constraint
end

function mean_field_constraint!(constraint::BoundedBitSetTuple, index::Int)
    return mean_field_constraint!(constraint, (index,))
end

function mean_field_constraint!(constraint::BoundedBitSetTuple, referenced_indices::NTuple{N, Int} where {N})
    for i in referenced_indices
        constraint[i, :] = false
        constraint[:, i] = false
        constraint[i, i] = true
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
    for node in labels(model)
        materialize_constraints!(model, node)
    end
end

"""
    materialize_constraints!(model::Model, node_label::NodeLabel, node_data::NodeData)

Materializes the factorization constraint in `node_data` in `model` at `node_label`. 
This function converts the BitSet representation of a constraint in `node_data` to the tuple representation containing all interface names.
"""
function materialize_constraints! end

function materialize_constraints!(model::Model, node::NodeLabel)
    return materialize_constraints!(model, node, model[node])
end

function materialize_constraints!(model::Model, node_label::NodeLabel, node_data::NodeData)
    return materialize_constraints!(model, node_label, node_data, getproperties(node_data))
end

function materialize_constraints!(model::Model, node_label::NodeLabel, node_data::NodeData, properties::FactorNodeProperties)
    constraint_bitset = getextra(node_data, VariationalConstraintsFactorizationBitSetKey)

    # Factorize out `neighbors` for which `is_factorized` is `true`
    materialize_is_factorized_neighbors!(constraint_bitset, neighbor_data(properties))

    constraint_set = unique(eachcol(contents(constraint_bitset)))

    if !is_valid_partition(constraint_set)
        error(
            lazy"Factorization constraint set at node $node_label is not a valid constraint set. Please check your model definition and constraint specification. (Constraint set: $constraint_bitset)"
        )
    end

    rows = Tuple(map(row -> filter(!iszero, map(elem -> elem[2] == 1 ? elem[1] : 0, enumerate(row))), constraint_set))
    setextra!(node_data, VariationalConstraintsFactorizationIndicesKey, rows)
end

function materialize_is_factorized_neighbors!(constraint_bitset::BoundedBitSetTuple, neighbors)
    for (i, neighbor) in enumerate(neighbors)
        if is_factorized(neighbor)
            mean_field_constraint!(constraint_bitset, i)
        end
    end
    return constraint_bitset
end

function is_valid_partition(contents)
    max_element = length(first(contents))
    for element in 1:max_element
        element_partition_count = sum(partition -> partition[element], contents)
        # If element is not present in at least one partition
        # or if it is present in more than one partition
        if element_partition_count !== 1
            return false
        end
    end
    return true
end

function materialize_constraints!(model::Model, node_label::NodeLabel, node_data::NodeData, ::VariableNodeProperties)
    return nothing
end

get_constraint_names(constraint::NTuple{N, Tuple} where {N}) = map(entry -> GraphPPL.getname.(entry), constraint)

__resolve_index_consistency(model, labels, findex::Int, lindex::Int) = (findex, lindex)
function __resolve_index_consistency(model, labels, findex::NTuple{N, Int}, lindex::NTuple{N, Int}) where {N}
    differing_indices = findall(map(indices -> indices[1] != indices[2], zip(findex, lindex)))
    if length(differing_indices) == 1 && first(differing_indices) == N
        full_array = model[first(labels[1])].context[first(labels[1]).name] # This black magic line gets the full array of the sliced variable that we need to acces. It accesses it through the context which is saved in the nodedata.
        return flattened_index(full_array, findex), flattened_index(full_array, lindex)
    else
        throw(
            NotImplementedError(
                "Congratulations, you tried to define a factorization constraint for a >2 dimensional random variable where there is either more than one differing index between the endpoints of the constraint, or you've sliced the random variable in more than 1 dimension. We've thought about this
edge case but don't know how we can resolve this, let alone efficiently. Please open an issue on GitHub if you need this feature, or consider changing your model definition. Furthermore, PR's are always welcome!"
            )
        )
    end
end

__resolve(model::Model, label::VariableRef) = __resolve(model, getifcreated(model, label.context, label))
__resolve(model::Model, label::AbstractArray{T}) where {T <: VariableRef} =
    __resolve(model, map(l -> getifcreated(model, l.context, l), label))

function __resolve(model::Model, label::NodeLabel)
    data = model[label]
    return __resolve(model, data, getproperties(data), index(getproperties(data)))
end

function __resolve(::Model, data::NodeData, properties::VariableNodeProperties, i::Union{Nothing, Int})
    # The variable is either a single variable or in a vector, then we don't really care.
    return ResolvedIndexedVariable(getname(properties), i, getcontext(data))
end

function __resolve(model::Model, data::NodeData, properties::VariableNodeProperties, i::NTuple{N, Int} where {N})
    # The variable is either a single variable or in a vector, then we don't really care.
    full_array = getcontext(data)[getname(properties)]
    return ResolvedIndexedVariable(getname(properties), flattened_index(full_array, i), getcontext(data))
end

function __resolve(model::Model, labels::AbstractArray{T, 1}) where {T <: NodeLabel}
    fdata = model[first(labels)]
    ldata = model[last(labels)]
    if getname(getproperties(fdata)) != getname(getproperties(ldata))
        throw(
            UnresolvableFactorizationConstraintError(
                "Cannot resolve factorization constraint for $(getname(getproperties(fdata))) and $(getname(getproperties(ldata)))."
            )
        )
    end
    # If we make a slice of a matrix in the constraints, we end up here (for example, q(x[1], x[2]) = q(x[1])q(x[2]) for matrix valued x). 
    # Then `index(getproperties(fdata))` and `index(getproperties(ldata))` will be `Tuple`, and we need to resolve this to a single `Int` in the dimension in which they differ
    findex = index(getproperties(fdata))
    lindex = index(getproperties(ldata))
    findex, lindex = __resolve_index_consistency(model, labels, findex, lindex)

    return ResolvedIndexedVariable(getname(getproperties(fdata)), CombinedRange(findex, lindex), getcontext(fdata))
end

function __resolve(model::Model, labels::AbstractArray{T, N} where {T <: NodeLabel}) where {N}
    findex, flabel = firstwithindex(labels)
    lindex, llabel = lastwithindex(labels)

    fdata = model[flabel]
    ldata = model[llabel]

    # We have to test whether or not the `ResizableArray` of labels passed is a slice. If it is, we throw because the constraint is unresolvable
    if CartesianIndex(index(getproperties(fdata))) != findex || CartesianIndex(index(getproperties(ldata))) != lindex
        throw(
            UnresolvableFactorizationConstraintError(
                lazy"Did you pass a slice of the variable to a submodel ($(getname(getproperties(fdata)))), and then tried to factorize it? These partial factorization constraints cannot be resolved and are not supported."
            )
        )
    end

    return ResolvedIndexedVariable(
        getname(getproperties(fdata)),
        CombinedRange(flattened_index(labels, findex.I), flattened_index(labels, lindex.I)),
        getcontext(fdata)
    )
end

function resolve(model::Model, context::Context, variable::IndexedVariable{<:SplittedRange})
    global_label = unroll(context[getname(variable)])
    resolved_indices = __factorization_specification_resolve_index(index(variable), global_label)
    firstdata = model[global_label[firstindex(resolved_indices)]]
    lastdata = model[global_label[lastindex(resolved_indices)]]
    if getname(getproperties(firstdata)) != getname(getproperties(lastdata))
        error("Cannot resolve factorization constraint for $(getname(getproperties(firstdata))) and $(getname(getproperties(lastdata))).")
    end
    return ResolvedIndexedVariable(
        getname(getproperties(firstdata)),
        SplittedRange(index(getproperties(firstdata)), index(getproperties(lastdata))),
        getcontext(firstdata)
    )
end

# The variational constraints plugin should not attempt to create new variables in the model
# Even if the `maycreate` flag was set to `True` at this point we assume that the variable has been created already
unroll_nocreate(something) = unroll(set_maycreate(something, False()))

function resolve(model::Model, context::Context, variable::IndexedVariable{Nothing})
    global_label = unroll_nocreate(context[getname(variable)])
    return __resolve(model, global_label)
end

function resolve(model::Model, context::Context, variable::IndexedVariable)
    global_label = unroll_nocreate(context[getname(variable)])[index(variable)...]
    return __resolve(model, global_label)
end

resolve(model::Model, context::Context, variable::IndexedVariable{CombinedRange{NTuple{N, Int}, NTuple{N, Int}}}) where {N} =
    throw(UnresolvableFactorizationConstraintError("Cannot resolve factorization constraint for a combined range of dimension > 2."))

function resolve(model::Model, context::Context, variable::IndexedVariable{<:CombinedRange})
    global_label = view(unroll_nocreate(context[getname(variable)]), firstindex(index(variable)):lastindex(index(variable)))
    return __resolve(model, global_label)
end

function resolve(model::Model, context::Context, constraint::FactorizationConstraint)
    vfiltered = filter(variable -> haskey(context, getname(variable)), getvariables(constraint))
    if length(vfiltered) != length(getvariables(constraint))
        @warn "Some variables in factorization constraint $constraint are not present in the context."
    end
    lhs = map(variable -> resolve(model, context, variable), vfiltered)
    rhs = map(
        entry -> begin
            fentries = filter(var -> haskey(context, getname(var)), entries(entry))
            ResolvedFactorizationConstraintEntry(map(variable -> resolve(model, context, variable), fentries))
        end,
        getconstraint(constraint)
    )
    return ResolvedFactorizationConstraint(ResolvedConstraintLHS(lhs), rhs)
end

resolve(model::Model, context::Context, variable::NodeLabel, ::MeanField) = __resolve(model, variable)
resolve(model::Model, context::Context, variable::AbstractArray{<:NodeLabel, N}, ::MeanField) where {N} = begin
    firstdata = first(model[variable])
    ResolvedIndexedVariable(
        getname(getproperties(firstdata)), SplittedRange(firstindex(variable), lastindex(variable)), getcontext(firstdata)
    )
end

function resolve(model::Model, context::Context, constraint::FactorizationConstraint{V, <:MeanField} where {V})
    vfiltered = filter(variable -> haskey(context, getname(variable)), getvariables(constraint))
    if length(vfiltered) != length(getvariables(constraint))
        @warn "Some variables in factorization constraint $constraint are not present in the context."
    end
    lhs = map(variable -> resolve(model, context, variable), vfiltered)
    rhs = map(
        variable ->
            ResolvedFactorizationConstraintEntry((resolve(model, context, unroll_nocreate(context[getname(variable)]), MeanField()),)),
        vfiltered
    )
    return ResolvedFactorizationConstraint(ResolvedConstraintLHS(lhs), rhs)
end

function is_factorized(nodedata::AbstractNodeData)
    properties = getproperties(nodedata)
    if is_constant(properties)
        return true
    end
    _factorized = hasextra(nodedata, :factorized) ? getextra(nodedata, :factorized) : false
    if _factorized
        return true
    end
    if !isnothing(getlink(properties))
        return all(link -> is_factorized(link), getlink(properties))::Bool
    end
    return false
end

function is_applicable(neighbors, constraint::ResolvedFactorizationConstraint)
    lhsc = lhs(constraint)
    return any(neighbors) do neighbor
        # The constraint is potentially applicable if any of the neighbor is directly listed in the LHS of the constraint
        # OR if any of its links 
        plink = getlink(getproperties(neighbor))
        return neighbor ∈ lhsc || (!isnothing(plink) && any(link -> link ∈ lhsc, plink))
    end
end

function is_decoupled(var_1::NodeData, var_2::NodeData, constraint::ResolvedFactorizationConstraint)
    return is_decoupled(
        var_1, getproperties(var_1)::VariableNodeProperties, var_2, getproperties(var_2)::VariableNodeProperties, constraint
    )
end

function is_decoupled(
    var_1::NodeData,
    var_1_properties::VariableNodeProperties,
    var_2::NodeData,
    var_2_properties::VariableNodeProperties,
    constraint::ResolvedFactorizationConstraint
)::Bool
    if !in_lhs(constraint, var_1, var_1_properties) || !in_lhs(constraint, var_2, var_2_properties)
        return false
    end

    linkvar_1 = getlink(var_1_properties)
    linkvar_2 = getlink(var_2_properties)

    if !isnothing(linkvar_1)
        return is_decoupled_one_linked(linkvar_1, var_2, constraint)
    elseif !isnothing(linkvar_2)
        return is_decoupled_one_linked(linkvar_2, var_1, constraint)
    end

    return any(rhs(constraint)) do entry
        return var_1 ∈ entry && is_decoupled(var_2, entry)::Bool
    end
end

function is_decoupled_one_linked(links, unlinked::NodeData, constraint::ResolvedFactorizationConstraint)::Bool
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
        throw(UnresolvableFactorizationConstraintError(lazy"""
        Cannot resolve factorization constraint $(constraint) for an anonymous variable connected to variables $(join(links, ',')).
            As a workaround specify the name and the factorization constraint for the anonymous variable explicitly.
        """))
    end
end

__is_splittedrange(::ResolvedIndexedVariable{<:SplittedRange}) = true
__is_splittedrange(::ResolvedIndexedVariable) = false

function is_decoupled(var::NodeData, entry::ResolvedFactorizationConstraintEntry)::Bool
    # This function checks if the `variable` is not a part of the `entry`
    return all(entry.variables) do entryvar
        return var ∉ entryvar || __is_splittedrange(entryvar)
    end
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
    result = BoundedBitSetTuple(length(neighbors))
    for (i, v1) in enumerate(neighbors)
        for (j, v2) in enumerate(neighbors)
            if j > i && is_decoupled(v1, v2, constraint)
                delete!(result, i, j)
                delete!(result, j, i)
            end
        end
    end
    return result
end

function apply_constraints!(
    model::Model, context::Context, marginal_constraint::MarginalFormConstraint{T, F} where {T <: IndexedVariable, F}
)
    applicable_nodes = unroll_nocreate(context[getvariables(marginal_constraint)])
    for node in applicable_nodes
        if hasextra(model[node], VariationalConstraintsMarginalFormConstraintKey)
            @warn lazy"Node $node already has functional form constraint $(opt[:q]) applied, therefore $constraint_data will not be applied"
        else
            setextra!(model[node], VariationalConstraintsMarginalFormConstraintKey, getconstraint(marginal_constraint))
        end
    end
end

function apply_constraints!(model::Model, context::Context, marginal_constraint::MarginalFormConstraint{T, F} where {T <: AbstractArray, F})
    throw("Not implemented")
end

function apply_constraints!(model::Model, context::Context, message_constraint::MessageFormConstraint)
    applicable_nodes = unroll_nocreate(context[getvariables(message_constraint)])
    for node in applicable_nodes
        if hasextra(model[node], VariationalConstraintsMessagesFormConstraintKey)
            @warn lazy"Node $node already has functional form constraint $(opt[:q]) applied, therefore $constraint_data will not be applied"
        else
            setextra!(model[node], VariationalConstraintsMessagesFormConstraintKey, getconstraint(message_constraint))
        end
    end
end

function apply_constraints!(model::Model, context::Context, constraints)
    return apply_constraints!(model, context, constraints, ConstraintStack())
end

# Mean-field constraint simply applies the entire mean-field factorization to all the nodes in the model
# Ignores `default_constraints` from the submodels and forces everything to be `MeanField`
function apply_constraints!(model::Model, ::Context, ::MeanField, ::ConstraintStack)
    factor_nodes(model) do _, data
        constraint_bitset = getextra(data, VariationalConstraintsFactorizationBitSetKey)
        mean_field_constraint!(constraint_bitset)
    end
end

function apply_constraints!(model::Model, context::Context, constraint_set::Constraints, stack::ConstraintStack)
    foreach(factorization_constraints(constraint_set)) do fc
        push!(stack, resolve(model, context, fc), context)
    end
    foreach(marginal_form_constraints(constraint_set)) do ffc
        apply_constraints!(model, context, ffc)
    end
    foreach(message_form_constraints(constraint_set)) do mc
        apply_constraints!(model, context, mc)
    end
    foreach(constraints(stack)) do rfc
        apply_constraints!(model, context, rfc)
    end
    for (factor_id, child) in pairs(children(context))
        if factor_id ∈ keys(specific_submodel_constraints(constraint_set))
            apply_constraints!(model, child, getconstraint(specific_submodel_constraints(constraint_set)[factor_id]), stack)
        elseif fform(factor_id) ∈ keys(general_submodel_constraints(constraint_set))
            apply_constraints!(model, child, getconstraint(general_submodel_constraints(constraint_set)[fform(child)]), stack)
        else
            apply_constraints!(model, child, default_constraints(fform(factor_id)), stack)
        end
    end
    while pop!(stack, context)
        continue
    end
end

function apply_constraints!(model::Model, node::NodeLabel, constraint::ResolvedFactorizationConstraint)
    node_data = model[node]
    node_properties = getproperties(node_data)
    return apply_constraints!(NodeBehaviour(model, fform(node_properties)), model, node, node_data, node_properties, constraint)
end

function apply_constraints!(
    ::Deterministic,
    model::Model,
    node::NodeLabel,
    node_data::NodeData,
    node_properties::FactorNodeProperties,
    constraint::ResolvedFactorizationConstraint
)
    return nothing
end

function apply_constraints!(
    ::Stochastic,
    model::Model,
    node::NodeLabel,
    node_data::NodeData,
    node_properties::FactorNodeProperties,
    constraint::ResolvedFactorizationConstraint
)
    # Get data for the neighbors of the node and check if the constraint is applicable
    neighbors = neighbor_data(node_properties)
    constraint_bitset = getextra(node_data, VariationalConstraintsFactorizationBitSetKey)
    if is_applicable(neighbors, constraint)
        intersect!(constraint_bitset, convert_to_bitsets(model, node, neighbors, constraint))
    end
    return nothing
end

function apply_constraints!(model::Model, context::Context, constraint::ResolvedFactorizationConstraint)
    for node in values(factor_nodes(context))
        apply_constraints!(model, node, constraint)
    end
    return nothing
end
