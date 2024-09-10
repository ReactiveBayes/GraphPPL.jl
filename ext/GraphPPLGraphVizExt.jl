module GraphPPLGraphVizExt

export generate_dot, show_gv, dot_string_to_pdf, SimpleIteration, BFSTraversal

using GraphPPL, MetaGraphsNext, GraphViz

"""
This abstract type represents a node traversal strategy for use with the `generate_dot` function.

This abstract type is used to define various strategies for traversing nodes in the graph when generating a DOT representation. 
Each concrete subtype specifies a different traversal approach, which is selected by Julia's multiple dispatch system 
when calling `generate_dot`.

Concrete subtypes:
- `SimpleIteration`: Represents a simple iteration of the graph's vertex/node set.
- `BFSTraversal`: Represents a breadth-first search traversal strategy, from the initially created node.

These types afford a trade-off between a relatively fast and a relatively 'principled' iteration strategy (respectfully).
"""
abstract type TraversalStrategy end
struct SimpleIteration <: TraversalStrategy end
struct BFSTraversal <: TraversalStrategy end

"""
    get_node_properties(model::GraphPPL.Model, vertex::Int64)

Extracts the properties of a specific node in a `GraphPPL.Model` and returns them as a dictionary.

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
and returns them as a dictionary.

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
    strip_dot_wrappers(dot_string::String)

Strips non-DOT syntax from the beginning and end of a GraphViz.jl DOT code string.

# Arguments
- `dot_string::String`: A string containing the DOT code generated for a 
`GraphPPL.Model`, including the GraphViz.jl wrapper code (non-DOT syntax) at the 
beginning and end.

# Returns
- A `String` with the leading and trailing non-DOT syntax removed, leaving 
only the valid DOT code.

# Details
This function is designed to clean up GraphViz.jl DOT code strings by removing the specific 
wrapper syntax that may is present at the beginning and end of such a string. It removes:
- The leading 'dot...' sequence at the start.
- The trailing '...n' sequence at the end.

The resulting string is ready for use in DOT-compatible tools.
"""
function strip_dot_wrappers(dot_string::String)
    stripped_string = replace(dot_string, r"^dot\"\"\"\n" => "")
    stripped_string = replace(stripped_string, r"\n\"\"\"$" => "")
    
    return stripped_string
end

"""
    write_to_dot_file(dot_string::String, file_path::String) :: Bool

Writes the given DOT format string to a file specified by `file_path`.

# Arguments
- `dot_string::String`: The DOT format string to be written to the file.
- `file_path::String`: The path of the file where the DOT string will be written.

# Returns
- `Bool`: Returns `true` if the file was written successfully; otherwise, returns `false`.

# Throws
- `SystemError`: If there is an error in opening or writing to the file.

# Details
Attempts to write a DOT string to the specified file path. 
If the operation is successful, it returns `true`. If an error occurs, it logs 
the error and returns `false`.
"""
function write_to_dot_file(dot_string::String, file_path::String) :: Bool
    try
        open(file_path, "w") do file
            write(file, dot_string)
        end
        return true
    catch e
        @error "Failed to write to file $file_path" exception = (e, catch_backtrace())
        return false
    end
end

"""
    generate_pdf_from_dot(src_dot_file_path::String, dst_pdf_file_path_name::String) :: Bool

Generates a PDF file from a DOT file using Graphviz's `dot` command.

# Arguments
- `src_dot_file_path::String`: The path to the source DOT file.
- `dst_pdf_file_path_name::String`: The desired path and name for the output PDF file.

# Returns
- `Bool`: Returns `true` if the PDF generation is successful; otherwise, returns `false`.

# Details
This function takes a DOT file specified by `src_dot_file_path` and converts it to a PDF 
file using the Graphviz `dot` command. The resulting PDF is saved to the path 
specified by `dst_pdf_file_path_name`. The function returns `true` upon successful generation 
of the PDF, and `false` if any error occurs during the process.
"""
function generate_pdf_from_dot(src_dot_file_path::String, dst_pdf_file_path_name::String) :: Bool
    try
        run(`dot -Tpdf $src_dot_file_path -o $dst_pdf_file_path_name`)
        return true
    catch
        return false
    end
end

"""
    dot_string_to_pdf(dot_string::String, dst_pdf_file::String) :: Bool

Converts a DOT string to a PDF file via the following steps:
1. Strips unnecessary wrappers from the DOT string.
2. Writes the cleaned DOT string to a temporary DOT file.
3. Converts the temporary DOT file to a PDF using Graphviz's `dot` command.
4. Cleans up the temporary DOT file.

# Arguments
- `dot_string::String`: The DOT format string to be converted into a PDF.
- `dst_pdf_file::String`: The path and filename where the output PDF should be saved.

# Returns
- `Bool`: Returns `true` if the PDF generation is successful, `false` otherwise.

# Details
The function first processes the input DOT string to remove any non-DOT syntax wrappers. 
It then writes the cleaned string to a temporary file named `"tmp.dot"`. 
After generating the PDF using Graphviz, the temporary file is removed. 
The function returns `true` if all operations complete successfully, and `false` 
if an error occurs during any step.
"""
function dot_string_to_pdf(dot_string::String, dst_pdf_file::String) :: Bool
    tmp_dot_file = "tmp.dot"
    try
        pure_dot_string = strip_dot_wrappers(dot_string)
        write_to_dot_file(pure_dot_string, tmp_dot_file)
        success = generate_pdf_from_dot(tmp_dot_file, dst_pdf_file)
        return success
    catch
        return false
    finally
        if isfile(tmp_dot_file)
            rm(tmp_dot_file)
        end
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
        io_buffer::IOBuffer, 
        model_graph::GraphPPL.Model, 
        global_namespace_dict::Dict{Int64, Dict{Symbol, Any}},
        ::SimpleIteration
    )
    
    for vertex in MetaGraphsNext.vertices(model_graph.graph)
        
        # index the label of model_namespace_variables with "vertex"
        san_label = get_sanitized_node_name(global_namespace_dict[vertex])
        
        label = MetaGraphsNext.label_for(model_graph.graph, vertex)
        
        properties = model_graph[label].properties
        
        if isa(properties, GraphPPL.FactorNodeProperties)
            write(io_buffer, "    \"$(san_label)\" [shape=square, style=filled, fillcolor=lightgray];\n")
        elseif isa(properties, GraphPPL.VariableNodeProperties)
            write(io_buffer, "    \"$(san_label)\" [shape=circle];\n")
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
function add_nodes!(
        io_buffer::IOBuffer, 
        model_graph::GraphPPL.Model, 
        global_namespace_dict::Dict{Int64, Dict{Symbol, Any}}, 
        ::BFSTraversal
    )
    
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
            
            if isa(properties, GraphPPL.FactorNodeProperties)
                write(io_buffer, "    \"$(san_label)\" [shape=square, style=filled, fillcolor=lightgray];\n")
            elseif isa(properties, GraphPPL.VariableNodeProperties)
                write(io_buffer, "    \"$(san_label)\" [shape=circle];\n")
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
                    
                    source_san_name = get_sanitized_node_name(
                        global_namespace_dict[source_vertex.global_counter]
                    )

                    dest_san_name = get_sanitized_node_name(
                        global_namespace_dict[dest_vertex.global_counter]
                    )
                    
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
Constructs a DOT string from an input `GraphPPL.Model` for visualization with GraphViz.jl. 
The DOT string includes configuration options for node appearance, edge length, layout, and more.

# Arguments:
- `model_graph::GraphPPL.Model`: The `GraphPPL.Model` structure containing the raw factor 
   graph to be visualized.
- `strategy::TraversalStrategy`: Specifies the traversal strategy for graph traversal. 
   Either `SimpleIteration()` or `BFSTraversal()`.
- `font_size::Int`: The font size of the node labels.
- `edge_length::Float64` (default is `1.0`): Controls the visual length of edges in the graph.
- `layout::String` (default is `"neato"`): The layout engine to be used by GraphViz for 
   arranging the nodes.
- `overlap::Bool`: Controls whether node overlap is allowed in the visualization.
- `width::Float64` (default is `10.0`): The width of the display window in inches.
- `height::Float64` (default is `10.0`): The height of the display window in inches.

# Returns:
- `String`: A DOT format string that can be used to generate a GraphViz visualization.
"""
function generate_dot(;
        model_graph::GraphPPL.Model, 
        strategy::TraversalStrategy,
        font_size::Int, 
        edge_length::Float64 = 1.0, 
        layout::String = "neato", 
        overlap::Bool,
        width::Float64 = 10.0, 
        height::Float64 = 10.0
    )
    
    # get the entire namespace dict
    global_namespace_dict = get_namespace_variables_dict(model_graph)
    
    # use Base.IOBuffer instead of string concatenation
    io_buffer = IOBuffer()
    
    write(io_buffer, "dot\"\"\"\ngraph G {\n")
    write(io_buffer, "    layout=$(layout);\n")
    write(io_buffer, "    overlap =$(string(overlap));\n") # control if allowing node overlaps
    write(io_buffer, "    size=\"$(width),$(height)!\";\n")
    write(io_buffer, "    node [shape=circle, fontsize=$(font_size)];\n")
    
    # Nodes
    add_nodes!(io_buffer, model_graph, global_namespace_dict, strategy)
    
    # Edges
    add_edges!(io_buffer, model_graph, global_namespace_dict, strategy, edge_length)
    
    write(io_buffer, "}\n\"\"\"")
    
    final_dot = String(take!(io_buffer))
    
    return final_dot
end

"""
    show_gv(dot_code_graph::String)

Executes the DOT string to display the graph using Graphviz.

This function evaluates the DOT string generated by the `generate_dot` 
function, and displays the graph visualization. It uses  Julia's `eval` 
and `Meta.parse` functions to interpret and execute the DOT code.

# Arguments:
- `dot_code_graph::String`: The DOT format string representing the graph to be 
visualized. This string is expected to be valid DOT code generated by the 
`generate_dot` function, as per the convention used in GraphViz.jl.

# Throws:
- `ErrorException`: If there is an error while evaluating the DOT string, an 
exception will be raised with a message indicating the problem.
"""
function show_gv(dot_code_graph::String)
    try
        eval(Meta.parse(dot_code_graph))
    catch e
        error("Could not evaluate the input DOT string: ", e)
    end
end

end
