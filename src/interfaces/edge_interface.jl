"""
    EdgeInterface

Abstract interface for edges in a factor graph. Represents the connection
between nodes and its properties.
"""
abstract type EdgeInterface end

"""
    get_name(edge::EdgeInterface)

Get the name of the edge.
"""
function get_name end

"""
    get_index(edge::EdgeInterface)

Get the index of the edge.
"""
function get_index end
