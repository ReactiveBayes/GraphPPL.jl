using BenchmarkTools
using GraphPPL

function benchmark_graph_engine()
    SUITE = BenchmarkGroup(["graph_creation"])

    # Benchmark how long it takes to create a model structure
    SUITE["create_model"] = @benchmarkable GraphPPL.create_model()

    # Benchmark how long it takes to get the context of a model
    SUITE["getcontext"] = @benchmarkable_withmodel GraphPPL.getcontext(model)

    # Benchmark how long it takes to create a factor node
    SUITE["factor_node_creation"] = benchmark_factor_node_creation()

    # Benchmark how long it takes to get or create a variable node
    # SUITE["variable_node_creation"] = variable_node_creation()

    
    return SUITE
end

# Benchmark how long it takes to create a factor node
function benchmark_factor_node_creation()
    SUITE = BenchmarkGroup()

    for f in (sum,), n in 5:5:25
        SUITE["make_node!", f, n] = @benchmarkable GraphPPL.make_node!(model, ctx, $f, y, (in = x,)) setup=begin 
            model = GraphPPL.create_model()
            ctx = GraphPPL.getcontext(model)
            y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
            foreach(1:$n) do i
                GraphPPL.getorcreate!(model, ctx, :x, i)
            end
            x = GraphPPL.getorcreate!(model, ctx, :x, 1)
        end
    end

    return SUITE
end

function add_n_nodes(n::Int, model, ctx)
    for i in 1:n
        GraphPPL.add_variable_node!(model, ctx, :x, i)
    end
end

function getorcreate_n_nodes(n::Int, model, ctx; asc = true)
    f = asc ? identity : reverse
    for i in f(1:n)
        GraphPPL.getorcreate!(model, ctx, :x, i)
    end
end


function variable_node_creation()
    SUITE = BenchmarkGroup(["node_creation"])
    
    setup = quote 
        model = GraphPPL.create_model()
        ctx = GraphPPL.getcontext(model)
    end

    SUITE["add_variable_node"] = eval(:(@benchmarkable GraphPPL.add_variable_node!(m, c, :x, nothing) setup=$setup))

    for j in 10 .^ range(1, stop=3)
        j = convert(Int, j)
        model = GraphPPL.create_model()
        ctx = GraphPPL.getcontext(model)
        x = GraphPPL.getorcreate!(model, ctx, :x, 1)
        SUITE["add $j variable nodes"] = @benchmarkable add_n_nodes($j, m, c) setup=(m=deepcopy($model);c=deepcopy($ctx)) evals=1
        SUITE["getorcreate $j variable nodes ascending"] = @benchmarkable getorcreate_n_nodes($j, m, c) setup=(m=deepcopy($model);c=deepcopy($ctx)) evals=1
        SUITE["getorcreate $j variable nodes descending"] = @benchmarkable getorcreate_n_nodes($j, m, c; asc=false) setup=(m=deepcopy($model);c=deepcopy($ctx)) evals=1
        getorcreate_n_nodes(j, model, ctx)
        SUITE["getorcreate $j variable nodes that exist"] = @benchmarkable getorcreate_n_nodes($j, m, c) setup=(m=deepcopy($model);c=deepcopy($ctx)) evals=1
        SUITE["get ResizableArray of $j variables from context"] = @benchmarkable getindex($ctx, :x)
        SUITE["get element from ResizableArray of length $j"] = @benchmarkable getindex($x, $j - 1)
    end
    return SUITE
end