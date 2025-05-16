"""
    NodeCreationOptions(namedtuple)

Options for creating a node in a probabilistic graphical model. These are typically coming from the `where {}` block 
in the `@model` macro, but can also be created manually. Expects a `NamedTuple` as an input.

# Fields
- `options::N`: A NamedTuple or `nothing` containing node creation options like `kind`, `value`, etc.

# Examples
```julia
# Create options for a constant node
options = NodeCreationOptions(value = 5, kind = :constant)

# Create empty options
empty_options = NodeCreationOptions(nothing)
```
"""
struct NodeCreationOptions{N}
    options::N
end

const EmptyNodeCreationOptions = NodeCreationOptions{Nothing}(nothing)

"""
    NodeCreationOptions(; kwargs...)

Create a `NodeCreationOptions` instance from keyword arguments.

# Examples
```julia
options = NodeCreationOptions(kind = :random, value = 0.5)
```
"""
NodeCreationOptions(; kwargs...) = convert(NodeCreationOptions, kwargs)

Base.convert(::Type{NodeCreationOptions}, ::@Kwargs{}) = NodeCreationOptions(nothing)
Base.convert(::Type{NodeCreationOptions}, options) = NodeCreationOptions(NamedTuple(options))

Base.haskey(options::NodeCreationOptions, key::Symbol) = haskey(options.options, key)
Base.getindex(options::NodeCreationOptions, keys...) = getindex(options.options, keys...)
Base.getindex(options::NodeCreationOptions, keys::NTuple{N, Symbol}) where {N} = NodeCreationOptions(getindex(options.options, keys))
Base.keys(options::NodeCreationOptions) = keys(options.options)
Base.get(options::NodeCreationOptions, key::Symbol, default) = get(options.options, key, default)

# Fast fallback for empty options
Base.haskey(::NodeCreationOptions{Nothing}, key::Symbol) = false
Base.getindex(::NodeCreationOptions{Nothing}, keys...) = error("type `NodeCreationOptions{Nothing}` has no field $(keys)")
Base.keys(::NodeCreationOptions{Nothing}) = ()
Base.get(::NodeCreationOptions{Nothing}, key::Symbol, default) = default

"""
    withopts(options::NodeCreationOptions, extra::NamedTuple) -> NodeCreationOptions

Combine existing `NodeCreationOptions` with additional options in `extra`.
Returns a new `NodeCreationOptions` instance with merged options.

# Arguments
- `options::NodeCreationOptions`: Existing options
- `extra::NamedTuple`: Additional options to add

# Returns
A new `NodeCreationOptions` with combined options.

# Examples
```julia
original = NodeCreationOptions(kind = :random)
extended = withopts(original, (value = 0.5,))
```
"""
withopts(::NodeCreationOptions{Nothing}, options::NamedTuple) = NodeCreationOptions(options)
withopts(options::NodeCreationOptions, extra::NamedTuple) = NodeCreationOptions((; options.options..., extra...))

"""
    withoutopts(options::NodeCreationOptions, ::Val{K}) -> NodeCreationOptions

Create a new `NodeCreationOptions` with specified keys removed.

# Arguments
- `options::NodeCreationOptions`: Existing options
- `::Val{K}`: Keys to remove, as a value type of tuple of symbols

# Returns
A new `NodeCreationOptions` with specified keys removed.

# Examples
```julia
options = NodeCreationOptions(kind = :random, value = 0.5)
filtered = withoutopts(options, Val((:value,)))  # Removes the :value key
```
"""
withoutopts(::NodeCreationOptions{Nothing}, ::Val) = NodeCreationOptions(nothing)

function withoutopts(options::NodeCreationOptions, ::Val{K}) where {K}
    newoptions = options.options[filter(key -> key ∉ K, keys(options.options))]
    # Should be compiled out, there are tests for it
    if isempty(newoptions)
        return NodeCreationOptions(nothing)
    else
        return NodeCreationOptions(newoptions)
    end
end