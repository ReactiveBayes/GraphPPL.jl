
"""
A compile time key to access the `extra` properties of the `NodeData` structure.
"""
struct CompileTimeDictionaryKey{K, T} end

get_key(::CompileTimeDictionaryKey{K, T}) where {K, T} = K