module GraphPPLGraphVizExt
using GraphPPL, MetaGraphsNext, GraphViz
using GraphPPL.MetaGraphsNext
import MetaGraphsNext: nv

import GraphViz: load

"""
This abstract type represents a node traversal strategy for use with the `GraphViz.load` function.

This abstract type is used to define various strategies for traversing nodes in the graph when generating a DOT representation. 
Each concrete subtype specifies a different traversal approach, which is selected by Julia's multiple dispatch system 
when calling `GraphViz.load`.

Concrete subtypes:
- `SimpleIteration`: Represents a simple iteration of the graph's vertex/node set.
- `BFSTraversal`: Represents a breadth-first search traversal strategy, from the initially created node.

These types afford a trade-off between a relatively fast and a relatively 'principled' iteration strategy (respectfully), 
in addition to affecting the layout of the final visualization.
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

Creates a dictionary mapping each node's global counter ID to its corresponding 
properties within a `GraphPPL.Model`.

# Arguments
- `model::GraphPPL.Model`: The probabilistic graphical model from which node 
properties will be extracted.

# Returns
- A `Dict{Int64, Dict{Symbol, Any}}` where:
  - The keys are the global counter IDs (`Int64`) of the nodes within the model. 
    This is the GraphPPL.NodeLabel.global_counter value.
  - The values are all dictionaries (`Dict{Symbol, Any}`), containing the properties 
  of the corresponding nodes.
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

Generates a sanitized string representation of a variable node's name, ID, and value.

# Arguments
- `var_namespace_dict::Dict{Symbol, Any}`: The namespace dictionary for a particular 
   variable node. 

# Returns
- A `String` that concatenates the variable node's name (label) and its value. 
If the value is `nothing`, the string `"nothing"` is used instead. The format 
of the returned string is `"<variable_name>:<variable_value>"`.

# Details
This function extracts the `label` (which serves as the variable node's name - for now) 
and `value` from the input dictionary and constructs a string in the format 
`"<label>:<value>"`. If the value is `nothing`, the string `"nothing"` is used 
in place of the value.
"""
function get_sanitized_variable_node_name(var_namespace_dict::Dict{Symbol, Any})
    san_str_name_var = string(var_namespace_dict[:label]) # was :name

    if var_namespace_dict[:value] == nothing
        str_val_var = "nothing"
    else
        str_val_var = string(var_namespace_dict[:value])
    end

    final_str = string(san_str_name_var, ":", str_val_var)

    return final_str
end

"""
    get_sanitized_factor_node_name(fac_namespace_dict::Dict{Symbol, Any})

Generates a sanitized string representation of a factor node's name.

# Arguments
- `fac_namespace_dict::Dict{Symbol, Any}`: A dictionary containing the properties 
of a factor node, specifically its label.

# Returns
- A `String` containing the sanitized name of the factor node, derived from the 
`label` field in the input dictionary.

# Details
This function extracts the `label` from the input dictionary, which serves as 
the name of the factor node. It then converts the label to a string and returns 
it as the sanitized name of the factor node.

"""
function get_sanitized_factor_node_name(fac_namespace_dict::Dict{Symbol, Any})
    san_str_name_fac = string(fac_namespace_dict[:label]) # was :fform
    san_str_name_fac = replace(san_str_name_fac, "\"" => "", "#" => "")
    return san_str_name_fac
end

"""
    get_sanitized_node_name(single_node_namespace_dict::Dict{Symbol, Any})

Generates a sanitized name for a node (either a variable node or a factor node) 
based on its properties.

# Arguments
- `single_node_namespace_dict::Dict{Symbol, Any}`: A dictionary containing the 
properties of a node, which is either a variable node or a factor node.

# Returns
- A `String` representing the sanitized name of the node. This is determined 
by calling either `get_sanitized_variable_node_name` for variable nodes, or 
`get_sanitized_factor_node_name` for factor nodes.

# Details
This function determines whether the input dictionary represents a variable 
node or a factor node by checking the presence of specific keys:
- If the dictionary contains the `:name` key, the node is considered a variable 
  node, and `get_sanitized_variable_node_name` is called.
- If the dictionary contains the `:fform` key, the node is considered a factor 
  node, and `get_sanitized_factor_node_name` is called.

If neither key is found, the function throws an error indicating that the 
dictionary is missing the necessary information to determine the node type.
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
    dot_string_to_svg(dot_string::String, dst_pdf_file::String) :: Bool

Converts a DOT string to a SVG file via the following steps:
"""
function buffer_to_svg(dot_string::String, dst_svg_file::String)::Bool
    # pure_dot_string = strip_dot_wrappers(dot_string)
    loaded = GraphViz.load(IOBuffer(dot_string))
    open(dst_svg_file, "w") do io
        show(io, MIME"image/svg+xml"(), loaded)
    end
    return true
end

"""
    get_displayed_label(properties::GraphPPL.FactorNodeProperties) :: String

Extracts and returns the displayed label for a `FactorNode` in a GraphPPL.Model. The label is generated 
using the `prettyname` function and is enclosed in double quotes for consistent formatting.

# Arguments
- `properties::GraphPPL.FactorNodeProperties`: The properties of the factor node from which the label is extracted.

# Returns
- `String`: A string containing the label of the factor node, enclosed in double quotes.

# Details
This function calls the `GraphPPL.prettyname` method to generate a "pretty" label for the factor node. The resulting label
is then enclosed in quotes for consistency in visualization or formatting.
"""
function get_displayed_label(properties::GraphPPL.FactorNodeProperties)
    # Ensure that the result of prettyname is enclosed in quotes
    label = GraphPPL.prettyname(properties)
    return "\"" * label * "\""
end

"""
    get_displayed_label(properties::GraphPPL.VariableNodeProperties) :: String

Extracts and returns the displayed label for a `VariableNode` in a GraphPPL.Model. The format of the label
depends on whether the node is a constant or has an index. Constants are displayed as string values enclosed
in quotes, while indexed variables are displayed in HTML format with a subscript. Other variable nodes are displayed
with their name in quotes.

# Arguments
- `properties::GraphPPL.VariableNodeProperties`: The properties of the variable node from which the label is extracted.

# Returns
- `String`: A string containing the label of the variable node - varying as described above, depending on the node's properties:
  - For constants, the label is the string representation of the constant value enclosed in quotes.
  - For indexed variables, the label is in HTML format with the variable name and index as a subscript.
  - For other variables, the label is simply the name of the variable enclosed in quotes.

# Details
The function handles three cases:
1. If the node is a constant (checked by `GraphPPL.is_constant`), the value is displayed in quotes.
2. If the node has an index, the label is displayed in HTML format with a subscript showing the index.
3. If neither condition is true, the label is the node's name enclosed in quotes.
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
Constructs the portion of the DOT string that specifies the nodes in the GraphViz visualization.
Specifically, by means of the simple iteration strategy specified by the `SimpleIteration` subtype. 

This function iterates over the vertices of the graph contained in the `model_graph`, 
which is an instance of `GraphPPL.Model`. It writes the appropriate DOT notation for each 
node to the provided `io_buffer`. The function handles two types of nodes:
- `GraphPPL.FactorNodeProperties`: Represented as squares with a light gray fill color.
- `GraphPPL.VariableNodeProperties`: Represented as circles.

# Arguments:
- `io_buffer::IOBuffer`: The buffer to which DOT string segments are written. 
  Used for efficient iterative writes rather than string concatenation.
- `model_graph::GraphPPL.Model`: The GraphPPL model containing the factor graph. 
  This provides the raw graph structure from which nodes are extracted.
- `global_namespace_dict::Dict{Int64, Dict{Symbol, Any}}`: A dictionary mapping vertex IDs to their 
  namespace dictionaries. This global namespace dictionary provides node-specific metadata.
- `::SimpleIteration`: Specifies the iteration strategy to use, here set to `SimpleIteration`.

# Raises:
- `Error`: If a vertex's properties are of an unrecognized type.
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
Constructs the portion of the DOT string that specifies the nodes in the GraphViz visualization.
Specifically, by means of a Breadth First Search (BFS) from the initially-created 
node of the 'model_graph'.

This function iterates over the vertices of the graph contained in the `model_graph`, 
which is an instance of `GraphPPL.Model`. It writes the appropriate DOT notation for each 
node to the provided `io_buffer`. The function handles two types of nodes:
- `GraphPPL.FactorNodeProperties`: Represented as squares with a light gray fill color.
- `GraphPPL.VariableNodeProperties`: Represented as circles.

# Arguments:
- `io_buffer::IOBuffer`: The buffer to which DOT string segments are written. 
  Used for efficient iterative writes rather than string concatenation.
- `model_graph::GraphPPL.Model`: The GraphPPL model containing the factor graph. 
  This provides the raw graph structure from which nodes are extracted.
- `global_namespace_dict::Dict{Int64, Dict{Symbol, Any}}`: A dictionary mapping vertex IDs to their 
  namespace dictionaries. This global namespace dictionary provides node-specific metadata.
- `::BFSTraversal`: Specifies the BFS iteration strategy. The search is carried out from the initially created node.

# Raises:
- `Error`: If a vertex's properties are of an unrecognized type.
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
Constructs the portion of the DOT string that specifies the edges between nodes in a 
GraphViz visualization. This function iterates over the edges in the `model_graph`  via 
the `SimpleIteration` strategy and generates the corresponding DOT syntax to represent these 
edges. Each edge connects two nodes, and the `edge_length` parameter controls the visual 
length of these edges in the final graph.

# Arguments:
- `io_buffer::IOBuffer`: An IOBuffer used for efficient iterative writing of the DOT string. 
- `model_graph::GraphPPL.Model`: The GraphPPL model containing the raw factor graph from 
   which edges are extracted.
- `global_namespace_dict::Dict{Int64, Dict{Symbol, Any}}`: A dictionary mapping vertex IDs 
   to their namespace dictionaries. This global namespace provides metadata for each node.
- `::SimpleIteration`: Specifies the iteration strategy, here set to `SimpleIteration`.
- `edge_length::Float64`: A floating-point value that specifies the length of the edges in 
   the visualization.
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
Constructs the portion of the DOT string that specifies the edges between nodes in a 
GraphViz visualization. This function iterates over the edges in the `model_graph`  via 
the `BFSTraversal` strategy and generates the corresponding DOT syntax to represent these 
edges. Each edge connects two nodes, and the `edge_length` parameter controls the visual 
length of these edges in the final graph.

# Arguments:
- `io_buffer::IOBuffer`: An IOBuffer used for efficient iterative writing of the DOT string. 
- `model_graph::GraphPPL.Model`: The GraphPPL model containing the raw factor graph from 
   which edges are extracted.
- `global_namespace_dict::Dict{Int64, Dict{Symbol, Any}}`: A dictionary mapping vertex IDs 
   to their namespace dictionaries. This global namespace provides metadata for each node.
- `::BFSTraversal`: Specifies the iteration strategy, here set to `BFSTraversal`.
- `edge_length::Float64`: A floating-point value that specifies the length of the edges in 
   the visualization.
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
This is the crucial function in the GraphPPLGraphVizExt.jl extension. 
Constructs a DOT string from a `GraphPPL.Model` for visualization with GraphViz.jl. 
The DOT string includes configuration options for node appearance, edge length, layout, and other 
visualization parameters. The generated graph is saved as a PDF to the specified `save_to` file path.

# Arguments:
- `model_graph::GraphPPL.Model`: The `GraphPPL.Model` structure containing the raw factor 
   graph to be visualized.
- `strategy::Symbol`: Specifies the traversal strategy for graph traversal. This is a symbolic value 
   that will be converted to a valid traversal strategy used by the `GraphPPL.Model`.
- `font_size::Int`: The font size of the node labels. Default is `12`.
- `edge_length::Float64` (default is `1.0`): Controls the visual length of edges in the graph.
- `layout::String` (default is `"neato"`): The layout engine to be used by GraphViz for 
   arranging the nodes. Common options include `"dot"`, `"neato"`, `"fdp"`, etc.
- `overlap::Bool`: Controls whether node overlap is allowed in the visualization. Default is `false`.
- `width::Float64` (default is `10.0`): The width of the display window in inches.
- `height::Float64` (default is `10.0`): The height of the display window in inches.
- `save_to::String`: If provided, this is the file path where the generated PDF of the visualized will be saved.

# Returns:
- `String`: A DOT format string representing the graph, which can be used to generate a GraphViz visualization.

# Details:
This function generates a DOT string based on the input `GraphPPL.Model`, affording the visualization 
of an arbitrary GraphPPL.Model with GraphViz.jl. The DOT string includes options for controlling the layout, node 
properties, edge length, and other appearance-related attributes.

The resulting graph is saved as a SVG file. The file is saved to the path 
specified by the `save_to` argument. 
If the file cannot be saved (e.g., due to permission issues), a warning will be logged.
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
    final_dot = GraphViz.Graph(final_string)

    if !isnothing(save_to)
        open(save_to, "w") do io
            show(io, MIME"image/svg+xml"(), final_dot)
        end
    end

    return final_dot
end

end