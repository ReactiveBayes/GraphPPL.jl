"""
    FactorNodeCreationOptions(namedtuple)

Options for creating a node in a probabilistic graphical model. These are typically coming from the `where {}` block 
in the `@model` macro, but can also be created manually. Expects a `NamedTuple` as an input.

# Fields
- `options::N`: A NamedTuple or `nothing` containing node creation options like `kind`, `value`, etc.

# Examples
```julia
# Create options for a constant node
options = FactorNodeCreationOptions(value = 5, kind = :constant)

# Create empty options
empty_options = FactorNodeCreationOptions(nothing)
```
"""
struct FactorNodeCreationOptions{N}
    options::N
end

const EmptyFactorNodeCreationOptions = FactorNodeCreationOptions{Nothing}(nothing)

"""
    FactorNodeCreationOptions(; kwargs...)

Create a `FactorNodeCreationOptions` instance from keyword arguments.

# Examples
```julia
options = FactorNodeCreationOptions(kind = :random, value = 0.5)
```
"""
FactorNodeCreationOptions(; kwargs...) = convert(FactorNodeCreationOptions, kwargs)

Base.convert(::Type{FactorNodeCreationOptions}, ::@Kwargs{}) = FactorNodeCreationOptions(nothing)
Base.convert(::Type{FactorNodeCreationOptions}, options) = FactorNodeCreationOptions(NamedTuple(options))

Base.haskey(options::FactorNodeCreationOptions, key::Symbol) = haskey(options.options, key)
Base.getindex(options::FactorNodeCreationOptions, keys...) = getindex(options.options, keys...)
Base.getindex(options::FactorNodeCreationOptions, keys::NTuple{N, Symbol}) where {N} =
    FactorNodeCreationOptions(getindex(options.options, keys))
Base.keys(options::FactorNodeCreationOptions) = keys(options.options)
Base.get(options::FactorNodeCreationOptions, key::Symbol, default) = get(options.options, key, default)

# Fast fallback for empty options
Base.haskey(::FactorNodeCreationOptions{Nothing}, key::Symbol) = false
Base.getindex(::FactorNodeCreationOptions{Nothing}, keys...) = error("type `FactorNodeCreationOptions{Nothing}` has no field $(keys)")
Base.keys(::FactorNodeCreationOptions{Nothing}) = ()
Base.get(::FactorNodeCreationOptions{Nothing}, key::Symbol, default) = default

"""
    withopts(options::FactorNodeCreationOptions, extra::NamedTuple) -> FactorNodeCreationOptions

Combine existing `FactorNodeCreationOptions` with additional options in `extra`.
Returns a new `FactorNodeCreationOptions` instance with merged options.

# Arguments
- `options::FactorNodeCreationOptions`: Existing options
- `extra::NamedTuple`: Additional options to add

# Returns
A new `FactorNodeCreationOptions` with combined options.

# Examples
```julia
original = FactorNodeCreationOptions(kind = :random)
extended = withopts(original, (value = 0.5,))
```
"""
withopts(::FactorNodeCreationOptions{Nothing}, options::NamedTuple) = FactorNodeCreationOptions(options)
withopts(options::FactorNodeCreationOptions, extra::NamedTuple) = FactorNodeCreationOptions((; options.options..., extra...))

"""
    withoutopts(options::FactorNodeCreationOptions, ::Val{K}) -> FactorNodeCreationOptions

Create a new `FactorNodeCreationOptions` with specified keys removed.

# Arguments
- `options::FactorNodeCreationOptions`: Existing options
- `::Val{K}`: Keys to remove, as a value type of tuple of symbols

# Returns
A new `FactorNodeCreationOptions` with specified keys removed.

# Examples
```julia
options = FactorNodeCreationOptions(kind = :random, value = 0.5)
filtered = withoutopts(options, Val((:value,)))  # Removes the :value key
```
"""
withoutopts(::FactorNodeCreationOptions{Nothing}, ::Val) = FactorNodeCreationOptions(nothing)

function withoutopts(options::FactorNodeCreationOptions, ::Val{K}) where {K}
    newoptions = options.options[filter(key -> key ∉ K, keys(options.options))]
    # Should be compiled out, there are tests for it
    if isempty(newoptions)
        return FactorNodeCreationOptions(nothing)
    else
        return FactorNodeCreationOptions(newoptions)
    end
end