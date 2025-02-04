module GraphPPLGraphVizExt
using GraphPPL, MetaGraphsNext, GraphViz
using GraphPPL.MetaGraphsNext
import MetaGraphsNext: nv

import GraphViz: load

"""
Abstract type defining node traversal strategies for graph visualization.

Concrete subtypes:
- `SimpleIteration`: Basic iteration through vertices
- `BFSTraversal`: Breadth-first search traversal from initial node

The choice of strategy affects both performance and visual layout.
"""
abstract type TraversalStrategy end

struct SimpleIteration <: TraversalStrategy end
struct BFSTraversal <: TraversalStrategy end

"""
    get_node_properties(model::GraphPPL.Model, vertex::Int64)

Extracts the properties of a specific node in a `GraphPPL.Model` and returns these as a dictionary.

# Arguments
- `model::GraphPPL.Model`: The model from which the node's properties will be retrieved.
- `vertex::Int64`: The integer index representing the node in the model's graph.

# Returns
- A `Dict{Symbol, Any}` where each key is a symbol corresponding to the node's property names 
(including the `label`), and the value is the corresponding property value.
"""
function get_node_properties(model::GraphPPL.Model, vertex::Int64)
    # Set up return value
    namespace_variables = Dict{Symbol, Any}()

    # Get the properties of the node   
    label = MetaGraphsNext.label_for(model.graph, vertex)
    properties = model[label].properties

    # Add label to the dictionary
    namespace_variables[:label] = label

    # Get field names
    field_names = fieldnames(typeof(properties))

    # Add field names and values to the dictionary
    for field_name in field_names

        # It might be wise to add GraphPPL.NodeData to this also. 
        namespace_variables[field_name] = getproperty(properties, field_name)
    end

    return namespace_variables
end

"""
    get_node_properties(properties::GraphPPL.FactorNodeProperties)

Extracts the properties of a factor node from a `GraphPPL.FactorNodeProperties` struct 
and returns them as a dictionary.

# Arguments
- `properties::GraphPPL.FactorNodeProperties`: A struct containing the factor node properties 
of a factor node in a probabilistic graphical model.

# Returns
- A `Dict{Symbol, Any}` where each key is the name of a field in the `properties` 
object (as a symbol), and the corresponding value is the value of that field.
"""
function get_node_properties(properties::GraphPPL.FactorNodeProperties)
    # Set up return value
    namespace_variables = Dict{Symbol, Any}()

    # Get field names
    field_names = fieldnames(typeof(properties))

    # Add field names and values to the dictionary
    for field_name in field_names
        namespace_variables[field_name] = getproperty(properties, field_name)
    end

    return namespace_variables
end

"""
    get_node_properties(properties::GraphPPL.VariableNodeProperties)

Extracts the properties of a variable node from a `GraphPPL.VariableNodeProperties` struct 
and returns these as a dictionary.

# Arguments
- `properties::GraphPPL.VariableNodeProperties`: A struct containing the variable node properties.

# Returns
- A `Dict{Symbol, Any}` where each key is the name of a field in the `properties` 
object (as a symbol), and the corresponding value is the value of that field.
"""
function get_node_properties(properties::GraphPPL.VariableNodeProperties)
    # Set up return value
    namespace_variables = Dict{Symbol, Any}()

    # Get field names
    field_names = fieldnames(typeof(properties))

    # Add field names and values to the dictionary
    for field_name in field_names
        namespace_variables[field_name] = getproperty(properties, field_name)
    end

    return namespace_variables
end

"""
    get_namespace_variables_dict(model::GraphPPL.Model)

Maps each node's global counter ID to its properties.

# Arguments
- `model::GraphPPL.Model`: The model to extract node properties from

# Returns
- `Dict{Int64, Dict{Symbol, Any}}`: Maps node IDs to property dictionaries
"""
function get_namespace_variables_dict(model::GraphPPL.Model)
    node_properties_dict = Dict{Int64, Dict{Symbol, Any}}()

    for vertex in MetaGraphsNext.vertices(model.graph)
        node_properties = get_node_properties(model, vertex)

        global_counter_id = node_properties[:label].global_counter

        node_properties_dict[global_counter_id] = node_properties
    end

    return node_properties_dict
end

"""
    get_sanitized_variable_node_name(var_namespace_dict::Dict{Symbol, Any})

Creates a sanitized string representation of a variable node in the format "label:value".

# Arguments
- `var_namespace_dict::Dict{Symbol, Any}`: Dictionary containing the variable node's properties

# Returns
- `String`: Node representation in format "label:value", where value is "nothing" if null
"""
function get_sanitized_variable_node_name(var_namespace_dict::Dict{Symbol, Any})
    san_str_name_var = string(var_namespace_dict[:label]) # was :name

    if isnothing(var_namespace_dict[:value])
        str_val_var = "nothing"
    else
        str_val_var = string(var_namespace_dict[:value])
    end

    final_str = string(san_str_name_var, ":", str_val_var)

    return final_str
end

"""
    get_sanitized_factor_node_name(fac_namespace_dict::Dict{Symbol, Any})

Converts a factor node's label to a sanitized string name.

# Arguments
- `fac_namespace_dict::Dict{Symbol, Any}`: Dictionary containing the factor node's properties

# Returns
- `String`: Sanitized string name derived from the node's label
"""
function get_sanitized_factor_node_name(fac_namespace_dict::Dict{Symbol, Any})
    san_str_name_fac = string(fac_namespace_dict[:label]) # was :fform
    san_str_name_fac = replace(san_str_name_fac, "\"" => "", "#" => "")
    return san_str_name_fac
end

"""
    get_sanitized_node_name(single_node_namespace_dict::Dict{Symbol, Any})

Returns a sanitized name string for either a variable or factor node.

# Arguments
- `single_node_namespace_dict`: Dictionary containing node properties

# Returns
- Sanitized name string for the node

Calls `get_sanitized_variable_node_name` if dict has `:name` key,
or `get_sanitized_factor_node_name` if dict has `:fform` key.
Throws error if neither key exists.
"""
function get_sanitized_node_name(single_node_namespace_dict::Dict{Symbol, Any})
    if haskey(single_node_namespace_dict, :name)
        san_node_name_str = get_sanitized_variable_node_name(single_node_namespace_dict)
    elseif haskey(single_node_namespace_dict, :fform)
        san_node_name_str = get_sanitized_factor_node_name(single_node_namespace_dict)
    else
        error("Input single-node namespace dictionary has neither :name nor :fform as a key.")
    end
    return san_node_name_str
end

"""
    get_displayed_label(properties::GraphPPL.FactorNodeProperties) :: String

Returns a quoted display label for a factor node.

# Arguments
- `properties`: Properties of the factor node

# Returns
- `String`: The factor node's pretty name enclosed in double quotes
"""
function get_displayed_label(properties::GraphPPL.FactorNodeProperties)
    # Ensure that the result of prettyname is enclosed in quotes
    label = GraphPPL.prettyname(properties)
    return "\"" * label * "\""
end

"""
    get_displayed_label(properties::GraphPPL.VariableNodeProperties) :: String

Returns a formatted label string for a variable node.

# Arguments
- `properties`: Properties of the variable node

# Returns
- `String`: Label formatted as:
  - Quoted value for constants (e.g. "5") 
  - HTML with subscript for indexed variables (e.g. x<sub>1</sub>)
  - Quoted name for regular variables (e.g. "x")
"""
function get_displayed_label(properties::GraphPPL.VariableNodeProperties)
    if GraphPPL.is_constant(properties)
        # Ensure constants are returned as strings enclosed in quotes
        return "\"" * string(GraphPPL.value(properties)) * "\""

    elseif !isnothing(GraphPPL.index(properties))
        # HTML format for labels with indices
        return string("<", GraphPPL.getname(properties), "<SUB><FONT POINT-SIZE=\"6\">", GraphPPL.index(properties), "</FONT></SUB>", ">")
    else
        # For non-HTML labels, ensure it's enclosed in quotes
        return "\"" * string(GraphPPL.getname(properties)) * "\""
    end
end

"""
Writes DOT notation for nodes in a graph using simple iteration.

Iterates through vertices and writes DOT format for:
- Factor nodes: Light gray squares
- Variable nodes: Circles

# Arguments
- `io_buffer::IOBuffer`: Buffer to write DOT output
- `model_graph::GraphPPL.Model`: Factor graph model to visualize
- `global_namespace_dict::Dict{Int64, Dict{Symbol, Any}}`: Maps vertex IDs to metadata
- `::SimpleIteration`: Specifies simple iteration strategy

# Raises
- `Error`: If a vertex has an unrecognized type
"""
function add_nodes!(
    io_buffer::IOBuffer, model_graph::GraphPPL.Model, global_namespace_dict::Dict{Int64, Dict{Symbol, Any}}, ::SimpleIteration
)
    for vertex in MetaGraphsNext.vertices(model_graph.graph)
        san_label = get_sanitized_node_name(global_namespace_dict[vertex])

        # index the label of model_namespace_variables with "vertex"
        label = MetaGraphsNext.label_for(model_graph.graph, vertex)

        properties = model_graph[label].properties
        displayed_label = get_displayed_label(properties)

        if isa(properties, GraphPPL.FactorNodeProperties)
            displayed_label = replace(displayed_label, "\"" => "", "#" => "")
            write(io_buffer, "    \"$(san_label)\" [shape=square, style=filled, fillcolor=lightgray, label=\"$(displayed_label)\"];\n")
        elseif isa(properties, GraphPPL.VariableNodeProperties)
            write(io_buffer, "    \"$(san_label)\" [shape=circle, label=$(displayed_label)];\n")
        else
            error("Unknown node type for label $(san_label)")
        end
    end
end

"""
Writes DOT syntax for nodes in a graph visualization using breadth-first search traversal.

Traverses the graph starting from the first created node and writes DOT notation for each node:
- Factor nodes are drawn as light gray squares
- Variable nodes are drawn as circles

# Arguments
- `io_buffer::IOBuffer`: Buffer to write the DOT string
- `model_graph::GraphPPL.Model`: Factor graph model to extract nodes from
- `global_namespace_dict::Dict{Int64, Dict{Symbol, Any}}`: Maps vertex IDs to namespace metadata
- `::BFSTraversal`: Specifies BFS traversal strategy

# Raises
- `Error`: If a node has an unrecognized type
"""
function add_nodes!(io_buffer::IOBuffer, model_graph::GraphPPL.Model, global_namespace_dict::Dict{Int64, Dict{Symbol, Any}}, ::BFSTraversal)
    n = nv(model_graph) # number of nodes in the model_graph
    visited = falses(n) # array of visited nodes
    cur_level = Vector{Int}() # current level of nodes processed in BFS/current layer of the BFS iteration
    next_level = Vector{Int}() # next level of nodes for BFS iteration

    s = 1 # always start at the initially created node of model_graph
    if !visited[s]
        visited[s] = true
        push!(cur_level, s)
    end

    while !isempty(cur_level)
        for v in cur_level # iterate over the verticies in the current level

            # we use the sanitized vertex label in the visualization
            san_label = get_sanitized_node_name(global_namespace_dict[v])

            label = MetaGraphsNext.label_for(model_graph.graph, v)
            properties = model_graph[label].properties
            displayed_label = get_displayed_label(properties)

            if isa(properties, GraphPPL.FactorNodeProperties)
                displayed_label = replace(displayed_label, "\"" => "", "#" => "")
                write(io_buffer, "    \"$(san_label)\" [shape=square, style=filled, fillcolor=lightgray, label=\"$(displayed_label)\"];\n")
            elseif isa(properties, GraphPPL.VariableNodeProperties)
                write(io_buffer, "    \"$(san_label)\" [shape=circle, label=$(displayed_label)];\n")
            else
                error("Unknown node type for label $(san_label)")
            end

            for v_neighb in MetaGraphsNext.neighbors(model_graph.graph, v)
                if !visited[v_neighb]
                    visited[v_neighb] = true
                    push!(next_level, v_neighb)
                end
            end
        end
        empty!(cur_level)
        cur_level, next_level = next_level, cur_level
        sort!(cur_level)
    end
end

"""
Writes DOT syntax for edges in a graph visualization using simple iteration.

# Arguments
- `io_buffer::IOBuffer`: Buffer to write the DOT string
- `model_graph::GraphPPL.Model`: Factor graph model to extract edges from 
- `global_namespace_dict::Dict{Int64, Dict{Symbol, Any}}`: Node metadata dictionary
- `::SimpleIteration`: Simple iteration strategy
- `edge_length::Float64`: Visual length of edges in the graph

Iterates through edges in the graph and writes DOT syntax for each one, with edge lengths
controlled by `edge_length`. Uses node metadata from `global_namespace_dict` to generate
node labels.
"""
function add_edges!(
    io_buffer::IOBuffer,
    model_graph::GraphPPL.Model,
    global_namespace_dict::Dict{Int64, Dict{Symbol, Any}},
    ::SimpleIteration,
    edge_length::Float64
)
    for edge in MetaGraphsNext.edges(model_graph.graph)
        source_vertex = MetaGraphsNext.label_for(model_graph.graph, edge.src)
        dest_vertex = MetaGraphsNext.label_for(model_graph.graph, edge.dst)

        # we use the sanitized names of the vertices in the final visualization
        source_san_name = get_sanitized_node_name(global_namespace_dict[source_vertex.global_counter])
        dest_san_name = get_sanitized_node_name(global_namespace_dict[dest_vertex.global_counter])

        write(io_buffer, "    \"$(source_san_name)\" -- \"$(dest_san_name)\" [len=$(edge_length)];\n")
    end
end

"""
Generates DOT syntax for edges in a graph visualization using breadth-first search traversal.

# Arguments
- `io_buffer::IOBuffer`: Buffer to write the DOT string
- `model_graph::GraphPPL.Model`: Factor graph model to extract edges from
- `global_namespace_dict::Dict{Int64, Dict{Symbol, Any}}`: Node metadata dictionary
- `::BFSTraversal`: BFS traversal strategy
- `edge_length::Float64`: Visual length of edges in the graph

Traverses the graph in BFS order and writes DOT syntax for each edge, with edge lengths 
controlled by `edge_length`. Uses node metadata from `global_namespace_dict` to generate 
node labels.
"""
function add_edges!(
    io_buffer::IOBuffer,
    model_graph::GraphPPL.Model,
    global_namespace_dict::Dict{Int64, Dict{Symbol, Any}},
    ::BFSTraversal,
    edge_length::Float64
)
    edge_set = Set{Tuple{Int, Int}}()

    n = nv(model_graph)
    visited = falses(n)
    cur_level = Vector{Int}()
    next_level = Vector{Int}()

    s = 1
    if !visited[s]
        visited[s] = true
        push!(cur_level, s)
    end

    while !isempty(cur_level)
        for v in cur_level
            for v_neighb in MetaGraphsNext.neighbors(model_graph.graph, v)
                edge = (min(v, v_neighb), max(v, v_neighb))
                if !(edge in edge_set)
                    source_vertex = MetaGraphsNext.label_for(model_graph.graph, v)
                    dest_vertex = MetaGraphsNext.label_for(model_graph.graph, v_neighb)

                    source_san_name = get_sanitized_node_name(global_namespace_dict[source_vertex.global_counter])

                    dest_san_name = get_sanitized_node_name(global_namespace_dict[dest_vertex.global_counter])

                    write(io_buffer, "    \"$(source_san_name)\" -- \"$(dest_san_name)\" [len=$(edge_length)];\n")
                    push!(edge_set, edge)
                end

                if !visited[v_neighb]
                    visited[v_neighb] = true
                    push!(next_level, v_neighb)
                end
            end
        end
        empty!(cur_level)
        cur_level, next_level = next_level, cur_level
        sort!(cur_level)
    end
end

"""
A 'wrapper' arround a user-specified Symbolic expression which returns 
the associated traversal type. 
"""
function convert_strategy(strategy::Symbol)
    if strategy == :simple
        return SimpleIteration()
    elseif strategy == :bfs
        return BFSTraversal()
    else
        error("Unknown traversal strategy: $strategy")
    end
end

"""
    GraphVizGraphWrapper

A wrapper type for GraphViz.Graph that restricts display capabilities to SVG and text formats only.

This wrapper is designed to prevent display issues that can occur with PNG format on some systems
by limiting the available display formats to SVG and plain text.

# Fields
- `graph::GraphViz.Graph`: The wrapped GraphViz graph object
- `dot_string::String`: The DOT string representation of the graph
"""
struct GraphVizGraphWrapper
    graph::GraphViz.Graph
    dot_string::String
end

# Override showable to only allow SVG and text display
function Base.showable(mime::MIME, x::GraphVizGraphWrapper)
    if mime isa MIME"image/svg+xml" || mime isa MIME"text/plain"
        return showable(mime, x.graph)
    end
    return false
end

# Delegate show methods to the wrapped graph
function Base.show(io::IO, mime::MIME"image/svg+xml", x::GraphVizGraphWrapper)
    show(io, mime, x.graph)
end

function Base.show(io::IO, mime::MIME"text/plain", x::GraphVizGraphWrapper)
    show(io, mime, x.dot_string)
end

"""
Converts a GraphPPL.Model to a DOT string for visualization with GraphViz.jl.

# Arguments
- `model_graph::GraphPPL.Model`: The factor graph model to visualize
- `strategy::Symbol`: Graph traversal strategy (`:simple` or `:bfs`)
- `font_size::Int=12`: Font size for node labels
- `edge_length::Float64=1.0`: Visual length of edges
- `layout::String="neato"`: GraphViz layout engine ("dot", "neato", "fdp", etc)
- `overlap::Bool=false`: Whether to allow node overlap
- `width::Float64=10.0`: Display width in inches
- `height::Float64=10.0`: Display height in inches 
- `save_to::String=nothing`: Optional path to save SVG output

# Returns
- `GraphVizGraphWrapper`: A wrapper around the GraphViz.Graph object that restricts display capabilities to SVG and text formats only. 
Use `.graph` property to access the GraphViz.Graph object directly.
Use `.dot_string` property to access the DOT string representation of the graph.

# Details
Generates a DOT string visualization of a GraphPPL.Model with configurable layout and styling options.
If `save_to` is provided, saves the visualization as an SVG file.
"""
function GraphViz.load(
    model_graph::GraphPPL.Model;
    strategy::Symbol,
    font_size::Int = 12,
    edge_length::Float64 = 1.0,
    layout::String = "neato",
    overlap::Bool = false,
    width::Float64 = 10.0,
    height::Float64 = 10.0,
    save_to::Union{String, Nothing} = nothing
)
    traversal_strategy = convert_strategy(strategy)

    # get the entire namespace dict
    global_namespace_dict = get_namespace_variables_dict(model_graph)

    # use Base.IOBuffer instead of string concatenation
    io_buffer = IOBuffer()

    write(io_buffer, "graph G {\n")
    write(io_buffer, "    layout=$(layout);\n")
    write(io_buffer, "    overlap =$(string(overlap));\n") # control if allowing node overlaps
    write(io_buffer, "    size=\"$(width),$(height)!\";\n")
    write(io_buffer, "    node [shape=circle, fontsize=$(font_size)];\n")

    # Nodes
    add_nodes!(io_buffer, model_graph, global_namespace_dict, traversal_strategy)

    # Edges
    add_edges!(io_buffer, model_graph, global_namespace_dict, traversal_strategy, edge_length)

    write(io_buffer, "}")

    final_string = String(take!(io_buffer))
    final_graph = GraphViz.Graph(final_string)

    if !isnothing(save_to)
        open(save_to, "w") do io
            show(io, MIME"image/svg+xml"(), final_graph)
        end
    end

    return GraphVizGraphWrapper(final_graph, final_string)
end

end