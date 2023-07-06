using BenchmarkTools
using GraphPPL

function add_n_nodes(n::Int, model, ctx)
    for i in 1:n
        GraphPPL.add_variable_node!(model, ctx, :x; index=i)
    end
end

function getorcreate_n_nodes(n::Int, model, ctx)
    for i in 1:n
        GraphPPL.getorcreate!(model, ctx, :x, n)
    end
end



function benchmark_graph_engine()
    SUITE = BenchmarkGroup()
    SUITE["create_model"] = @benchmarkable GraphPPL.create_model()

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
        SUITE["getorcreate $j variable nodes"] = @benchmarkable getorcreate_n_nodes($j, m, c) setup=(m=deepcopy($model);c=deepcopy($ctx)) evals=1
    end


    return SUITE
end


