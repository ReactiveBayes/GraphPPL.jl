using Graphs
using MetaGraphsNext
import Base: put!, haskey, gensym, getindex
import MacroTools: postwalk, capture
using GraphPlot, Compose
import Cairo

struct Context
    prefix :: String
    contents :: Dict{Symbol, Union{Symbol, Context}}
end

name(f::Function) = String(Symbol(f))
vals(kwargs::Base.Pairs) = [entry for entry in values(kwargs)]

Context(prefix::String) = Context(prefix, Dict())    
Context(parent::Context, model_name::String) = Context(parent.prefix * model_name * "_")
Context(parent::Context, model_name::Function) = Context(parent, name(model_name))
Context() = Context("")

haskey(context :: Context, key::Symbol) = haskey(context.contents, key)

gensym(context :: Context, key::Symbol) = gensym(Symbol(context.prefix * String(key)))
gensym(context :: Context, key::Function) = gensym(Symbol(context.prefix * name(key)))

getindex(c::Context, key::Symbol) = c.contents[key]


function pprint(str:: String, indent :: Int)
    print("   "^indent * str)
end

function pprint(context :: Context, indent=0)
    println("Context " * context.prefix * "{")
    for pair in context.contents
        pprint(pair, indent+1)
    end
    pprint("} \n", indent)
end

function pprint(pair :: Pair{Symbol, Union{Symbol, Context}}, indent=0)
    pprint(String(pair[1]) * " : ", indent)
    pprint(pair[2], indent)
end

function pprint(symbol :: Symbol, indent=0)
   println(String(symbol))
end

abstract type NodeType end

struct Composite <: NodeType end
struct Atomic <: NodeType end


NodeType(::Type) = Atomic()
NodeType(::Function) = Atomic()

function Base.put!(context :: Context, name :: Symbol, variable :: Union{Symbol, Context})
    if haskey(context, name)
        throw(ErrorException("Variable " * String(name) * " in Context " * context.prefix * " is duplicate."))
    end
    context.contents[name] = variable
end


function create_model(interfaces...)
    model = MetaGraph(
        Graph(),
        Label = Symbol,
        VertexData = Tuple{Bool, String},
        graph_data = Context(),
        EdgeData = Symbol
    )
    for interface in interfaces
        model[interface] = (true, String(interface))
        put!(model[], interface, interface)

    end
    return model
end

function add_variable_node!(model:: MetaGraph, context :: Context, variable_id::Symbol)
    variable_symbol = gensym(context, variable_id)
    put!(context, variable_id, variable_symbol)
    model[variable_symbol] = (true, String(variable_id))
    return variable_symbol
end

function add_atomic_factor_node!(model :: MetaGraph, context :: Context, node_name::Union{Function, Symbol})
    node_id = gensym(context, node_name)
    model[node_id] = (false, name(node_name))
    put!(context, node_id, node_id)
    return node_id
end

function add_composite_factor_node!(parent_context :: Context, context :: Context, node_name::Union{Function, Symbol})
    node_id = gensym(parent_context, node_name)
    put!(parent_context, node_id, context)
    return node_id
end

getorcreate(model::MetaGraph, context::Context, edge::Symbol) = get(() -> add_variable_node!(model, context, edge), context, edge)
    # if !(haskey(context, edge))
    #     return add_variable_node!(model, context, name)
    # end
    # return context[edge]

function ensure_markov_blanket_exists!(model::MetaGraph, context::Context; interfaces...)
    for (interface_name, variable_id) in interfaces
        if !haskey(context, variable_id)
            add_variable_node!(model, context, variable_id)
        end
    end
end

function ensure_markov_blanket_exists!(model :: MetaGraph, parent_context :: Context, child_context :: Context; interfaces...)
    ensure_markov_blanket_exists!(model, parent_context; interfaces...)
    for (interface_name, variable_id) in interfaces
        if !haskey(child_context, variable_id)
            put!(child_context, interface_name, parent_context[variable_id])
        end
    end
end

function add_edge!(model :: MetaGraph, context :: Context, factor_node_id :: Symbol, variable_node_name :: Symbol, interface_name :: Symbol)
    variable_node_id = context[variable_node_name]
    model[variable_node_id, factor_node_id] = interface_name
end

function make_node!(model :: MetaGraph, ::Atomic, context :: Context, node_name; interfaces...)
    ensure_markov_blanket_exists!(model, context; interfaces...)
    factor_node_id = add_atomic_factor_node!(model, context, node_name)
    for (interface_name, variable_name) in interfaces
        add_edge!(model, context, factor_node_id, variable_name, interface_name)
    end
    return factor_node_id
end

function equality_node end

function equality_block end

NodeType(::typeof(equality_block)) = Composite()

function make_node!(model :: MetaUndirectedGraph, ::Composite, parent_context :: Context, node_name::typeof(equality_block); interfaces...)
    if length(interfaces) == 3
        make_node!(model, parent_context, equality_node; interfaces...)
        return
    end

    @assert length(interfaces) > 3
    context = Context(parent_context, node_name)
    ensure_markov_blanket_exists!(model, parent_context, context; interfaces...)

    interfaces = Tuple(interfaces)

    current_terminal = gensym(:out)
    first_input, _ = interfaces[1]
    second_input, _ = interfaces[2]
    make_node!(model, context, equality_node; in1=first_input, in2=second_input, in3=current_terminal)
    for i in range(3, length(interfaces) - 2)
        new_terminal = gensym(:out)
        current_input, _ = interfaces[i]
        make_node!(model, context, equality_node; in1=current_terminal, in2 = current_input, in3=new_terminal)
        current_terminal = new_terminal
    end
    second_to_last_input, _ = interfaces[length(interfaces)-1]
    last_input, _ = interfaces[length(interfaces)]
    make_node!(model, context, equality_node; in1=current_terminal, in2=second_to_last_input, in3=last_input)

    node_id = gensym(parent_context, node_name)
    put!(parent_context, node_id, context)

end

function make_node!(model :: MetaUndirectedGraph, ::Composite, parent_context :: Context, node_name::typeof(prod); interfaces...)
    context = Context(parent_context, node_name)
    ensure_markov_blanket_exists!(model, parent_context, context; interfaces...)
    
    make_node!(model, context, sum; in1=:in1, in2=:in2, out=:z)
    make_node!(model, context, sum; in1=:z, in2=:in2, out=:out)

    node_id = gensym(parent_context, node_name)
    put!(parent_context, node_id, context)

end

NodeType(::typeof(prod)) = Composite()

function plot_graph(g; name="tmp.png")
    node_labels = [label[2] for label in sort(collect(g.vertex_labels), by = x->x[1])]
    draw(PNG(name, 16cm, 16cm), gplot(g, nodelabel = node_labels))
end

is_variable_node(model :: MetaGraph, vertex :: Int) = model[label_for(model, vertex)][1]

function terminate_at_neighbors!(model::MetaGraph, vertex)
    name = model[label_for(model, vertex)][2]
    label = label_for(model, vertex)
    new_vertices = Dict()
    for neighbor in neighbors(model, vertex)
        new_label = gensym(label)
        model[new_label] = (true, name)
        edge_data = model[label_for(model, vertex),label_for(model, neighbor)]
        model[label_for(model, neighbor), new_label] = edge_data
        new_vertices[new_label] = new_label
        put!(model[], new_label, new_label)
    end
    rem_vertex!(model, vertex)
    return new_vertices
end

function replace_with_edge!(model::MetaGraph, vertex :: Int)
    src, dst = neighbors(model, vertex)
    edge_name = model[label_for(model, vertex)][2]
    model[label_for(model, src), label_for(model, dst)] = Symbol(edge_name)
    return vertex
end

function convert_to_ffg(model :: MetaUndirectedGraph)
    ffg_model = deepcopy(model)
    for vertex in vertices(ffg_model)
        if is_variable_node(ffg_model, vertex)
            if outdegree(ffg_model, vertex) > 2
                interfaces = terminate_at_neighbors!(ffg_model, vertex)
                make_node!(ffg_model, ffg_model[], equality_block; interfaces...)
            end
        end
    end
    to_delete = []
    for (vertex, label) in ffg_model.vertex_labels
        if is_variable_node(ffg_model, vertex)
            replace_with_edge!(ffg_model, vertex)
            push!(to_delete, vertex)
        end
    end
    for vertex in reverse(sort(to_delete))
        rem_vertex!(ffg_model, vertex)
    end
    return ffg_model
end



make_node!(model :: MetaUndirectedGraph, parent_context :: Context, node_name; interfaces...) = make_node!(model :: MetaUndirectedGraph, NodeType(node_name), parent_context :: Context, node_name; interfaces...)
make_node!(model :: MetaUndirectedGraph, node_name; interfaces...) = make_node!(model, model[], node_name; interfaces...)