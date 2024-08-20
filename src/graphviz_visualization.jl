
"""
These abstract types are used as arguments in the respective generate_dot methods
and are used by Julia's multiple dispatch system to decide which method of generate_dot to call. 

"""
abstract type TraversalStrategy end
struct SimpleIteration <: TraversalStrategy end
struct BFSTraversal <: TraversalStrategy end

"""
    get_node_properties(model::GraphPPL.Model, vertex)

Get the properties of a node in a GraphPPL model.

# Arguments
- `model::GraphPPL.Model`: The GraphPPL model.
- `vertex`: The vertex representing the node.

# Returns
A dictionary containing the properties of the node, including the label and field names.

"""
function get_node_properties(model::GraphPPL.Model, vertex)
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
        namespace_variables[field_name] = getproperty(properties, field_name)
    end

    return namespace_variables
end

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
Returns a dict of dicts where each key is the unique 
GraphPPL.NodeLabel.global_counter value for each node.
Each value is a dictionary containing the namespace for 
the node with ID == Key. 

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
Input: the namespace dictionary for a particular variable node. 

Return value: a string containing the variable node name, variable node ID
and variable node value. These three fields are to be the default variable node
"""
function get_sanitized_variable_node_name(var_namespace_dict)
    
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
Input: the namespace dictionary for a particular factor node. 

Return value: a string containing only the name for the input factor node 
namespace dictionary. 
"""
function get_sanitized_factor_node_name(fac_namespace_dict)

    san_str_name_fac = string(fac_namespace_dict[:label]) # was :fform
    
    return san_str_name_fac
end

"""
Input: a namespace dictionary for an arbitrary node (variable node or factor node).

Return value: a string cotaining either the return value of 
get_sanitized_variable_node_name or get_sanitized_factor_node_name.
"""
function get_sanitized_node_name(single_node_namespace_dict)
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
Input: a string containing the DOT code corresponding to a GraphPPL.Model

Return value: returns the input string, stripped of the leading and 
trailing non-DOT syntax.

"""
function strip_dot_wrappers(dot_string::String)
    stripped_string = replace(dot_string, r"^dot\"\"\"\n" => "")
    stripped_string = replace(stripped_string, r"\n\"\"\"$" => "")
    
    return stripped_string
end

"""
Writes the given DOT string to a file specified by file_path.

# Arguments:
- dot_string: The DOT format string to write to the file.
- file_path: The path of the file where the DOT string should be written.

# Returns:
- Bool: Returns true if the file was written successfully, otherwise false.

# Throws:
- SystemError: If there is an error in opening/writing to the file.

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
Generate a PDF file from a DOT file using Graphviz's dot command.

# Arguments
- src_dot_file_path: The path to the source DOT file.
- dst_pdf_file_path_name: The desired path and name for the output PDF file.

# Returns
- Bool: true if the PDF generation is successful, false otherwise.

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
Convert a DOT string to a PDF file.

This function encapsulates the process of stripping unnecessary wrappers from the DOT string,
writing it to a temporary DOT file, converting it to a PDF using Graphviz, and cleaning up the 
temporary file.

# Arguments:
- dot_string: The DOT format string to be converted.
- dst_pdf_file: The desired path and name for the output PDF file.

# Returns:
- Bool: true if the PDF generation is successful, false otherwise.

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
Responsible for contructing the portion of the final DOT string which
specifies the nodes in the eventual GraphViz visualization. 

This method of add_nodes! simply iterates over the set of verticies from the constituent 
MetaGraphsNext.MetaGraph contained in model_graph. 

Raises an error if the type of any vertex is not recognized. 

# Arguments:
- io_buffer: an IOBuffer is used to perform iterative writes as opposed to string concatenation. 
- model_graph: the GraphPPL.Model structure containing the raw factor graph. 
- global_namespace_dict: the namespace dictionary for all nodes in the model_graph. 
  Otherwise known as the global namespace dictionary. 
- ::SimpleIteration: identifies the desired iteration strategy as SimpleIteration. 

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
Responsible for contructing the portion of the final DOT string which
specifies the nodes in the eventual GraphViz visualization. 

This method of add_nodes! conducts a Breadth First Search (BFS) from the initially-created 
node of the model_graph. 

Raises an error if the type of any vertex is not recognized. 

# Arguments:
- io_buffer: an IOBuffer is used to perform iterative writes as opposed to string concatenation. 
- model_graph: the GraphPPL.Model structure containing the raw factor graph. 
- global_namespace_dict: the namespace dictionary for all nodes in the model_graph. 
  Otherwise known as the global namespace dictionary. 
- ::BFSTraversal: identifies the desired iteration strategy as BFSTraversal. 

"""
function add_nodes!(
        io_buffer::IOBuffer, 
        model_graph::GraphPPL.Model, 
        global_namespace_dict::Dict{Int64, Dict{Symbol, Any}}, 
        ::BFSTraversal
    )
    
    n = nv(model_graph) # number of nodes in the 
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
Responsible for contructing the portion of the final DOT string which
specifies the edges between the included nodes in the eventual GraphViz visualization. 

This method of add_edges! simply iterates over the set of edges from the constituent 
MetaGraphsNext.MetaGraph contained in model_graph.

# Arguments:
- io_buffer: an IOBuffer is used to perform iterative writes as opposed to string concatenation. 
- model_graph: the GraphPPL.Model structure containing the raw factor graph. 
- global_namespace_dict: the namespace dictionary for all nodes in the model_graph. 
  Otherwise known as the global namespace dictionary. 
- ::SimpleIteration: identifies the desired iteration strategy as SimpleIteration. 
- edge_length: a floating point value to control the length of the edges. 


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
Responsible for contructing the portion of the final DOT string which
specifies the edges between the included nodes in the eventual GraphViz visualization. 

This method of add_edges! conducts a Breadth First Search (BFS) from the initially-created 
node of the model_graph. 

# Arguments:
- io_buffer: an IOBuffer is used to perform iterative writes as opposed to string concatenation. 
- model_graph: the GraphPPL.Model structure containing the raw factor graph. 
- global_namespace_dict: the namespace dictionary for all nodes in the model_graph. 
  Otherwise known as the global namespace dictionary. 
- ::BFSTraversal: identifies the desired iteration strategy as BFSTraversal. 
- edge_length: a floating point value to control the length of the edges. 

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
Constructs the DOT string from an input GraphPPL.Model.

# Arguments:
- model_graph: the GraphPPL.Model structure containing the raw factor graph. 
- strategy: the abstract type which specifies the particular traversal strategy. 
Either SimpleIteration() or BFSTraversal().
- font_size: the font size of the node fields. 
- edge_length: a floating point value to control the length of the edges. 
- layout: layout engine for the eventual display. Default is "neato".  
- width: width of the display window.
- height: height of the display window.

# Returns:
- String: a string containing the DOT code which can then be executed 
to yield a GraphViz visualization. 

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
Executes the DOT string returned by generate_dot.

# Arguments:
- dot_code_graph: the DOT string returned by generate_dot. 
"""
function show_gv(dot_code_graph::String)
    try
        eval(Meta.parse(dot_code_graph))
    catch e
        error("Could not evaluate the input DOT string: ", e)
    end
end