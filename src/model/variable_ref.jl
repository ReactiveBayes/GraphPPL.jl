"""
    VariableRef(model::AbstractModel, context::Context, name::Symbol, index, external_collection = nothing)

`VariableRef` implements a lazy reference to a variable in the model. 
The reference does not create an actual variable in the model immediatelly, but postpones the creation 
until strictly necessarily, which is hapenning inside the `unroll` function. The postponed creation allows users to define 
pass a single variable into a submodel, e.g. `y ~ submodel(x = x)`, but use it as an array inside the submodel, 
e.g. `y[i] ~ Normal(x[i], 1.0)`. 

Optionally accepts an `external_collection`, which defines the upper limit on the shape of the underlying collection.
For example, an external collection `[ 1, 2, 3 ]` can be used both as `y ~ ...` and `y[i] ~ ...`, but not as `y[i, j] ~ ...`.
By default, the `MissingCollection` is used for the `external_collection`, which does not restrict the shape of the underlying collection.

The `index` is always a `Tuple`. By default, `(nothing, )` is used, to indicate empty indices with no restrictions on the shape of the underlying collection. 
If "non-nothing" index is supplied, e.g. `(1, )` the shape of the udnerlying collection will be fixed to match the index 
(1-dimensional in case of `(1, )`, 2-dimensional in case of `(1, 1)` and so on).
"""
struct VariableRef{M, C, O, I, E, L} <: AbstractVariableReference
    model::M
    context::C
    options::O
    name::Symbol
    index::I
    external_collection::E
    internal_collection::L
end

Base.:(==)(left::VariableRef, right::VariableRef) =
    left.model == right.model && left.context == right.context && left.name == right.name && left.index == right.index

function Base.:(==)(left::VariableRef, right)
    error(
        "Comparing Factor Graph variable `$left` with a value. This is not possible as the value of `$left` is not known at model construction time."
    )
end
Base.:(==)(left, right::VariableRef) = right == left

Base.:(>)(left::VariableRef, right) = left == right
Base.:(>)(left, right::VariableRef) = left == right
Base.:(<)(left::VariableRef, right) = left == right
Base.:(<)(left, right::VariableRef) = left == right
Base.:(>=)(left::VariableRef, right) = left == right
Base.:(>=)(left, right::VariableRef) = left == right
Base.:(<=)(left::VariableRef, right) = left == right
Base.:(<=)(left, right::VariableRef) = left == right

is_proxied(::Type{T}) where {T <: VariableRef} = True()

external_collection_typeof(::Type{VariableRef{M, C, O, I, E, L}}) where {M, C, O, I, E, L} = E
internal_collection_typeof(::Type{VariableRef{M, C, O, I, E, L}}) where {M, C, O, I, E, L} = L

external_collection(ref::VariableRef) = ref.external_collection
internal_collection(ref::VariableRef) = ref.internal_collection

Base.show(io::IO, ref::VariableRef) = variable_ref_show(io, ref.name, ref.index)
variable_ref_show(io::IO, name::Symbol, index::Nothing) = print(io, name)
variable_ref_show(io::IO, name::Symbol, index::Tuple{Nothing}) = print(io, name)
variable_ref_show(io::IO, name::Symbol, index::Tuple) = print(io, name, "[", join(index, ","), "]")
variable_ref_show(io::IO, name::Symbol, index::Any) = print(io, name, "[", index, "]")

"""
    makevarref(fform::F, model::AbstractModel, context::Context, options::NodeCreationOptions, name::Symbol, index::Tuple)

A function that creates `VariableRef`, but takes the `fform` into account. When `fform` happens to be `Atomic` creates 
the underlying variable immediatelly without postponing. When `fform` is `Composite` does not create the actual variable, 
but waits until strictly necessarily.
"""
function makevarref end

function makevarref(fform::F, model::AbstractModel, context::Context, options::NodeCreationOptions, name::Symbol, index::Tuple) where {F}
    return makevarref(NodeType(model, fform), model, context, options, name, index)
end

function makevarref(::Atomic, model::AbstractModel, context::Context, options::NodeCreationOptions, name::Symbol, index::Tuple)
    # In the case of `Atomic` variable reference, we always create the variable 
    # (unless the index is empty, which may happen during broadcasting)
    internal_collection = isempty(index) ? nothing : getorcreate!(model, context, name, index...)
    return VariableRef(model, context, options, name, index, nothing, internal_collection)
end

function makevarref(::Composite, model::AbstractModel, context::Context, options::NodeCreationOptions, name::Symbol, index::Tuple)
    # In the case of `Composite` variable reference, we create it immediatelly only when the variable is instantiated 
    # with indexing operation
    internal_collection = if !all(isnothing, index)
        getorcreate!(model, context, name, index...)
    else
        nothing
    end
    return VariableRef(model, context, options, name, index, nothing, internal_collection)
end

function VariableRef(
    model::AbstractModel,
    context::Context,
    options::NodeCreationOptions,
    name::Symbol,
    index::Tuple,
    external_collection = nothing,
    internal_collection = nothing
)
    M = typeof(model)
    C = typeof(context)
    O = typeof(options)
    I = typeof(index)
    E = typeof(external_collection)
    L = typeof(internal_collection)
    return VariableRef{M, C, O, I, E, L}(model, context, options, name, index, external_collection, internal_collection)
end

function unroll(p::ProxyLabel, ref::VariableRef, index, maycreate, liftedindex)
    liftedindex = lift_index(maycreate, index, liftedindex)
    if maycreate === False()
        return checked_getindex(getifcreated(ref.model, ref.context, ref, liftedindex), index)
    elseif maycreate === True()
        return checked_getindex(getorcreate!(ref.model, ref.context, ref, liftedindex), index)
    end
    error("Unreachable. The `maycreate` argument in the `unroll` function for the `VariableRef` must be either `True` or `False`.")
end

function getifcreated(model::AbstractModel, context::Context, ref::VariableRef)
    return getifcreated(model, context, ref, ref.index)
end

function getifcreated(model::AbstractModel, context::Context, ref::VariableRef, index)
    if !isnothing(ref.external_collection)
        return getorcreate!(ref.model, ref.context, ref, index)
    elseif !isnothing(ref.internal_collection)
        return ref.internal_collection
    elseif haskey(ref.context, ref.name)
        return ref.context[ref.name]
    else
        error(lazy"The variable `$ref` has been used, but has not been instantiated.")
    end
end

function getorcreate!(model::AbstractModel, context::Context, ref::VariableRef, index::Nothing)
    check_external_collection_compatibility(ref, index)
    return getorcreate!(model, context, ref.options, ref.name, index)
end

function getorcreate!(model::AbstractModel, context::Context, ref::VariableRef, index::Tuple)
    check_external_collection_compatibility(ref, index)
    return getorcreate!(model, context, ref.options, ref.name, index...)
end

Base.IteratorSize(ref::VariableRef) = Base.IteratorSize(typeof(ref))
Base.IteratorEltype(ref::VariableRef) = Base.IteratorEltype(typeof(ref))
Base.eltype(ref::VariableRef) = Base.eltype(typeof(ref))

Base.IteratorSize(::Type{R}) where {R <: VariableRef} =
    variable_ref_iterator_size(external_collection_typeof(R), internal_collection_typeof(R))
variable_ref_iterator_size(::Type{Nothing}, ::Type{Nothing}) = Base.SizeUnknown()
variable_ref_iterator_size(::Type{E}, ::Type{L}) where {E, L} = Base.IteratorSize(E)
variable_ref_iterator_size(::Type{Nothing}, ::Type{L}) where {L} = Base.IteratorSize(L)

Base.IteratorEltype(::Type{R}) where {R <: VariableRef} =
    variable_ref_iterator_eltype(external_collection_typeof(R), internal_collection_typeof(R))
variable_ref_iterator_eltype(::Type{Nothing}, ::Type{Nothing}) = Base.EltypeUnknown()
variable_ref_iterator_eltype(::Type{E}, ::Type{L}) where {E, L} = Base.IteratorEltype(E)
variable_ref_iterator_eltype(::Type{Nothing}, ::Type{L}) where {L} = Base.IteratorEltype(L)

Base.eltype(::Type{R}) where {R <: VariableRef} = variable_ref_eltype(external_collection_typeof(R), internal_collection_typeof(R))
variable_ref_eltype(::Type{Nothing}, ::Type{Nothing}) = Any
variable_ref_eltype(::Type{E}, ::Type{L}) where {E, L} = Base.eltype(E)
variable_ref_eltype(::Type{Nothing}, ::Type{L}) where {L} = Base.eltype(L)

function variableref_checked_collection_typeof(::VariableRef)
    return variableref_checked_iterator_call(typeof, :typeof, ref)
end

Base.length(ref::VariableRef) = variableref_checked_iterator_call(Base.length, :length, ref)
Base.firstindex(ref::VariableRef) = variableref_checked_iterator_call(Base.firstindex, :firstindex, ref)
Base.lastindex(ref::VariableRef) = variableref_checked_iterator_call(Base.lastindex, :lastindex, ref)
Base.eachindex(ref::VariableRef) = variableref_checked_iterator_call(Base.eachindex, :eachindex, ref)
Base.axes(ref::VariableRef) = variableref_checked_iterator_call(Base.axes, :axes, ref)

Base.size(ref::VariableRef, dims...) = variableref_checked_iterator_call((c) -> Base.size(c, dims...), :size, ref)
Base.getindex(ref::VariableRef, indices...) = variableref_checked_iterator_call((c) -> Base.getindex(c, indices...), :getindex, ref)

function variableref_checked_iterator_call(f::F, fsymbol::Symbol, ref::VariableRef) where {F}
    if !isnothing(ref.external_collection)
        return f(ref.external_collection)
    elseif !isnothing(ref.internal_collection)
        return f(ref.internal_collection)
    elseif haskey(ref.context, ref.name)
        return f(ref.context[ref.name])
    end
    error(lazy"Cannot call `$(fsymbol)` on variable reference `$(ref.name)`. The variable `$(ref.name)` has not been instantiated.")
end

function postprocess_returnval(ref::VariableRef)
    if haskey(ref.context, ref.name)
        return ref.context[ref.name]
    end
    error("Cannot `return $(ref)`. The variable has not been instantiated.")
end

"""
A placeholder collection for `VariableRef` when the actual external collection is not yet available.
"""
struct MissingCollection end

__err_missing_collection_missing_method(method::Symbol) =
    error("The `$method` method is not defined for a lazy node label without data attached.")

Base.IteratorSize(::Type{MissingCollection}) = __err_missing_collection_missing_method(:IteratorSize)
Base.IteratorEltype(::Type{MissingCollection}) = __err_missing_collection_missing_method(:IteratorEltype)
Base.eltype(::Type{MissingCollection}) = __err_missing_collection_missing_method(:eltype)
Base.length(::MissingCollection) = __err_missing_collection_missing_method(:length)
Base.size(::MissingCollection, dims...) = __err_missing_collection_missing_method(:size)
Base.firstindex(::MissingCollection) = __err_missing_collection_missing_method(:firstindex)
Base.lastindex(::MissingCollection) = __err_missing_collection_missing_method(:lastindex)
Base.eachindex(::MissingCollection) = __err_missing_collection_missing_method(:eachindex)
Base.axes(::MissingCollection) = __err_missing_collection_missing_method(:axes)

function check_external_collection_compatibility(ref::VariableRef, index)
    if !isnothing(external_collection(ref)) && !__check_external_collection_compatibility(ref, index)
        error(
            """
            The index `[$(!isnothing(index) ? join(index, ", ") : nothing)]` is not compatible with the underlying collection provided for the label `$(ref.name)`.
            The underlying data provided for `$(ref.name)` is `$(external_collection(ref))`.
            """
        )
    end
    return nothing
end

function __check_external_collection_compatibility(ref::VariableRef, index::Nothing)
    # We assume that index `nothing` is always compatible with the underlying collection
    # Eg. a matrix `Σ` can be used both as it is `Σ`, but also as `Σ[1]` or `Σ[1, 1]`
    return true
end

function __check_external_collection_compatibility(ref::VariableRef, index::Tuple)
    return __check_external_collection_compatibility(ref, external_collection(ref), index)
end

# We can't really check if the data compatible or not if we get the `MissingCollection`
__check_external_collection_compatibility(label::VariableRef, ::MissingCollection, index::Tuple) = true
__check_external_collection_compatibility(label::VariableRef, collection::AbstractArray, indices::Tuple) =
    checkbounds(Bool, collection, indices...)
__check_external_collection_compatibility(label::VariableRef, collection::Tuple, indices::Tuple) =
    length(indices) === 1 && first(indices) ∈ 1:length(collection)
# A number cannot really be queried with non-empty indices
__check_external_collection_compatibility(label::VariableRef, collection::Number, indices::Tuple) = false
# For all other we simply don't know so we assume we are compatible
__check_external_collection_compatibility(label::VariableRef, collection, indices::Tuple) = true

function Base.iterate(ref::VariableRef, state)
    if !isnothing(external_collection(ref))
        return iterate(external_collection(ref), state)
    elseif !isnothing(internal_collection(ref))
        return iterate(internal_collection(ref), state)
    elseif haskey(ref.context, ref.name)
        return iterate(ref.context[ref.name], state)
    end
    error("Cannot iterate over $(ref.name). The underlying collection for `$(ref.name)` has undefined shape.")
end

function Base.iterate(ref::VariableRef)
    if !isnothing(external_collection(ref))
        return iterate(external_collection(ref))
    elseif !isnothing(internal_collection(ref))
        return iterate(internal_collection(ref))
    elseif haskey(ref.context, ref.name)
        return iterate(ref.context[ref.name])
    end
    error("Cannot iterate over $(ref.name). The underlying collection for `$(ref.name)` has undefined shape.")
end

function Base.broadcastable(ref::VariableRef)
    if !isnothing(external_collection(ref))
        # If we have an underlying collection (e.g. data), we should instantiate all variables at the point of broadcasting 
        # in order to support something like `y .~ ` where `y` is a data label
        return collect(
            Iterators.map(
                I -> checked_getindex(getorcreate!(ref.model, ref.context, ref.options, ref.name, I.I...), I.I), CartesianIndices(axes(ref))
            )
        )
    elseif !isnothing(internal_collection(ref))
        return Base.broadcastable(internal_collection(ref))
    elseif haskey(ref.context, ref.name)
        return Base.broadcastable(ref.context[ref.name])
    end
    error("Cannot broadcast over $(ref.name). The underlying collection for `$(ref.name)` has undefined shape.")
end

"""
    datalabel(model, context, options, name, collection = MissingCollection())

A function for creating proxy data labels to pass into the model upon creation. 
Can be useful in combination with `AbstractModelGenerator` and `create_model`.
"""
function datalabel(model, context, options, name, collection = MissingCollection())
    kind = get(options, :kind, VariableKindUnknown)
    if !isequal(kind, VariableKindData)
        error("`datalabel` only supports `VariableKindData` in `NodeCreationOptions`")
    end
    return proxylabel(name, VariableRef(model, context, options, name, (nothing,), collection), nothing, True())
end