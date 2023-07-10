using BenchmarkTools
using GraphPPL

function benchmark_graph_engine()
    SUITE = BenchmarkGroup(["graph_creation"])
    SUITE["create_model"] = @benchmarkable GraphPPL.create_model()
    SUITE["variable_node_creation"] = variable_node_creation()
    SUITE["factor_node_creation"] = factor_node_creation()
    return SUITE
end


function factor_node_creation()
    SUITE = BenchmarkGroup(["node_creation"])
    model = GraphPPL.create_model()
    ctx = GraphPPL.getcontext(model)
    local x
    for i in 5:5:25
        for j in 1:i
            x = GraphPPL.getorcreate!(model, ctx, :x, j)
        end
        y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
        SUITE["Create factor node with $i edges"] = @benchmarkable GraphPPL.make_node!(m, c, sum, $y, [$x]) setup=(m=$model;c=$ctx) evals=1
    end
    return SUITE
end

function add_n_nodes(n::Int, model, ctx)
    for i in 1:n
        GraphPPL.add_variable_node!(model, ctx, :x; index=i)
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
    model = GraphPPL.create_model()
    ctx = GraphPPL.getcontext(model)
    SUITE["add_variable_node"] = @benchmarkable GraphPPL.add_variable_node!($model, $ctx, :x)

    for j in 10 .^ range(1, stop=3)
        j = convert(Int, j)
        model = GraphPPL.create_model()
        ctx = GraphPPL.getcontext(model)
        x = GraphPPL.ResizableArray(GraphPPL.NodeLabel, Val(1))
        ctx.vector_variables[:x] = x
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