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

function Base.pairs(dict::SmallDict{K, V}) where {K, V}
    return dict.iter
end

function Base.merge(dict1::SmallDict{K, V1}, dict2::SmallDict{K, V2}) where {K, V1, V2}
    dict = SmallDict{K, Union{V1, V2}}()
    for (k, v) in pairs(dict1)
        set!(dict, k, v)
    end
    for (k, v) in pairs(dict2)
        set!(dict, k, v)
    end
    return dict
end

function Base.merge(dict1::SmallDict{K, V1}, dict2::SmallDict{K, V2}, dict3::SmallDict{K, V3}) where {K, V1, V2, V3}
    dict = SmallDict{K, Union{V1, V2, V3}}()
    for (k, v) in pairs(dict1)
        set!(dict, k, v)
    end
    for (k, v) in pairs(dict2)
        set!(dict, k, v)
    end
    for (k, v) in pairs(dict3)
        set!(dict, k, v)
    end
    return dict
end

function Base.map(f, dict::SmallDict{K, V}) where {K, V}
    T = Base.infer_return_type(f, (V,))
    mapped_dict = SmallDict{K, T}()
    for (k, v) in pairs(dict)
        push!(mapped_dict.iter, (k, f(v)))
    end
    return mapped_dict
end

function Base.filter(f, dict::SmallDict{K, V}) where {K, V}
    filtered_dict = SmallDict{K, V}()
    for (k, v) in pairs(dict)
        if f(v)
            push!(filtered_dict.iter, (k, v))
        end
    end
    return filtered_dict
end