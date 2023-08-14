export MeanField, FullFactorization

using StaticArrays
using Unrolled
using BitSetTuples

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

"""
    FunctionalIndex(collection)

Returns the result of applying the function `f` to the collection.
"""
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
getvariable(index::IndexedVariable) = index.variable
getindex(index::IndexedVariable) = index.index

Base.length(index::IndexedVariable{T} where {T}) = 1
Base.iterate(index::IndexedVariable{T} where {T}) = (index, nothing)
Base.iterate(index::IndexedVariable{T} where {T}, any) = nothing
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
    error("Attempt to access a single variable $(getname(collection)) at index [$(index)].") # `index` here is guaranteed to be not `nothing`, because of dispatch. `Nothing, Nothing` version will dispatch on the method below
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
        "Index out of bounds happened during indices resolution in factorization constraints. Attempt to access collection $(collection) of variable $(getname(collection)) at index [$(index)].",
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

"""
    FactorizationConstraintEntry

A `FactorizationConstraintEntry` is a group of variables (represented as a `Vector` of `IndexedVariable` objects) that represents a factor group in a factorization constraint.

See also: [`GraphPPL.FactorizationConstraint`](@ref)
"""
struct FactorizationConstraintEntry{T<:IndexedVariable}
    entries::Vector{T}
end

getvariables(entry::FactorizationConstraintEntry{T} where {T}) = getvariable.(entry.entries)

# These functions convert the multiplication in q(x)q(y) to a collection of `FactorizationConstraintEntry`s
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
) = [left..., right...]


function Base.show(io::IO, constraint_entry::FactorizationConstraintEntry)
    print(io, "q(")
    print(io, join(constraint_entry.entries, ", "))
    print(io, ")")
end

Base.iterate(e::FactorizationConstraintEntry, state::Int = 1) = iterate(e.entries, state)

Base.:(==)(lhs::FactorizationConstraintEntry, rhs::FactorizationConstraintEntry) =
    length(lhs.entries) == length(rhs.entries) &&
    all(pair -> pair[1] == pair[2], zip(lhs.entries, rhs.entries))

getnames(entry::FactorizationConstraintEntry) = [e.variable for e in entry.entries]
getindices(entry::FactorizationConstraintEntry) = Tuple([e.index for e in entry.entries])

"""
    factorization_split(left, right)

Creates a new `FactorizationConstraintEntry` that contains a `SplittedRange` splitting `left` and `right`. 
This function is used to convert two `FactorizationConstraintEntry`s (for example `q(x[begin])..q(x[end])`) into a single `FactorizationConstraintEntry` containing the `SplittedRange`.

    See also: [`GraphPPL.SplittedRange`](@ref)
"""
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


"""
    FactorizationConstraint{V, F}

A `FactorizationConstraint` represents a single factorization constraint in a variational posterior constraint specification. We use type parametrization 
to dispatch on different types of constraints, for example `q(x, y) = MeanField()` is treated different from `q(x, y) = q(x)q(y)`. 

The `FactorizationConstraint` constructor checks for obvious errors, such as duplicate variables in the constraint specification and checks if the left hand side and right hand side contain the same variables.

    See also: [`GraphPPL.FactorizationConstraintEntry`](@ref)
"""
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
            error(
                "Variables in right hand side of constraint ($(constraint...)) can only occur once",
            )
        end
        return new{V,typeof(constraint)}(variables, constraint)
    end
    function FactorizationConstraint(variables::V, constraint::F) where {V,F}
        return new{V,F}(variables, constraint)
    end
end

Base.:(==)(left::FactorizationConstraint, right::FactorizationConstraint) =
    left.variables == right.variables && left.constraint == right.constraint

"""
    FunctionalFormConstraint{V, F}

A `FunctionalFormConstraint` represents a single functional form constraint in a variational posterior constraint specification. We use type parametrization
to dispatch on different types of constraints, for example `q(x, y) :: MvNormal` should be treated different from `q(x) :: Normal`.
"""
struct FunctionalFormConstraint{V,F}
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

const MaterializedConstraints =
    Union{FactorizationConstraint,FunctionalFormConstraint,MessageConstraint}

getvariables(c::MaterializedConstraints) = c.variables
getconstraint(c::MaterializedConstraints) = c.constraint

function Base.show(
    io::IO,
    constraint::FactorizationConstraint{
        V,
        F,
    } where {V,F<:Union{AbstractArray,FactorizationConstraintEntry}},
)
    print(io, "q(")
    print(io, join(getvariables(constraint), ", "))
    print(io, ") = ")
    print(io, join(getconstraint(constraint), ""))
end

Base.show(io::IO, constraint::FunctionalFormConstraint{V,F} where {V<:AbstractArray,F}) =
    print(io, "q(", join(getvariables(constraint), ", "), ") :: ", constraint.constraint)
Base.show(io::IO, constraint::FunctionalFormConstraint{V,F} where {V<:IndexedVariable,F}) =
    print(io, "q(", getvariables(constraint), ") :: ", constraint.constraint)

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

fform(c::GeneralSubModelConstraints) = c.fform
Base.show(io::IO, constraint::GeneralSubModelConstraints) =
    print(io, "q(", getsubmodel(constraint), ") :: ", getconstraint(constraint))

getsubmodel(c::GeneralSubModelConstraints) = c.fform
getconstraint(c::GeneralSubModelConstraints) = c.constraints

"""
    SpecificSubModelConstraints

A `SpecificSubModelConstraints` represents a set of constraints to be applied to a specific submodel. The submodel is specified by the `tag` field, which contains the identifier of the submodel. 

See also: [`GraphPPL.GeneralSubModelConstraints`](@ref)
"""
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

"""
    Constraints

An instance of `Constraints` represents a set of constraints to be applied to a variational posterior in a factor graph model. These constraints can be applied using `apply!`.

See also: [`GraphPPL.apply!`](@ref)
"""
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
    push!(c.factorization_constraints, constraint)
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
    push!(c.functional_form_constraints, constraint)
end

function Base.push!(c::Constraints, constraint::MessageConstraint)
    if any(getvariables.(c.message_constraints) .== Ref(getvariables(constraint)))
        error(
            "Cannot add $(constraint) to constraint set as message on edge $(getvariables(constraint)) is already defined.",
        )
    end
    push!(c.message_constraints, constraint)
end

function Base.push!(c::Constraints, constraint::GeneralSubModelConstraints)
    if any(getsubmodel.(c.submodel_constraints) .== Ref(getsubmodel(constraint)))
        error(
            "Cannot add $(constraint) to constraint set as constraints are already specified for submodels of type $(getsubmodel(constraint)).",
        )
    end
    push!(c.submodel_constraints, constraint)
end

function Base.push!(c::Constraints, constraint::SpecificSubModelConstraints)
    if any(getsubmodel.(c.submodel_constraints) .== Ref(getsubmodel(constraint)))
        error(
            "Cannot add $(constraint) to $(c) to constraint set as constraints are already specified for submodel $(getsubmodel(constraint)).",
        )
    end
    push!(c.submodel_constraints, constraint)
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
    push!(getconstraint(c_set), c)
Base.push!(c_set::SpecificSubModelConstraints, c::Constraint) =
    push!(getconstraint(c_set), c)



SubModelConstraints(x::Symbol, constraints = Constraints()::Constraints) =
    SpecificSubModelConstraints(x, constraints)
SubModelConstraints(fform::Function, constraints = Constraints()::Constraints) =
    GeneralSubModelConstraints(fform, constraints)

"""
    applicable_nodes(::Model, ::Context, ::FactorizationConstraint)

Checks which nodes in a factor graph model are affected by a `FactorizationConstraint`. This is done by checking which factor nodes are neighbors of the variable nodes in the constraint.
"""
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

"""
    applicable_nodes(::Model, ::Context, ::FunctionalFormConstraint{<:IndexedVariable,::Any})

Checks which nodes in a factor graph model are affected by a `FunctionalFormConstraint`. This is done by checking which variable nodes are referenced in the constraint.
"""
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

"""
    applicable_nodes(::Model, ::Context, ::FunctionalFormConstraint{<:AbstractArray,::Any})

Checks which nodes in a factor graph model are affected by a `FunctionalFormConstraint`. This is done by checking which variable nodes are referenced in the constraint.
"""
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

"""
    prepare_factorization_constraint(::Context, ::FactorizationConstraint)

Prepares a `FactorizationConstraint` for use in a factor graph model. This function converts, for example, `MeanField` factorizations to `FactorizationConstraintEntry` objects. 
Other default strategies for applying factorization constraints should implement their own method for this function.
"""
prepare_factorization_constraint(
    context::Context,
    constraint::FactorizationConstraint{V,F} where {V,F},
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

__resolve_index_or_nodelabel(index::Nothing, collection::AbstractArray) = vec(collection)
__resolve_index_or_nodelabel(index::Nothing, label::NodeLabel) = label



function get_indexed_variable(context::Context, var::IndexedVariable{Nothing})
    return __resolve_index_or_nodelabel(nothing, context[var.variable])
end

get_indexed_variable(context::Context, var::IndexedVariable{<:Int}) =
    context[var.variable][var.index]

function get_indexed_variable(context::Context, var::IndexedVariable{<:CombinedRange})
    array = context[var.variable]
    index = __factorization_specification_resolve_index(var.index, array)
    return array[firstindex(index):lastindex(index)]
end

get_indexed_variable(context::Context, var::IndexedVariable{<:AbstractArray{<:Int}}) =
    context[var.variable][var.index...]

"""
    get_indexed_variable(context::Context, var::IndexedVariable{FunctionalIndex})

Get the indexed variable from the context.

This function takes in a `Context` and an `IndexedVariable` with a `FunctionalIndex` and returns the indexed variable from the context.

"""
function get_indexed_variable(context::Context, var::IndexedVariable{FunctionalIndex})
    array = context[var.variable]
    index = var.index(array)
    return array[index]
end

"""
    get_factorization_constraint_variables(context::Context, var::FactorizationConstraintEntry)

Get the variables for a `FactorizationConstraintEntry`.

This function takes in a `Context` and a `FactorizationConstraintEntry` and returns a vector of `NodeLabel`s. It calls `get_indexed_variable` for each variable in the entry and concatenates the resulting vectors of `NodeLabel`s.

"""
function get_factorization_constraint_variables(
    context::Context,
    var::FactorizationConstraintEntry,
)
    result = [get_indexed_variable(context, v) for v in var.entries]
    return Vector{GraphPPL.NodeLabel}[collect(Iterators.flatten(result))]
end

"""
    get_factorization_constraint_variables(context::Context, var::FactorizationConstraintEntry{<:IndexedVariable{<:SplittedRange}})

Get the variables for a `FactorizationConstraintEntry` with a `SplittedRange` index.

This function takes in a `Context` and a `FactorizationConstraintEntry` with a `SplittedRange` index and returns a vector of `NodeLabel`s. 
It calls `__factorization_specification_resolve_index` to resolve the indices and `get_indexed_variable` for each variable in the entry and concatenates the resulting vectors of `NodeLabel`s.

"""
function get_factorization_constraint_variables(
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
        push!(result, [variables[j][indices[j]] for j = 1:length(variables)])
    end
    return result
end

"""
    factorization_constraint_entries_to_nodelabel(context::Context, entries::AbstractArray{<:FactorizationConstraintEntry})

Convert an array of `FactorizationConstraintEntry` objects to an array of node labels.

This function takes in a `Context` and an array of `FactorizationConstraintEntry` objects and returns an array of node labels. 
It calls `get_factorization_constraint_variables` for each entry and concatenates the resulting vectors of node labels.

"""
function factorization_constraint_entries_to_nodelabel(
    context::Context,
    entries::AbstractArray{<:FactorizationConstraintEntry},
)
    result = Vector{GraphPPL.NodeLabel}[]
    for entry in entries
        variables = get_factorization_constraint_variables(context, entry)
        result = vcat(result, variables)
    end
    return result
end

"""
    factorization_constraint_entries_to_nodelabel(context::Context, entry::FactorizationConstraintEntry)

Get the variables for a single `FactorizationConstraintEntry`.

This function takes in a `Context` and a single `FactorizationConstraintEntry` and returns a vector of `NodeLabel`s. 
    It calls `get_factorization_constraint_variables` for the entry and returns the resulting vector of `NodeLabel`s.

"""
factorization_constraint_entries_to_nodelabel(
    context::Context,
    entry::FactorizationConstraintEntry,
) = get_factorization_constraint_variables(context, entry)


"""
    factorization_constraint_to_nodelabels(context::Context, constraint_data::FactorizationConstraint)

Get the node labels for a `FactorizationConstraint`.

This function takes in a `Context` and a `FactorizationConstraint` and returns an array of node labels. 
It calls `getconstraint` to get the `FactorizationConstraintEntry` objects and `factorization_constraint_entries_to_nodelabel` to convert them to node labels.
This function checks that the resulting node labels are unique and throws an error if they are not.
"""
function factorization_constraint_to_nodelabels(
    context::Context,
    constraint_data::FactorizationConstraint,
)
    result = factorization_constraint_entries_to_nodelabel(
        context,
        getconstraint(constraint_data),
    )
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
    constraint_sets = BitSetTuple(label_indices)
    complete!(constraint_sets, num_neighbors)
    return get_membership_sets(constraint_sets, num_neighbors)
end

"""
    apply!(::Model, ::Constraints)

Applies the constraints in `Constraints` to the principal submodel of `Model`. This function figures out what the principal submodel is in a `Model` (assuming that the model was created by `GraphPPL.create_model` and a call to `GraphPPL.make_node!`) 
and then applies the constraints to that submodel. Works by calling `apply!` on all individual constraints to be applied.

"""
function apply!(model::Model, constraints::Constraints)
    apply!(model, GraphPPL.get_principal_submodel(model), constraints)
end

"""
    apply!(::Model, ::Context, ::Constraints)

Applies the constraints in `Constraints` to the submodel represented by `Context` in `Model`. This function is used when applying a set of constraints to a submodel. 
Works by calling `apply!` on all individual constraints to be applied.
"""
function apply!(model::Model, context::Context, constraints::Constraints)
    for constraint in getconstraints(constraints)
        apply!(model, context, constraint)
    end
end

"""
    apply!(::Model, ::Context, ::GeneralSubModelConstraints)

Applies the constraints in `GeneralSubModelConstraints` to all instances of `GeneralSubModelConstraints.fform` in `Model` in the context of `Context`.
"""
function apply!(model::Model, context::Context, constraint::GeneralSubModelConstraints)
    for (_, factor_context) in children(context)
        if isdefined(factor_context, :fform)
            if fform(factor_context) == fform(constraint)
                apply!(model, factor_context, constraint.constraints)
            end
        end
    end
end

"""
    apply!(::Model, ::Context, ::SpecificSubModelConstraints)

Applies the constraints in `SpecificSubModelConstraints` to the submodel with tag `SpecificSubModelConstraints.tag` in `Model` in the context of `Context`.
"""
function apply!(model::Model, context::Context, constraint::SpecificSubModelConstraints)
    for (tag, factor_context) in children(context)
        if tag == constraint.tag
            apply!(model, factor_context, constraint.constraints)
        end
    end
end

"""
    apply!(::Model, ::Context, ::MaterializedConstraints)

Applies a materialized constraint to the `Model` in the context of `Context`. This function figures out which nodes in the `Model` are applicable to the constraint and then calls `apply!` on those nodes.
"""
function apply!(model::Model, context::Context, constraint::MaterializedConstraints)
    nodes = applicable_nodes(model, context, constraint)
    apply!(model, context, constraint, nodes)
end

"""
    apply!(::Model, ::Context, ::FactorizationConstraint, ::AbstractArray{K} where {K<:NodeLabel})
Applies a `FactorizationConstraint` to specific nodes in the `Model`. This function prepares the constraint for application and then applies the constraint to the nodes in the input array.
"""
function apply!(
    model::Model,
    context::Context,
    constraint::FactorizationConstraint,
    nodes::AbstractArray{K} where {K<:NodeLabel},
)
    constraint = prepare_factorization_constraint(context, constraint)
    constraint_labels = factorization_constraint_to_nodelabels(context, constraint)
    for node in nodes
        constraint_bitsets = convert_to_bitsets(
            GraphPPL.neighbors(model, node; sorted = true),
            constraint_labels,
        )
        save_constraint!(model, node, constraint_bitsets, :q)
    end
end

"""
    apply!(::Model, ::Context, ::FunctionalFormConstraint, ::AbstractArray{K} where {K<:NodeLabel})

Applies a `FunctionalFormConstraint` to `nodes` in `Model` in the context of `Context`.
"""
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

"""
    apply!(::Model, ::Context, ::MessageConstraint, ::AbstractArray{K} where {K<:NodeLabel})

Applies a `MessageConstraint` to `nodes` in `Model` in the context of `Context`.
"""
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
    constraint_data::BitSetTuple,
    symbol::Symbol,
)
    node_data_options = node_options(node_data)
    intersect!(node_data_options[:q], constraint_data)
end

function save_constraint!(
    model::Model,
    node::NodeLabel,
    node_data::VariableNodeData,
    constraint_data,
    symbol::Symbol,
)
    opt = node_options(node_data)
    if haskey(opt, :q)
        @warn lazy"Node $node already has functional form constraint $(opt[:q]) applied, therefore $constraint_data will not be applied"
        return
    end
    node_data.options = NamedTuple{(keys(opt)..., symbol)}((opt..., constraint_data))
end

"""
    is_valid_partition(set::Set)

Returns `true` if `set` is a valid partition of the set `{1, 2, ..., maximum(Iterators.flatten(set))}`, false otherwise.
"""
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

materialize_constraints!(model::Model, node::NodeLabel) =
    materialize_constraints!(model, node, model[node])
materialize_constraints!(model::Model, node::NodeLabel, node_data::VariableNodeData) =
    nothing

"""
    materialize_constraints!(model::Model, node_label::NodeLabel, node_data::FactorNodeData)

Materializes the factorization constraint in `node_data` in `model` at `node_label`. This function converts the BitSet representation of a constraint in `node_data` to the tuple representation containing all interface names.
"""
materialize_constraints!(model::Model, node_label::NodeLabel, node_data::FactorNodeData) =
    materialize_constraints!(model, node_label, node_data, node_options(node_data)[:q])

function materialize_constraints!(
    model::Model,
    node_label::NodeLabel,
    node_data::FactorNodeData,
    constraint::BitSetTuple,
)
    constraint_set = Set(BitSetTuples.contents(constraint)) #TODO test `unique``
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
    noptions = delete(node_options(node_data), :q)
    node_data.options = NamedTuple{(keys(noptions)..., :q)}((noptions..., constraint))
end

materialize_constraints!(
    model::Model,
    node_label::NodeLabel,
    node_data::FactorNodeData,
    constraint,
) = nothing
