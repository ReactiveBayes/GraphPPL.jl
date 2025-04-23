using BenchmarkTools
using GraphPPL

function benchmark_graph_engine()
    SUITE = BenchmarkGroup(["graph_creation"])

    # Benchmark how long it takes to create a model structure
    SUITE["create_model"] = @benchmarkable GraphPPL.Model(identity, GraphPPL.PluginsCollection(), GraphPPL.DefaultBackend(), nothing) evals = 1

    # Benchmark how long it takes to get the context of a model
    SUITE["getcontext"] = @benchmarkable GraphPPL.getcontext(model) evals = 1 setup = begin
        model = GraphPPL.Model(identity, GraphPPL.PluginsCollection(), GraphPPL.DefaultBackend(), nothing)
    end

    # Benchmark how long it takes to create a factor node
    SUITE["factor_node_creation"] = benchmark_factor_node_creation()

    # Benchmark how long it takes to get or create a variable node
    SUITE["variable_node_creation"] = benchmark_variable_node_creation()

    return SUITE
end

# Benchmark how long it takes to create a factor node
function benchmark_factor_node_creation()
    SUITE = BenchmarkGroup()

    # This SUITE benchmarks how long it takes to create a factor node `$f` with `n` variables as input
    for f in (sum,), n in Int.(exp10.(0:4))
        SUITE["make_node! (n inputs)", f, n] = @benchmarkable GraphPPL.make_node!(model, ctx, $f, y, (in = x,)) evals =
            1 setup = begin
            model = GraphPPL.Model(identity, GraphPPL.PluginsCollection(), GraphPPL.DefaultBackend(), nothing)
            ctx = GraphPPL.getcontext(model)
            y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
            foreach(1:($n)) do i
                GraphPPL.getorcreate!(model, ctx, :x, i)
            end
            x = GraphPPL.getorcreate!(model, ctx, :x, 1)
        end
    end

    # This SUITE benchmarks how long it takes to create `n` factor nodes with the same variable as input
    for f in (sum,), n in Int.(exp10.(0:4))
        SUITE["make_node! (n nodes)", f, n] = @benchmarkable foreach(
            _ -> GraphPPL.make_node!(model, ctx, $f, y, (in = x,)), 1:($n)
        ) evals = 1 setup = begin
            model = GraphPPL.Model(identity, GraphPPL.PluginsCollection(), GraphPPL.DefaultBackend(), nothing)
            ctx = GraphPPL.getcontext(model)
            y = GraphPPL.getorcreate!(model, ctx, :y, nothing)
            x = GraphPPL.getorcreate!(model, ctx, :x, nothing)
        end
    end

    return SUITE
end

function benchmark_variable_node_creation()
    SUITE = BenchmarkGroup()

    # This SUITE benchmarks how long it takes to create a single variable node
    SUITE["getorcreate! (individual)"] = @benchmarkable GraphPPL.getorcreate!(model, ctx, :x, nothing) evals = 1 setup =
        begin
            model = GraphPPL.Model(identity, GraphPPL.PluginsCollection(), GraphPPL.DefaultBackend(), nothing)
            ctx = GraphPPL.getcontext(model)
        end

    # This SUITE benchmarks how long it takes to add `n` individual variable nodes
    for n in Int.(exp10.(0:4))
        SUITE["getorcreate! (n individual)", n] = @benchmarkable foreach(
            _ -> GraphPPL.getorcreate!(model, ctx, :x, nothing), 1:($n)
        ) evals = 1 setup = begin
            model = GraphPPL.Model(identity, GraphPPL.PluginsCollection(), GraphPPL.DefaultBackend(), nothing)
            ctx = GraphPPL.getcontext(model)
        end
    end

    # THIS SUITE benchmarks how long it takes to add vector based bariables of size `n`
    for n in Int.(exp10.(0:4))
        SUITE["getorcreate! (n vector)", n] = @benchmarkable foreach(
            i -> GraphPPL.getorcreate!(model, ctx, :x, i), 1:($n)
        ) evals = 1 setup = begin
            model = GraphPPL.Model(identity, GraphPPL.PluginsCollection(), GraphPPL.DefaultBackend(), nothing)
            ctx = GraphPPL.getcontext(model)
        end
    end

    return SUITE
end