using Dictionaries

struct SmallDict{K, V}
    iter::Vector{Tuple{K, V}}
end

function SmallDict{K, V}() where {K, V}
    return SmallDict{K, V}(Vector{Tuple{K, V}}())
end

function Dictionaries.set!(dict::SmallDict{K, V}, key::K, value::V) where {K, V}
    @inbounds for i in eachindex(dict.iter)
        if isequal(dict.iter[i][1], key)
            dict.iter[i] = (key, value)
            return nothing
        end
    end
    push!(dict.iter, (key, value))
    return nothing
end

function Base.get(callable::C, dict::SmallDict{K, V}, key::K) where {C, K, V}
    @inbounds for i in eachindex(dict.iter)
        if isequal(dict.iter[i][1], key)
            return dict.iter[i][2]
        end
    end
    return callable()
end

function Base.setindex!(dict::SmallDict{K, V}, value::V, key::K) where {K, V}
    set!(dict, key, value)
end

function Base.getindex(dict::SmallDict{K, V}, key::K) where {K, V}
    @inbounds for i in eachindex(dict.iter)
        if isequal(dict.iter[i][1], key)
            return dict.iter[i][2]
        end
    end
    throw(KeyError(key))
end

function Base.haskey(dict::SmallDict{K, V}, key::K) where {K, V}
    @inbounds for i in eachindex(dict.iter)
        if isequal(dict.iter[i][1], key)
            return true
        end
    end
    return false
end