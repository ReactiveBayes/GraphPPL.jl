"""
    Splat{T}

A type used to represent splatting in the model macro. Any call on the right hand side of ~ that uses splatting will be wrapped in this type.
"""
struct Splat{T}
    collection::T
end

"""
    ProxyLabel(name, index, proxied)

A label that proxies another label in a probabilistic graphical model. 
The proxied objects must implement the `is_proxied(::Type) = True()`.
The proxy labels may spawn new variables in a model, if `maycreate` is set to `True()`.
"""
mutable struct ProxyLabel{P, I, M} <: ProxyLabelInterface
    const name::Symbol
    const proxied::P
    const index::I
    const maycreate::M
end

is_proxied(any) = is_proxied(typeof(any))
is_proxied(::Type) = False()
is_proxied(::Type{T}) where {T <: NodeLabelInterface} = True()
is_proxied(::Type{T}) where {T <: ProxyLabel} = True()
is_proxied(::Type{T}) where {T <: AbstractArray} = is_proxied(eltype(T))

proxylabel(name::Symbol, proxied::Splat{T}, index, maycreate) where {T} =
    [proxylabel(name, proxiedelement, index, maycreate) for proxiedelement in proxied.collection]

# By default, `proxylabel` set `maycreate` to `False`
proxylabel(name::Symbol, proxied, index) = proxylabel(name, proxied, index, False())
proxylabel(name::Symbol, proxied, index, maycreate) = proxylabel(is_proxied(proxied), name, proxied, index, maycreate)

# In case if `is_proxied` returns `False` we simply return the original object, because the object cannot be proxied
proxylabel(::False, name::Symbol, proxied::Any, index::Nothing, maycreate) = proxied
proxylabel(::False, name::Symbol, proxied::Any, index::Tuple, maycreate) = proxied[index...]

# In case if `is_proxied` returns `True`, we wrap the object into the `ProxyLabel` for later `unroll`-ing
function proxylabel(::True, name::Symbol, proxied::Any, index::Any, maycreate::Any)
    return ProxyLabel(name, proxied, index, maycreate)
end

# In case if `proxied` is another `ProxyLabel` we take `|` operation with its `maycreate` to lift it further
# This is a useful operation for `datalabels`, since they define `maycreate = True()` on their creation time
# That means that all subsequent usages of data labels will always create a new label, even when used on right hand side from `~`
function proxylabel(::True, name::Symbol, proxied::ProxyLabel, index::Any, maycreate::Any)
    return ProxyLabel(name, proxied, index, proxied.maycreate | maycreate)
end

getname(label::ProxyLabel) = label.name
index(label::ProxyLabel) = label.index

# This function allows to overwrite the `maycreate` flag on a proxy label, might be useful for situations where code should
# definitely not create a new variable, e.g in the variational constraints plugin
set_maycreate(proxylabel::ProxyLabel, maycreate::Union{True, False}) =
    ProxyLabel(proxylabel.name, proxylabel.proxied, proxylabel.index, maycreate)
set_maycreate(something, maycreate::Union{True, False}) = something

function unroll(something)
    return something
end

function unroll(proxylabel::ProxyLabel)
    return unroll(proxylabel, proxylabel.proxied, proxylabel.index, proxylabel.maycreate, proxylabel.index)
end

function unroll(proxylabel::ProxyLabel, proxied::ProxyLabel, index, maycreate, liftedindex)
    # In case of a chain of proxy-labels we should lift the index, that potentially might 
    # be used to create a new collection of variables
    liftedindex = lift_index(maycreate, index, liftedindex)
    unrolled = unroll(proxied, proxied.proxied, proxied.index, proxied.maycreate, liftedindex)
    return checked_getindex(unrolled, index)
end

function unroll(proxylabel::ProxyLabel, something::Any, index, maycreate, liftedindex)
    return checked_getindex(something, index)
end

checked_getindex(something, index::FunctionalIndex) = Base.getindex(something, index)
checked_getindex(something, index::Tuple) = Base.getindex(something, index...)
checked_getindex(something, index::Nothing) = something

checked_getindex(nodelabel::NodeLabelInterface, index::Nothing) = nodelabel
checked_getindex(nodelabel::NodeLabelInterface, index::Tuple) =
    error("Indexing a single node label `$(getname(nodelabel))` with an index `[$(join(index, ", "))]` is not allowed.")
checked_getindex(nodelabel::NodeLabelInterface, index) =
    error("Indexing a single node label `$(getname(nodelabel))` with an index `$index` is not allowed.")

"""
The `lift_index` function "lifts" (or tracks) the index that is going to be used to determine the shape of the container upon creation
for a variable during the unrolling of the `ProxyLabel`. This index is used only if the container is set to be created and is not used if 
variable container already exists.
"""
function lift_index end

lift_index(::True, ::Nothing, ::Nothing) = nothing
lift_index(::True, current, ::Nothing) = current
lift_index(::True, ::Nothing, previous) = previous
lift_index(::True, current, previous) = current
lift_index(::False, current, previous) = previous

Base.show(io::IO, proxy::ProxyLabel) = show_proxy(io, getname(proxy), index(proxy))
show_proxy(io::IO, name::Symbol, index::Nothing) = print(io, name)
show_proxy(io::IO, name::Symbol, index::Tuple) = print(io, name, "[", join(index, ","), "]")
show_proxy(io::IO, name::Symbol, index::Any) = print(io, name, "[", index, "]")

Base.last(label::ProxyLabel) = last(label.proxied, label)
Base.last(proxied::ProxyLabel, ::ProxyLabel) = last(proxied)
Base.last(proxied, ::ProxyLabel) = proxied

Base.:(==)(proxy1::ProxyLabel, proxy2::ProxyLabel) =
    proxy1.name == proxy2.name && proxy1.index == proxy2.index && proxy1.proxied == proxy2.proxied
Base.hash(proxy::ProxyLabel, h::UInt) = hash(proxy.maycreate, hash(proxy.name, hash(proxy.index, hash(proxy.proxied, h))))

# Iterator's interface methods
Base.IteratorSize(proxy::ProxyLabel) = Base.IteratorSize(indexed_last(proxy))
Base.IteratorEltype(proxy::ProxyLabel) = Base.IteratorEltype(indexed_last(proxy))
Base.eltype(proxy::ProxyLabel) = Base.eltype(indexed_last(proxy))

Base.length(proxy::ProxyLabel) = length(indexed_last(proxy))
Base.size(proxy::ProxyLabel, dims...) = size(indexed_last(proxy), dims...)
Base.firstindex(proxy::ProxyLabel) = firstindex(indexed_last(proxy))
Base.lastindex(proxy::ProxyLabel) = lastindex(indexed_last(proxy))
Base.eachindex(proxy::ProxyLabel) = eachindex(indexed_last(proxy))
Base.axes(proxy::ProxyLabel) = axes(indexed_last(proxy))
Base.getindex(proxy::ProxyLabel, indices...) = getindex(indexed_last(proxy), indices...)
Base.size(proxy::ProxyLabel) = size(indexed_last(proxy))
Base.broadcastable(proxy::ProxyLabel) = Base.broadcastable(indexed_last(proxy))

postprocess_returnval(proxy::ProxyLabel) = postprocess_returnval(indexed_last(proxy))

"""Similar to `Base.last` when applied on `ProxyLabel`, but also applies `checked_getindex` while unrolling"""
function indexed_last end

indexed_last(proxy::ProxyLabel) = checked_getindex(indexed_last(proxy.proxied), proxy.index)
indexed_last(something)         = something