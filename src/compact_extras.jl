# A column store for opt-in compact graphs. Undefined entries mean "absent";
# storing `nothing` remains distinguishable from not having a key.
struct CompactExtraColumn{T} <: AbstractVector{T}
    values::Vector{T}
    present::BitVector
end
CompactExtraColumn(::Type{T}) where {T} = CompactExtraColumn(T[], BitVector())
Base.size(column::CompactExtraColumn) = size(column.values)
Base.IndexStyle(::Type{<:CompactExtraColumn}) = IndexLinear()
Base.isassigned(column::CompactExtraColumn, i::Int) = 1 <= i <= length(column) && column.present[i]
Base.getindex(column::CompactExtraColumn, i::Int) = isassigned(column, i) ? column.values[i] : throw(UndefRefError())
function Base.setindex!(column::CompactExtraColumn, value, i::Int)
    column.values[i] = value
    column.present[i] = true
    return value
end
function Base.resize!(column::CompactExtraColumn, n::Int)
    previous = length(column)
    resize!(column.values, n)
    resize!(column.present, n)
    n > previous && fill!(view(column.present, (previous + 1):n), false)
    return column
end

mutable struct CompactExtraColumns
    columns::Dict{Symbol, Any}
    interned::Dict{Any, Any}
end

CompactExtraColumns() = CompactExtraColumns(Dict{Symbol, Any}(), Dict{Any, Any}())

compact_metadata_value(key, columns, value) = value

struct CompactNodeExtras
    columns::CompactExtraColumns
    index::Int
end

function Base.haskey(extra::CompactNodeExtras, key::Symbol)::Bool
    column = get(extra.columns.columns, key, nothing)
    return column !== nothing && extra.index <= length(column) && isassigned(column, extra.index)
end

function Base.getindex(extra::CompactNodeExtras, key::Symbol)
    haskey(extra, key) || throw(KeyError(key))
    return extra.columns.columns[key][extra.index]
end

function Dictionaries.insert!(extra::CompactNodeExtras, key::Symbol, value)
    haskey(extra, key) && throw(ArgumentError("Index already exists: $key"))
    value = compact_metadata_value(Val(key), extra.columns, value)
    column = get!(extra.columns.columns, key) do
        # Numerical IDs and flags need no per-entry boxing. Arbitrary extension
        # metadata keeps a general representation with the same presence rules.
        CompactExtraColumn(isbitstype(typeof(value)) ? typeof(value) : Any)
    end
    if !(value isa eltype(column))
        widened = resize!(CompactExtraColumn(Any), length(column))
        for i in eachindex(column)
            isassigned(column, i) && (widened[i] = column[i])
        end
        extra.columns.columns[key] = column = widened
    end
    if length(column) < extra.index
        resize!(column, extra.index)
    end
    column[extra.index] = value
    return extra
end

Base.get(extra::CompactNodeExtras, key::Symbol, default) = haskey(extra, key) ? extra[key] : default
Base.keys(extra::CompactNodeExtras) = Iterators.filter(key -> haskey(extra, key), keys(extra.columns.columns))
Base.values(extra::CompactNodeExtras) = (extra[key] for key in keys(extra))
Base.pairs(extra::CompactNodeExtras) = (key => extra[key] for key in keys(extra))
Base.isempty(extra::CompactNodeExtras) = isempty(keys(extra))
Base.length(extra::CompactNodeExtras) = Base.count(_ -> true, keys(extra))
Base.iterate(extra::CompactNodeExtras, state...) = iterate(values(extra), state...)

function Base.show(io::IO, extra::CompactNodeExtras)
    print(io, "CompactNodeExtras(")
    join(io, pairs(extra), ", ")
    print(io, ')')
end
