@testitem "IndexedVariable" begin
    import GraphPPL: IndexedVariable, CombinedRange, SplittedRange, getname, index

    # Test 1: Test IndexedVariable
    @test IndexedVariable(:x, nothing) isa IndexedVariable

    # Test 2: Test IndexedVariable equality
    lhs = IndexedVariable(:x, nothing)
    rhs = IndexedVariable(:x, nothing)
    @test lhs == rhs
    @test lhs === rhs
    @test lhs != IndexedVariable(:y, nothing)
    @test lhs !== IndexedVariable(:y, nothing)
    @test getname(IndexedVariable(:x, nothing)) === :x
    @test getname(IndexedVariable(:x, 1)) === :x
    @test getname(IndexedVariable(:y, nothing)) === :y
    @test getname(IndexedVariable(:y, 1)) === :y
    @test index(IndexedVariable(:x, nothing)) === nothing
    @test index(IndexedVariable(:x, 1)) === 1
    @test index(IndexedVariable(:y, nothing)) === nothing
    @test index(IndexedVariable(:y, 1)) === 1
end

@testitem "FunctionalIndex" begin
    import GraphPPL: FunctionalIndex

    collection = [1, 2, 3, 4, 5]

    # Test 1: Test FunctionalIndex{:begin}
    index = FunctionalIndex{:begin}(firstindex)
    @test index(collection) === firstindex(collection)

    # Test 2: Test FunctionalIndex{:end}
    index = FunctionalIndex{:end}(lastindex)
    @test index(collection) === lastindex(collection)

    # Test 3: Test FunctionalIndex{:begin} + 1
    index = FunctionalIndex{:begin}(firstindex) + 1
    @test index(collection) === firstindex(collection) + 1

    # Test 4: Test FunctionalIndex{:end} - 1
    index = FunctionalIndex{:end}(lastindex) - 1
    @test index(collection) === lastindex(collection) - 1

    # Test 5: Test FunctionalIndex equality
    lhs = FunctionalIndex{:begin}(firstindex)
    rhs = FunctionalIndex{:begin}(firstindex)
    @test lhs == rhs
    @test lhs === rhs
    @test lhs != FunctionalIndex{:end}(lastindex)
    @test lhs !== FunctionalIndex{:end}(lastindex)
end

@testitem "model constructor" begin
    import GraphPPL: create_model, Model

    @test typeof(create_model()) <: Model

    @test_throws MethodError Model()
end

@testitem "NodeData constructor" begin
    import GraphPPL: create_model, getcontext, NodeData, FactorNodeProperties, VariableNodeProperties, getproperties

    model = create_model()
    context = getcontext(model)

    @testset "FactorNodeProperties" begin
        properties = FactorNodeProperties(fform = String)
        nodedata = NodeData(context, properties)

        @test getcontext(nodedata) === context
        @test getproperties(nodedata) === properties

        io = IOBuffer()

        show(io, nodedata)

        output = String(take!(io))

        @test !isempty(output)
        @test contains(output, "String") # fform
    end

    @testset "VariableNodeProperties" begin
        properties = VariableNodeProperties(name = :x, index = 1)
        nodedata = NodeData(context, properties)

        @test getcontext(nodedata) === context
        @test getproperties(nodedata) === properties

        io = IOBuffer()

        show(io, nodedata)

        output = String(take!(io))

        @test !isempty(output)
        @test contains(output, "x") # name
        @test contains(output, "1") # index
    end
end

@testitem "NodeData extra properties" begin
    import GraphPPL:
        create_model,
        getcontext,
        NodeData,
        FactorNodeProperties,
        VariableNodeProperties,
        getproperties,
        setextra!,
        getextra,
        hasextra,
        NodeDataExtraKey

    model = create_model()
    context = getcontext(model)

    @testset for properties in (FactorNodeProperties(fform = String), VariableNodeProperties(name = :x, index = 1))
        nodedata = NodeData(context, properties)

        @test !hasextra(nodedata, :a)
        setextra!(nodedata, :a, 1)
        @test hasextra(nodedata, :a)
        @test getextra(nodedata, :a) === 1

        # In the current implementation it is not possible to update extra properties
        @test_throws Exception setextra!(nodedata, :a, 2)

        @test !hasextra(nodedata, :b)
        setextra!(nodedata, :b, 2)
        @test hasextra(nodedata, :b)
        @test getextra(nodedata, :b) === 2

        constkey_c_float = NodeDataExtraKey{:c, Float64}()

        @test !@inferred(hasextra(nodedata, constkey_c_float))
        @inferred(setextra!(nodedata, constkey_c_float, 3.0))
        @test @inferred(hasextra(nodedata, constkey_c_float))
        @test @inferred(getextra(nodedata, constkey_c_float)) === 3.0

        constkey_d_int = NodeDataExtraKey{:d, Int64}()

        @test !@inferred(hasextra(nodedata, constkey_d_int))
        @inferred(setextra!(nodedata, constkey_d_int, 4))
        @test @inferred(hasextra(nodedata, constkey_d_int))
        @test @inferred(getextra(nodedata, constkey_d_int)) === 4
    end
end

@testitem "factor_nodes" begin
    import GraphPPL: factor_nodes, is_factor, labels
    include("model_zoo.jl")

    for model_name in [simple_model, vector_model, tensor_model, outer, multidim_array]
        model = create_terminated_model(model_name)
        fnodes = collect(factor_nodes(model))
        for node in fnodes
            @test is_factor(model[node])
        end
        for label in labels(model)
            if is_factor(model[label])
                @test label ∈ fnodes
            end
        end
    end
end

@testitem "factor_nodes with lambda function" begin
    import GraphPPL: factor_nodes, is_factor, labels

    include("model_zoo.jl")

    for model_name in [simple_model, vector_model, tensor_model, outer, multidim_array]
        model = create_terminated_model(model_name)
        fnodes = collect(factor_nodes(model))
        factor_nodes(model) do label, nodedata
            @test is_factor(model[label])
            @test is_factor(nodedata)
            @test model[label] === nodedata
            @test label ∈ labels(model)
            @test label ∈ fnodes

            clength = length(fnodes)
            filter!(n -> n !== label, fnodes)
            @test length(fnodes) === clength - 1 # Only one should be removed
        end
        @test length(fnodes) === 0 # all should be processed
    end
end

@testitem "variable_nodes" begin
    import GraphPPL: variable_nodes, is_variable, labels
    include("model_zoo.jl")

    for model_name in [simple_model, vector_model, tensor_model, outer, multidim_array]
        model = create_terminated_model(model_name)
        fnodes = collect(variable_nodes(model))
        for node in fnodes
            @test is_variable(model[node])
        end
        for label in labels(model)
            if is_variable(model[label])
                @test label ∈ fnodes
            end
        end
    end
end

@testitem "variable_nodes with lambda function" begin
    import GraphPPL: variable_nodes, is_variable, labels

    include("model_zoo.jl")

    for model_name in [simple_model, vector_model, tensor_model, outer, multidim_array]
        model = create_terminated_model(model_name)
        fnodes = collect(variable_nodes(model))
        variable_nodes(model) do label, nodedata
            @test is_variable(model[label])
            @test is_variable(nodedata)
            @test model[label] === nodedata
            @test label ∈ labels(model)
            @test label ∈ fnodes

            clength = length(fnodes)
            filter!(n -> n !== label, fnodes)
            @test length(fnodes) === clength - 1 # Only one should be removed
        end
        @test length(fnodes) === 0 # all should be processed
    end
end

@testitem "variable_nodes with anonymous variables" begin
    # The idea here is that the `variable_nodes` must return ALL anonymous variables as well

    using Distributions
    import GraphPPL: create_model, variable_nodes, getname

    @model function simple_submodel_with_2_anonymous_for_variable_nodes(z, x, y)
        # Creates two anonymous variables here
        z ~ Normal(x + 1, y - 1)
    end

    @model function simple_submodel_with_3_anonymous_for_variable_nodes(z, x, y)
        # Creates three anonymous variables here
        z ~ Normal(x + 1, y - 1 + 1)
    end

    @model function simple_model_for_variable_nodes(submodel)
        x ~ Normal(0, 1)
        y ~ Gamma(1, 1)
        z ~ submodel(x = x, y = y)
    end

    @testset let submodel = simple_submodel_with_2_anonymous_for_variable_nodes
        model = create_model(simple_model_for_variable_nodes(submodel = submodel))
        @test length(collect(variable_nodes(model))) === 11
        @test length(collect(filter(v -> getname(v) === :anonymous, collect(variable_nodes(model))))) === 2
    end

    @testset let submodel = simple_submodel_with_3_anonymous_for_variable_nodes
        model = create_model(simple_model_for_variable_nodes(submodel = submodel))
        @test length(collect(variable_nodes(model))) === 13 # +1 for new anonymous +1 for new constant
        @test length(collect(filter(v -> getname(v) === :anonymous, collect(variable_nodes(model))))) === 3
    end
end

@testitem "degree" begin
    import GraphPPL: create_model, getcontext, getorcreate!, NodeCreationOptions, make_node!, degree

    for n in 5:10
        model = create_model()
        ctx = getcontext(model)

        unused = getorcreate!(model, ctx, :unusued, nothing)
        x = getorcreate!(model, ctx, :x, nothing)
        y = getorcreate!(model, ctx, :y, nothing)

        foreach(1:n) do k
            getorcreate!(model, ctx, :z, k)
        end

        z = getorcreate!(model, ctx, :z, 1)

        @test degree(model, unused) === 0
        @test degree(model, x) === 0
        @test degree(model, y) === 0
        @test all(zᵢ -> degree(model, zᵢ) === 0, z)

        for i in 1:n
            make_node!(model, ctx, NodeCreationOptions(), sum, y, (in = [x, z[i]],))
        end

        @test degree(model, unused) === 0
        @test degree(model, x) === n
        @test degree(model, y) === n
        @test all(zᵢ -> degree(model, zᵢ) === 1, z)
    end
end

@testitem "is_constant" begin
    import GraphPPL: is_constant, variable_nodes, getname, getproperties
    include("model_zoo.jl")
    for model_name in [simple_model, vector_model, tensor_model, outer, multidim_array]
        model = create_terminated_model(model_name)
        for label in variable_nodes(model)
            node = model[label]
            props = getproperties(node)
            if occursin("constvar", string(getname(props)))
                @test is_constant(props)
            else
                @test !is_constant(props)
            end
        end
    end
end

@testitem "is_data" begin
    import GraphPPL: is_data, create_model, getcontext, getorcreate!, variable_nodes, NodeCreationOptions, getproperties
    include("model_zoo.jl")

    m = create_model()
    ctx = getcontext(m)
    x = getorcreate!(m, ctx, NodeCreationOptions(kind = :data), :x, nothing)
    @test is_data(getproperties(m[x]))

    for model_name in [simple_model, vector_model, tensor_model, outer, multidim_array]
        model = create_terminated_model(model_name)
        for label in variable_nodes(model)
            @test !is_data(getproperties(model[label]))
        end
    end
end

@testitem "NodeCreationOptions" begin
    import GraphPPL: NodeCreationOptions, withopts, withoutopts

    @test NodeCreationOptions() == NodeCreationOptions()
    @test keys(NodeCreationOptions()) === ()
    @test NodeCreationOptions(arbitrary_option = 1) == NodeCreationOptions((; arbitrary_option = 1))

    @test haskey(NodeCreationOptions(arbitrary_option = 1), :arbitrary_option)
    @test NodeCreationOptions(arbitrary_option = 1)[:arbitrary_option] === 1

    @test @inferred(haskey(NodeCreationOptions(), :a)) === false
    @test @inferred(haskey(NodeCreationOptions(), :b)) === false
    @test @inferred(haskey(NodeCreationOptions(a = 1, b = 2), :b)) === true
    @test @inferred(haskey(NodeCreationOptions(a = 1, b = 2), :c)) === false
    @test @inferred(NodeCreationOptions(a = 1, b = 2)[:a]) === 1
    @test @inferred(NodeCreationOptions(a = 1, b = 2)[:b]) === 2

    @test_throws ErrorException NodeCreationOptions()[:a]
    @test_throws ErrorException NodeCreationOptions(a = 1, b = 2)[:c]

    @test @inferred(get(NodeCreationOptions(), :a, 2)) === 2
    @test @inferred(get(NodeCreationOptions(), :b, 3)) === 3
    @test @inferred(get(NodeCreationOptions(), :c, 4)) === 4
    @test @inferred(get(NodeCreationOptions(a = 1, b = 2), :a, 2)) === 1
    @test @inferred(get(NodeCreationOptions(a = 1, b = 2), :b, 3)) === 2
    @test @inferred(get(NodeCreationOptions(a = 1, b = 2), :c, 4)) === 4

    @test NodeCreationOptions(a = 1, b = 2)[(:a,)] === NodeCreationOptions(a = 1)
    @test NodeCreationOptions(a = 1, b = 2)[(:b,)] === NodeCreationOptions(b = 2)

    @test keys(NodeCreationOptions(a = 1, b = 2)) == (:a, :b)

    @test @inferred(withopts(NodeCreationOptions(), (a = 1,))) == NodeCreationOptions(a = 1)
    @test @inferred(withopts(NodeCreationOptions(b = 2), (a = 1,))) == NodeCreationOptions(b = 2, a = 1)

    @test @inferred(withoutopts(NodeCreationOptions(), Val((:a,)))) == NodeCreationOptions()
    @test @inferred(withoutopts(NodeCreationOptions(b = 1), Val((:a,)))) == NodeCreationOptions(b = 1)
    @test @inferred(withoutopts(NodeCreationOptions(a = 1), Val((:a,)))) == NodeCreationOptions()
    @test @inferred(withoutopts(NodeCreationOptions(a = 1, b = 2), Val((:c,)))) == NodeCreationOptions(a = 1, b = 2)
end

@testitem "Check that factor node plugins are uniquely recreated" begin
    import GraphPPL: getplugins, factor_nodes, PluginsCollection, setextra!, getextra

    include("model_zoo.jl")

    struct AnArbitraryPluginForTestUniqeness end

    GraphPPL.plugin_type(::AnArbitraryPluginForTestUniqeness) = GraphPPL.FactorNodePlugin()

    count = Ref(0)

    function GraphPPL.preprocess_plugin(::AnArbitraryPluginForTestUniqeness, model, context, label, nodedata, options)
        setextra!(nodedata, :count, count[])
        count[] = count[] + 1
        return label, nodedata
    end

    for model_name in [simple_model, vector_model, tensor_model, outer, multidim_array]
        model = create_terminated_model(model_name; plugins = PluginsCollection(AnArbitraryPluginForTestUniqeness()))
        for f1 in factor_nodes(model), f2 in factor_nodes(model)
            if f1 !== f2
                @test getextra(model[f1], :count) !== getextra(model[f2], :count)
            else
                @test getextra(model[f1], :count) === getextra(model[f2], :count)
            end
        end
    end
end

@testitem "Check that plugins may change the options" begin
    import GraphPPL:
        NodeData,
        variable_nodes,
        getname,
        index,
        is_constant,
        getproperties,
        value,
        PluginsCollection,
        VariableNodeProperties,
        NodeCreationOptions,
        create_terminated_model

    include("model_zoo.jl")

    struct AnArbitraryPluginForChangingOptions end

    GraphPPL.plugin_type(::AnArbitraryPluginForChangingOptions) = GraphPPL.VariableNodePlugin()

    function GraphPPL.preprocess_plugin(::AnArbitraryPluginForChangingOptions, model, context, label, nodedata, options)
        # Here we replace the original options entirely
        return label, NodeData(context, convert(VariableNodeProperties, :x, nothing, NodeCreationOptions(kind = :constant, value = 1.0)))
    end

    for model_name in [simple_model, vector_model, tensor_model, outer, multidim_array]
        model = create_terminated_model(model_name; plugins = PluginsCollection(AnArbitraryPluginForChangingOptions()))
        for v in variable_nodes(model)
            @test getname(getproperties(model[v])) === :x
            @test index(getproperties(model[v])) === nothing
            @test is_constant(getproperties(model[v])) === true
            @test value(getproperties(model[v])) === 1.0
        end
    end
end

@testitem "proxy labels" begin
    import GraphPPL: NodeLabel, ProxyLabel, getname, unroll, ResizableArray, FunctionalIndex
    y = NodeLabel(:y, 1)

    let p = ProxyLabel(:x, nothing, y)
        @test last(p) === y
        @test getname(p) === :x
        @test getname(last(p)) === :y
    end

    let p = ProxyLabel(:x, (1,), y)
        @test_throws "Indexing a single node label `y` with an index `[1]` is not allowed" unroll(p)
    end

    let p = ProxyLabel(:x, (1, 2), y)
        @test_throws "Indexing a single node label `y` with an index `[1, 2]` is not allowed" unroll(p)
    end

    let p = ProxyLabel(:r, nothing, ProxyLabel(:x, nothing, y))
        @test last(p) === y
        @test getname(p) === :r
        @test getname(last(p)) === :y
    end

    for n in (5, 10)
        s = ResizableArray(NodeLabel, Val(1))

        for i in 1:n
            s[i] = NodeLabel(:s, i)
        end

        let p = ProxyLabel(:x, nothing, s)
            @test last(p) === s
            @test all(i -> p[i] === s[i], 1:length(s))
            @test unroll(p) === s
        end

        for i in 1:5
            let p = ProxyLabel(:r, nothing, ProxyLabel(:x, (i,), s))
                @test unroll(p) === s[i]
            end
        end

        let p = ProxyLabel(:r, (2,), ProxyLabel(:x, (2:4,), s))
            @test unroll(p) === s[3]
        end
        let p = ProxyLabel(:x, (2:4,), s)
            @test p[1] === s[2]
        end
    end

    for n in (5, 10)
        s = ResizableArray(NodeLabel, Val(1))

        for i in 1:n
            s[i] = NodeLabel(:s, i)
        end

        let p = ProxyLabel(:x, FunctionalIndex{:begin}(firstindex), s)
            @test unroll(p) === s[begin]
        end
    end
end

@testitem "NodeLabel properties" begin
    import GraphPPL: NodeLabel

    x = NodeLabel(:x, 1)
    @test x[1] == x
    @test length(x) === 1
    @test GraphPPL.to_symbol(x) === :x_1

    y = NodeLabel(:y, 2)
    @test x < y
end

@testitem "getname(::NodeLabel)" begin
    import GraphPPL: ResizableArray, NodeLabel, getname

    x = NodeLabel(:x, 1)
    @test getname(x) == :x

    x = ResizableArray(NodeLabel, Val(1))
    x[1] = NodeLabel(:x, 1)
    @test getname(x) == :x

    x = ResizableArray(NodeLabel, Val(1))
    x[2] = NodeLabel(:x, 1)
    @test getname(x) == :x
end

@testitem "setindex!(::Model, ::NodeData, ::NodeLabel)" begin
    using Graphs
    import GraphPPL: create_model, getcontext, NodeLabel, NodeData, VariableNodeProperties, FactorNodeProperties, PluginCollection

    model = create_model()
    ctx = getcontext(model)
    model[NodeLabel(:μ, 1)] = NodeData(ctx, VariableNodeProperties(name = :μ, index = nothing))
    @test nv(model) == 1 && ne(model) == 0

    model[NodeLabel(:x, 2)] = NodeData(ctx, VariableNodeProperties(name = :x, index = nothing))
    @test nv(model) == 2 && ne(model) == 0

    model[NodeLabel(sum, 3)] = NodeData(ctx, FactorNodeProperties(fform = sum))
    @test nv(model) == 3 && ne(model) == 0

    @test_throws MethodError model[0] = 1
    @test_throws MethodError model["string"] = NodeData(ctx, VariableNodeProperties(name = :x, index = nothing))
    @test_throws MethodError model["string"] = NodeData(ctx, FactorNodeProperties(fform = sum))
end

@testitem "setindex!(::Model, ::EdgeLabel, ::NodeLabel, ::NodeLabel)" begin
    using Graphs
    import GraphPPL: create_model, getcontext, NodeLabel, NodeData, VariableNodeProperties, EdgeLabel

    model = create_model()
    ctx = getcontext(model)

    μ = NodeLabel(:μ, 1)
    x = NodeLabel(:x, 2)

    model[μ] = NodeData(ctx, VariableNodeProperties(name = :μ, index = nothing))
    model[x] = NodeData(ctx, VariableNodeProperties(name = :x, index = nothing))
    model[μ, x] = EdgeLabel(:interface, 1)

    @test ne(model) == 1
    @test_throws MethodError model[0, 1] = 1

    # Test that we can't add an edge between two nodes that don't exist
    model[μ, NodeLabel(:x, 100)] = EdgeLabel(:if, 1)
    @test ne(model) == 1
end

@testitem "setindex!(::Context, ::ResizableArray{NodeLabel}, ::Symbol)" begin
    import GraphPPL: NodeLabel, ResizableArray, Context, vector_variables, tensor_variables

    context = Context()
    context[:x] = ResizableArray(NodeLabel, Val(1))
    @test haskey(vector_variables(context), :x)

    context[:y] = ResizableArray(NodeLabel, Val(2))
    @test haskey(tensor_variables(context), :y)
end

@testitem "getindex(::Model, ::NodeLabel)" begin
    import GraphPPL: create_model, getcontext, NodeLabel, NodeData, VariableNodeProperties, getproperties

    model = create_model()
    ctx = getcontext(model)
    label = NodeLabel(:x, 1)
    model[label] = NodeData(ctx, VariableNodeProperties(name = :x, index = nothing))
    @test isa(model[label], NodeData)
    @test isa(getproperties(model[label]), VariableNodeProperties)
    @test_throws KeyError model[NodeLabel(:x, 10)]
    @test_throws MethodError model[0]
end

@testitem "increase_count(::Model)" begin
    import GraphPPL: create_model, increase_count
    model = create_model()

    increase_count(model)

    @test model.counter == 1
    increase_count(model)
    @test model.counter == 2
end

@testitem "nv_ne(::Model)" begin
    import GraphPPL: create_model, getcontext, nv, ne, NodeData, VariableNodeProperties, NodeLabel, EdgeLabel

    model = create_model()
    ctx = getcontext(model)
    @test isempty(model)
    @test nv(model) == 0
    @test ne(model) == 0

    model[NodeLabel(:a, 1)] = NodeData(ctx, VariableNodeProperties(name = :a, index = nothing))
    model[NodeLabel(:b, 2)] = NodeData(ctx, VariableNodeProperties(name = :b, index = nothing))
    @test !isempty(model)
    @test nv(model) == 2
    @test ne(model) == 0

    model[NodeLabel(:a, 1), NodeLabel(:b, 2)] = EdgeLabel(:edge, 1)
    @test !isempty(model)
    @test nv(model) == 2
    @test ne(model) == 1
end

@testitem "edges" begin
    import GraphPPL:
        edges,
        create_model,
        getcontext,
        getproperties,
        NodeData,
        VariableNodeProperties,
        FactorNodeProperties,
        NodeLabel,
        EdgeLabel,
        getname,
        add_edge!,
        getproperties

    # Test 1: Test getting all edges from a model
    model = create_model()
    ctx = getcontext(model)
    a = NodeLabel(:a, 1)
    b = NodeLabel(:b, 2)
    model[a] = NodeData(ctx, VariableNodeProperties(name = :a, index = nothing))
    model[b] = NodeData(ctx, FactorNodeProperties(fform = sum))
    add_edge!(model, b, getproperties(model[b]), a, :edge, 1)
    @test length(edges(model)) == 1

    c = NodeLabel(:c, 2)
    model[c] = NodeData(ctx, FactorNodeProperties(fform = sum))
    add_edge!(model, c, getproperties(model[c]), a, :edge, 2)
    @test length(edges(model)) == 2

    # Test 2: Test getting all edges from a model with a specific node
    @test getname.(edges(model, a)) == [:edge, :edge]
    @test getname.(edges(model, b)) == [:edge]
    @test getname.(edges(model, c)) == [:edge]
    # @test getname.(edges(model, [a, b])) == [:edge, :edge, :edge]
end

@testitem "neighbors(::Model, ::NodeData)" begin
    include("model_zoo.jl")
    import GraphPPL:
        create_model,
        getcontext,
        neighbors,
        NodeData,
        VariableNodeProperties,
        FactorNodeProperties,
        NodeLabel,
        EdgeLabel,
        getname,
        ResizableArray,
        add_edge!,
        getproperties
    model = create_model()
    ctx = getcontext(model)

    a = NodeLabel(:a, 1)
    b = NodeLabel(:b, 2)
    model[a] = NodeData(ctx, FactorNodeProperties(fform = sum))
    model[b] = NodeData(ctx, VariableNodeProperties(name = :b, index = nothing))
    add_edge!(model, a, getproperties(model[a]), b, :edge, 1)
    @test collect(neighbors(model, NodeLabel(:a, 1))) == [NodeLabel(:b, 2)]

    model = create_model()
    ctx = getcontext(model)
    a = ResizableArray(NodeLabel, Val(1))
    b = ResizableArray(NodeLabel, Val(1))
    for i in 1:3
        a[i] = NodeLabel(:a, i)
        model[a[i]] = NodeData(ctx, FactorNodeProperties(fform = sum))
        b[i] = NodeLabel(:b, i)
        model[b[i]] = NodeData(ctx, VariableNodeProperties(name = :b, index = i))
        add_edge!(model, a[i], getproperties(model[a[i]]), b[i], :edge, i)
    end
    for n in b
        @test n ∈ neighbors(model, a)
    end
    # Test 2: Test getting sorted neighbors
    model = create_terminated_model(simple_model)
    ctx = getcontext(model)
    node = first(neighbors(model, ctx[:z])) # Normal node we're investigating is the only neighbor of `z` in the graph.
    @test getname.(neighbors(model, node)) == [:z, :x, :y]

    # Test 3: Test getting sorted neighbors when one of the edge indices is nothing
    model = create_terminated_model(vector_model)
    ctx = getcontext(model)
    node = first(neighbors(model, ctx[:z][1]))
    @test getname.(collect(neighbors(model, node))) == [:z, :x, :y]
end

@testitem "filter(::Predicate, ::Model)" begin
    import GraphPPL: as_node, as_context, as_variable
    include("model_zoo.jl")

    model = create_terminated_model(simple_model)
    result = collect(filter(as_node(Normal) | as_variable(:x), model))
    @test length(result) == 3

    model = create_terminated_model(outer)
    result = collect(filter(as_node(Gamma) & as_context(inner_inner), model))
    @test length(result) == 0

    result = collect(filter(as_node(Gamma) | as_context(inner_inner), model))
    @test length(result) == 6

    result = collect(filter(as_node(Normal) & as_context(inner_inner; children = true), model))
    @test length(result) == 1
end

@testitem "filter(::FactorNodePredicate, ::Model)" begin
    import GraphPPL: as_node, getcontext
    include("model_zoo.jl")

    model = create_terminated_model(simple_model)
    context = getcontext(model)
    result = filter(as_node(Normal), model)
    @test collect(result) == [context[NormalMeanVariance, 1], context[NormalMeanVariance, 2]]
    result = filter(as_node(), model)
    @test collect(result) == [context[NormalMeanVariance, 1], context[GammaShapeScale, 1], context[NormalMeanVariance, 2]]
end

@testitem "filter(::VariableNodePredicate, ::Model)" begin
    import GraphPPL: as_variable, getcontext, variable_nodes
    include("model_zoo.jl")

    model = create_terminated_model(simple_model)
    context = getcontext(model)
    result = filter(as_variable(:x), model)
    @test collect(result) == [context[:x]...]
    result = filter(as_variable(), model)
    @test collect(result) == collect(variable_nodes(model))
end

@testitem "filter(::SubmodelPredicate, Model)" begin
    import GraphPPL: as_context
    include("model_zoo.jl")

    model = create_terminated_model(outer)

    result = filter(as_context(inner), model)
    @test length(collect(result)) == 0

    result = filter(as_context(inner; children = true), model)
    @test length(collect(result)) == 1

    result = filter(as_context(inner_inner), model)
    @test length(collect(result)) == 1

    result = filter(as_context(outer; children = true), model)
    @test length(collect(result)) == 22
end

@testitem "generate_nodelabel(::Model, ::Symbol)" begin
    import GraphPPL: create_model, gensym, NodeLabel, generate_nodelabel

    model = create_model()
    first_sym = generate_nodelabel(model, :x)
    @test typeof(first_sym) == NodeLabel

    second_sym = generate_nodelabel(model, :x)
    @test first_sym != second_sym && first_sym.name == second_sym.name

    id = generate_nodelabel(model, :c)
    @test id.name == :c && id.global_counter == 3
end

@testitem "getname" begin
    import GraphPPL: getname
    @test getname(+) == "+"
    @test getname(-) == "-"
    @test getname(sin) == "sin"
    @test getname(cos) == "cos"
    @test getname(exp) == "exp"
end

@testitem "Context" begin
    import GraphPPL: Context

    ctx1 = Context()
    @test typeof(ctx1) == Context && ctx1.prefix == "" && length(ctx1.individual_variables) == 0 && ctx1.depth == 0

    io = IOBuffer()
    show(io, ctx1)
    output = String(take!(io))
    @test !isempty(output)
    @test contains(output, "identity") # fform

    function test end

    ctx2 = Context(0, test, "test", nothing)
    @test contains(repr(ctx2), "test")
    @test typeof(ctx2) == Context && ctx2.prefix == "test" && length(ctx2.individual_variables) == 0 && ctx2.depth == 0

    function layer end

    ctx3 = Context(ctx2, layer)
    @test typeof(ctx3) == Context && ctx3.prefix == "test_layer" && length(ctx3.individual_variables) == 0 && ctx3.depth == 1

    @test_throws MethodError Context(ctx2, :my_model)

    function secondlayer end

    ctx5 = Context(ctx2, secondlayer)
    @test typeof(ctx5) == Context && ctx5.prefix == "test_secondlayer" && length(ctx5.individual_variables) == 0 && ctx5.depth == 1

    ctx6 = Context(ctx3, secondlayer)
    @test typeof(ctx6) == Context && ctx6.prefix == "test_layer_secondlayer" && length(ctx6.individual_variables) == 0 && ctx6.depth == 2
end

@testitem "haskey(::Context)" begin
    import GraphPPL:
        Context, NodeLabel, ResizableArray, ProxyLabel, individual_variables, vector_variables, tensor_variables, proxies, children

    ctx = Context()
    xlab = NodeLabel(:x, 1)
    @test !haskey(ctx, :x)
    ctx[:x] = xlab
    @test haskey(ctx, :x)
    @test haskey(individual_variables(ctx), :x)
    @test !haskey(vector_variables(ctx), :x)
    @test !haskey(tensor_variables(ctx), :x)
    @test !haskey(proxies(ctx), :x)

    @test !haskey(ctx, :y)
    ctx[:y] = ResizableArray(NodeLabel, Val(1))
    @test haskey(ctx, :y)
    @test !haskey(individual_variables(ctx), :y)
    @test haskey(vector_variables(ctx), :y)
    @test !haskey(tensor_variables(ctx), :y)
    @test !haskey(proxies(ctx), :y)

    @test !haskey(ctx, :z)
    ctx[:z] = ResizableArray(NodeLabel, Val(2))
    @test haskey(ctx, :z)
    @test !haskey(individual_variables(ctx), :z)
    @test !haskey(vector_variables(ctx), :z)
    @test haskey(tensor_variables(ctx), :z)
    @test !haskey(proxies(ctx), :z)

    @test !haskey(ctx, :proxy)
    ctx[:proxy] = ProxyLabel(:proxy, nothing, xlab)
    @test !haskey(individual_variables(ctx), :proxy)
    @test !haskey(vector_variables(ctx), :proxy)
    @test !haskey(tensor_variables(ctx), :proxy)
    @test haskey(proxies(ctx), :proxy)

    @test !haskey(ctx, GraphPPL.FactorID(sum, 1))
    ctx[GraphPPL.FactorID(sum, 1)] = Context()
    @test haskey(ctx, GraphPPL.FactorID(sum, 1))
    @test haskey(children(ctx), GraphPPL.FactorID(sum, 1))
end

@testitem "getindex(::Context, ::Symbol)" begin
    import GraphPPL: Context, NodeLabel

    ctx = Context()
    xlab = NodeLabel(:x, 1)
    @test_throws KeyError ctx[:x]
    ctx[:x] = xlab
    @test ctx[:x] == xlab
end

@testitem "getindex(::Context, ::FactorID)" begin
    import GraphPPL: Context, NodeLabel, FactorID

    ctx = Context()
    @test_throws KeyError ctx[FactorID(sum, 1)]
    ctx[FactorID(sum, 1)] = Context()
    @test ctx[FactorID(sum, 1)] == ctx.children[FactorID(sum, 1)]

    @test_throws KeyError ctx[FactorID(sum, 2)]
    ctx[FactorID(sum, 2)] = NodeLabel(:sum, 1)
    @test ctx[FactorID(sum, 2)] == ctx.factor_nodes[FactorID(sum, 2)]
end

@testitem "getcontext(::Model)" begin
    import GraphPPL: Context, getcontext, create_model, add_variable_node!, NodeCreationOptions

    model = create_model()
    @test getcontext(model) == model.graph[]
    add_variable_node!(model, getcontext(model), NodeCreationOptions(), :x, nothing)
    @test getcontext(model)[:x] == model.graph[][:x]
end

@testitem "path_to_root(::Context)" begin
    import GraphPPL: Context, path_to_root, getcontext
    include("model_zoo.jl")

    ctx = Context()
    @test path_to_root(ctx) == [ctx]

    model = create_terminated_model(outer)
    ctx = getcontext(model)
    inner_context = ctx[inner, 1]
    inner_inner_context = inner_context[inner_inner, 1]
    @test path_to_root(inner_inner_context) == [inner_inner_context, inner_context, ctx]
end

@testitem "VarDict" begin
    using GraphPPL
    import GraphPPL: Context, VarDict

    ctx = Context()
    vardict = VarDict(ctx)
    @test isa(vardict, VarDict)

    using Distributions

    import GraphPPL: create_model, getorcreate!, LazyIndex, NodeCreationOptions, getcontext, is_random, is_data, getproperties

    @model function submodel(y, x_prev, x_next)
        γ ~ Gamma(1, 1)
        x_next ~ Normal(x_prev, γ)
        y ~ Normal(x_next, 1)
    end

    @model function state_space_model_with_new(y)
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], 1)
        for i in 2:length(y)
            # `x[i]` is not defined here, so this should fail
            y[i] ~ submodel(x_next = new(x[i]), x_prev = x[i - 1])
        end
    end

    ydata = ones(10)
    model = create_model(state_space_model_with_new()) do model, ctx
        y = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :y, LazyIndex(ydata))
        return (y = y,)
    end

    context = getcontext(model)
    vardict = VarDict(context)

    @test haskey(vardict, :y)
    @test haskey(vardict, :x)
    for i in 1:(length(ydata) - 1)
        @test haskey(vardict, (submodel, i))
        @test haskey(vardict[submodel, i], :γ)
    end

    @test vardict[:y] === context[:y]
    @test vardict[:x] === context[:x]
    @test vardict[submodel, 1] == VarDict(context[submodel, 1])

    result = map(identity, vardict)
    @test haskey(result, :y)
    @test haskey(result, :x)
    for i in 1:(length(ydata) - 1)
        @test haskey(result, (submodel, i))
        @test haskey(result[submodel, i], :γ)
    end

    result = map(vardict) do variable
        return length(variable)
    end
    @test haskey(result, :y)
    @test haskey(result, :x)
    @test result[:y] === length(ydata)
    @test result[:x] === length(ydata)
    for i in 1:(length(ydata) - 1)
        @test result[(submodel, i)][:γ] === 1
        @test result[GraphPPL.FactorID(submodel, i)][:γ] === 1
        @test result[submodel, i][:γ] === 1
    end

    # Filter only random variables
    result = filter(vardict) do label
        if label isa GraphPPL.ResizableArray
            all(is_random.(getproperties.(model[label])))
        else
            return is_random(getproperties(model[label]))
        end
    end
    @test !haskey(result, :y)
    @test haskey(result, :x)
    for i in 1:(length(ydata) - 1)
        @test haskey(result, (submodel, i))
        @test haskey(result[submodel, i], :γ)
    end

    # Filter only data variables
    result = filter(vardict) do label
        if label isa GraphPPL.ResizableArray
            all(is_data.(getproperties.(model[label])))
        else
            return is_data(getproperties(model[label]))
        end
    end
    @test haskey(result, :y)
    @test !haskey(result, :x)
    for i in 1:(length(ydata) - 1)
        @test haskey(result, (submodel, i))
        @test !haskey(result[submodel, i], :γ)
    end
end

@testitem "NodeType" begin
    include("model_zoo.jl")
    import GraphPPL: NodeType, Composite, Atomic
    @test NodeType(Composite) == Atomic()
    @test NodeType(Atomic) == Atomic()
    @test NodeType(abs) == Atomic()
    @test NodeType(gcv) === Composite()
end

@testitem "create_model()" begin
    import GraphPPL: create_model, Model, nv, ne

    model = create_model()
    @test typeof(model) <: Model && nv(model) == 0 && ne(model) == 0

    @test_throws MethodError create_model(:x, :y, :z)
end

@testitem "copy_markov_blanket_to_child_context" begin
    import GraphPPL:
        create_model, copy_markov_blanket_to_child_context, Context, getorcreate!, ProxyLabel, unroll, getcontext, NodeCreationOptions

    # Test 1: Copy individual variables
    model = create_model()
    ctx = getcontext(model)
    function child end
    child_context = Context(ctx, child)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    y = getorcreate!(model, ctx, NodeCreationOptions(), :y, nothing)
    z = getorcreate!(model, ctx, NodeCreationOptions(), :z, nothing)
    copy_markov_blanket_to_child_context(child_context, (in1 = x, in2 = y, out = z))
    @test child_context[:in1] === x

    # Test 2: Copy vector variables
    model = create_model()
    ctx = getcontext(model)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, 1)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, 2)
    child_context = Context(ctx, child)
    copy_markov_blanket_to_child_context(child_context, (in = x,))
    @test child_context[:in] === x

    # Test 3: Copy tensor variables
    model = create_model()
    ctx = getcontext(model)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, 1, 1)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, 2, 1)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, 1, 2)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, 2, 2)
    child_context = Context(ctx, child)
    copy_markov_blanket_to_child_context(child_context, (in = x,))
    @test child_context[:in] === x

    # Test 4: Do not copy constant variables
    model = create_model()
    ctx = getcontext(model)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    child_context = Context(ctx, child)
    copy_markov_blanket_to_child_context(child_context, (in = 1,))
    @test !haskey(child_context, :in)

    # Test 5: Do not copy vector valued constant variables
    model = create_model()
    ctx = getcontext(model)
    child_context = Context(ctx, child)
    copy_markov_blanket_to_child_context(child_context, (in = [1, 2, 3],))
    @test !haskey(child_context, :in)

    # Test 6: Copy ProxyLabel variables to child context
    model = create_model()
    ctx = getcontext(model)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    x = ProxyLabel(:x, nothing, x)
    child_context = Context(ctx, child)
    copy_markov_blanket_to_child_context(child_context, (in = x,))
    @test child_context[:in] == x
end

@testitem "check_variate_compatability" begin
    import GraphPPL: check_variate_compatability, NodeLabel, ResizableArray

    # Test 1: Check that a one dimensional variable is compatable with a symbol
    x = NodeLabel(:x, 1)
    @test check_variate_compatability(x, nothing)

    # Test 2: Check that an assigned vector variable returns the vector itself when called
    x = ResizableArray(NodeLabel, Val(1))
    x[1] = NodeLabel(:x, 1)
    @test check_variate_compatability(x, 1)

    #Test 3: Check that if it is not assigned, it is false
    @test !check_variate_compatability(x, 2)

    #Test 4: Check that if we overindex the array, it crashes
    @test_throws ErrorException check_variate_compatability(x, 1, 1)

    #Test 5: Check that if we underindex the array, it crashes
    x = ResizableArray(NodeLabel, Val(2))
    x[1, 1] = NodeLabel(:x, 1)
    @test_throws ErrorException check_variate_compatability(x, 1)

    #Test 6: Check that if we call an individual variable with an index, we return false
    x = NodeLabel(:x, 1)
    @test_throws ErrorException !check_variate_compatability(x, 1)

    #Test 7: Check that if we call a vector variable without an index, we return false
    x = ResizableArray(NodeLabel, Val(1))
    x[1] = NodeLabel(:x, 1)
    @test_throws ErrorException !check_variate_compatability(x, nothing)
end

@testitem "getorcreate!" begin
    using Graphs
    import GraphPPL:
        create_model,
        getcontext,
        getorcreate!,
        check_variate_compatability,
        NodeLabel,
        ResizableArray,
        NodeCreationOptions,
        getproperties,
        is_kind

    let # let block to suppress the scoping warnings
        # Test 1: Creation of regular one-dimensional variable
        model = create_model()
        ctx = getcontext(model)
        x = if !@isdefined(x)
            getorcreate!(model, ctx, :x, nothing)
        else
            (check_variate_compatability(x, :x) ? x : getorcreate!(model, ctx, :x, nothing))
        end
        @test nv(model) == 1 && ne(model) == 0

        # Test 2: Ensure that getorcreating this variable again does not create a new node
        x2 = if !@isdefined(x2)
            getorcreate!(model, ctx, :x, nothing)
        else
            (check_variate_compatability(x2, :x) ? x2 : getorcreate!(model, ctx, :x, nothing))
        end
        @test x == x2 && nv(model) == 1 && ne(model) == 0

        # Test 3: Ensure that calling x another time gives us x
        x = if !@isdefined(x)
            getorcreate!(model, ctx, :x, nothing)
        else
            (check_variate_compatability(x, nothing) ? x : getorcreate!(model, ctx, :x, nothing))
        end
        @test x == x2 && nv(model) == 1 && ne(model) == 0

        # Test 4: Test that creating a vector variable creates an array of the correct size
        model = create_model()
        ctx = getcontext(model)
        y = !@isdefined(y) ? getorcreate!(model, ctx, :y, 1) : (check_variate_compatability(y, 1) ? y : getorcreate!(model, ctx, :y, 1))
        @test nv(model) == 1 && ne(model) == 0 && y isa ResizableArray && y[1] isa NodeLabel

        # Test 5: Test that recreating the same variable changes nothing
        y2 = !@isdefined(y2) ? getorcreate!(model, ctx, :y, 1) : (check_variate_compatability(y2, 1) ? y : getorcreate!(model, ctx, :y, 1))
        @test y == y2 && nv(model) == 1 && ne(model) == 0

        # Test 6: Test that adding a variable to this vector variable increases the size of the array
        y = !@isdefined(y) ? getorcreate!(model, ctx, :y, 2) : (check_variate_compatability(y, 2) ? y : getorcreate!(model, ctx, :y, 2))
        @test nv(model) == 2 && y[2] isa NodeLabel && haskey(ctx.vector_variables, :y)

        # Test 7: Test that getting this variable without index does not work
        @test_throws ErrorException y = if !@isdefined(y)
            getorcreate!(model, ctx, :y, nothing)
        else
            (check_variate_compatability(y, nothing) ? y : getorcreate!(model, ctx, :y, nothing))
        end

        # Test 8: Test that getting this variable with an index that is too large does not work
        @test_throws ErrorException y = if !@isdefined(y)
            getorcreate!(model, ctx, :y, 1, 2)
        else
            (check_variate_compatability(y, 1, 2) ? y : getorcreate!(model, ctx, :y, 1, 2))
        end

        #Test 9: Test that creating a tensor variable creates a tensor of the correct size
        model = create_model()
        ctx = getcontext(model)
        z = if !@isdefined(z)
            getorcreate!(model, ctx, :z, 1, 1)
        else
            (check_variate_compatability(z, 1, 1) ? z : getorcreate!(model, ctx, :z, 1, 1))
        end
        @test nv(model) == 1 && ne(model) == 0 && z isa ResizableArray && z[1, 1] isa NodeLabel

        #Test 10: Test that recreating the same variable changes nothing
        z2 = if !@isdefined(z2)
            getorcreate!(model, ctx, :z, 1, 1)
        else
            (check_variate_compatability(z2, 1, 1) ? z : getorcreate!(model, ctx, :z, 1, 1))
        end
        @test z == z2 && nv(model) == 1 && ne(model) == 0

        #Test 11: Test that adding a variable to this tensor variable increases the size of the array
        z = if !@isdefined(z)
            getorcreate!(model, ctx, :z, 2, 2)
        else
            (check_variate_compatability(z, 2, 2) ? z : getorcreate!(model, ctx, :z, 2, 2))
        end
        @test nv(model) == 2 && z[2, 2] isa NodeLabel && haskey(ctx.tensor_variables, :z)

        #Test 12: Test that getting this variable without index does not work
        @test_throws ErrorException z = if !@isdefined(z)
            getorcreate!(model, ctx, :z, nothing)
        else
            (check_variate_compatability(z, :z) ? z : getorcreate!(model, ctx, :z, nothing))
        end

        #Test 13: Test that getting this variable with an index that is too small does not work
        @test_throws ErrorException z =
            !@isdefined(z) ? getorcreate!(model, ctx, :z, 1) : (check_variate_compatability(z, 1) ? z : getorcreate!(model, ctx, :z, 1))

        #Test 14: Test that getting this variable with an index that is too large does not work
        @test_throws Union{AssertionError, ErrorException} z = if !@isdefined(z)
            getorcreate!(model, ctx, :z, 1, 2, 3)
        else
            (check_variate_compatability(z, 1, 2, 3) ? z : getorcreate!(model, ctx, :z, 1, 2, 3))
        end

        # Test 15: Test that creating a variable that exists in the model scope but not in local scope still throws an error
        let # force local scope
            model = create_model()
            ctx = getcontext(model)
            if !@isdefined(a)
                getorcreate!(model, ctx, :a, nothing)
            else
                (check_variate_compatability(a, nothing) ? a : getorcreate!(model, ctx, :a, nothing))
            end
            @test_throws ErrorException a = if !@isdefined(a)
                getorcreate!(model, ctx, :a, 1)
            else
                (check_variate_compatability(a, 1) ? a : getorcreate!(model, ctx, :a, 1))
            end
            @test_throws ErrorException a = if !@isdefined(a)
                getorcreate!(model, ctx, :a, 1, 1)
            else
                (check_variate_compatability(a, 1, 1) ? a : getorcreate!(model, ctx, :a, 1, 1))
            end
        end

        # Test 16. Test that the index is required to create a variable in the model
        model = create_model()
        ctx = getcontext(model)
        @test_throws ErrorException getorcreate!(model, ctx, :a)
        @test_throws ErrorException getorcreate!(model, ctx, NodeCreationOptions(), :a)
        @test_throws ErrorException getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a)
        @test_throws ErrorException getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 2), :a)

        # Test 17. Range based getorcreate!
        model = create_model()
        ctx = getcontext(model)
        var = getorcreate!(model, ctx, :a, 1:2)
        @test nv(model) == 2 && var[1] isa NodeLabel && var[2] isa NodeLabel

        # Test 17.1 Range based getorcreate! should use the same options
        model = create_model()
        ctx = getcontext(model)
        var = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, 1:2)
        @test nv(model) == 2 && var[1] isa NodeLabel && var[2] isa NodeLabel
        @test is_kind(getproperties(model[var[1]]), :data)
        @test is_kind(getproperties(model[var[1]]), :data)

        # Test 18. Range x2 based getorcreate!
        model = create_model()
        ctx = getcontext(model)
        var = getorcreate!(model, ctx, :a, 1:2, 1:3)
        @test nv(model) == 6
        for i in 1:2, j in 1:3
            @test var[i, j] isa NodeLabel
        end

        # Test 18. Range x2 based getorcreate! should use the same options
        model = create_model()
        ctx = getcontext(model)
        var = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :a, 1:2, 1:3)
        @test nv(model) == 6
        for i in 1:2, j in 1:3
            @test var[i, j] isa NodeLabel
            @test is_kind(getproperties(model[var[i, j]]), :data)
        end
    end
end

@testitem "getifcreated" begin
    using Graphs
    import GraphPPL:
        create_model,
        getifcreated,
        getorcreate!,
        getcontext,
        getproperties,
        getname,
        value,
        getorcreate!,
        ProxyLabel,
        value,
        NodeCreationOptions
    model = create_model()
    ctx = getcontext(model)

    # Test case 1: check that getifcreated  the variable created by getorcreate
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    @test getifcreated(model, ctx, x) == x

    # Test case 2: check that getifcreated returns the variable created by getorcreate in a vector
    y = getorcreate!(model, ctx, NodeCreationOptions(), :y, 1)
    @test getifcreated(model, ctx, y[1]) == y[1]

    # Test case 3: check that getifcreated returns a new variable node when called with integer input
    c = getifcreated(model, ctx, 1)
    @test value(getproperties(model[c])) == 1

    # Test case 4: check that getifcreated returns a new variable node when called with a vector input
    c = getifcreated(model, ctx, [1, 2])
    @test value(getproperties(model[c])) == [1, 2]

    # Test case 5: check that getifcreated returns a tuple of variable nodes when called with a tuple of NodeData
    output = getifcreated(model, ctx, (x, y[1]))
    @test output == (x, y[1])

    # Test case 6: check that getifcreated returns a tuple of new variable nodes when called with a tuple of integers
    output = getifcreated(model, ctx, (1, 2))
    @test value(getproperties(model[output[1]])) == 1
    @test value(getproperties(model[output[2]])) == 2

    # Test case 7: check that getifcreated returns a tuple of variable nodes when called with a tuple of mixed input
    output = getifcreated(model, ctx, (x, 1))
    @test output[1] == x && value(getproperties(model[output[2]])) == 1

    # Test case 10: check that getifcreated returns the variable node if we create a variable and call it by symbol in a vector
    model = create_model()
    ctx = getcontext(model)
    z = getorcreate!(model, ctx, NodeCreationOptions(), :z, 1)
    z_fetched = getifcreated(model, ctx, z[1])
    @test z_fetched == z[1]

    # Test case 11: Test that getifcreated returns a constant node when we call it with a symbol
    model = create_model()
    ctx = getcontext(model)
    z = getifcreated(model, ctx, :Bernoulli)
    @test value(getproperties(model[z])) == :Bernoulli

    # Test case 12: Test that getifcreated returns a vector of NodeLabels if called with a vector of NodeLabels
    model = create_model()
    ctx = getcontext(model)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    y = getorcreate!(model, ctx, NodeCreationOptions(), :y, nothing)
    z = getifcreated(model, ctx, [x, y])
    @test z == [x, y]

    # Test case 13: Test that getifcreated returns a ResizableArray tensor of NodeLabels if called with a ResizableArray tensor of NodeLabels
    model = create_model()
    ctx = getcontext(model)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, 1, 1)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, 2, 1)
    z = getifcreated(model, ctx, x)
    @test z == x

    # Test case 14: Test that getifcreated returns multiple variables if called with a tuple of constants
    model = create_model()
    ctx = getcontext(model)
    z = getifcreated(model, ctx, ([1, 1], 2))
    @test nv(model) == 2 && value(getproperties(model[z[1]])) == [1, 1] && value(getproperties(model[z[2]])) == 2

    # Test case 15: Test that getifcreated returns a ProxyLabel if called with a ProxyLabel
    model = create_model()
    ctx = getcontext(model)
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    x = ProxyLabel(:x, nothing, x)
    z = getifcreated(model, ctx, x)
    @test z === x
end

@testitem "add_variable_node!" begin
    import GraphPPL:
        create_model,
        add_variable_node!,
        getcontext,
        options,
        NodeLabel,
        ResizableArray,
        nv,
        ne,
        NodeCreationOptions,
        getproperties,
        is_constant,
        value

    # Test 1: simple add variable to model
    model = create_model()
    ctx = getcontext(model)
    node_id = add_variable_node!(model, ctx, NodeCreationOptions(), :x, nothing)
    @test nv(model) == 1 && haskey(ctx.individual_variables, :x) && ctx.individual_variables[:x] == node_id

    # Test 2: Add second variable to model
    add_variable_node!(model, ctx, NodeCreationOptions(), :y, nothing)
    @test nv(model) == 2 && haskey(ctx, :y)

    # Test 3: Check that adding an integer variable throws a MethodError
    @test_throws MethodError add_variable_node!(model, ctx, NodeCreationOptions(), 1)
    @test_throws MethodError add_variable_node!(model, ctx, NodeCreationOptions(), 1, 1)

    # Test 4: Add a vector variable to the model
    model = create_model()
    ctx = getcontext(model)
    ctx[:x] = ResizableArray(NodeLabel, Val(1))
    node_id = add_variable_node!(model, ctx, NodeCreationOptions(), :x, 2)
    @test nv(model) == 1 && haskey(ctx, :x) && ctx[:x][2] == node_id && length(ctx[:x]) == 2

    # Test 5: Add a second vector variable to the model
    node_id = add_variable_node!(model, ctx, NodeCreationOptions(), :x, 1)
    @test nv(model) == 2 && haskey(ctx, :x) && ctx[:x][1] == node_id && length(ctx[:x]) == 2

    # Test 6: Add a tensor variable to the model
    model = create_model()
    ctx = getcontext(model)
    ctx[:x] = ResizableArray(NodeLabel, Val(2))
    node_id = add_variable_node!(model, ctx, NodeCreationOptions(), :x, (2, 3))
    @test nv(model) == 1 && haskey(ctx, :x) && ctx[:x][2, 3] == node_id

    # Test 7: Add a second tensor variable to the model
    node_id = add_variable_node!(model, ctx, NodeCreationOptions(), :x, (2, 4))
    @test nv(model) == 2 && haskey(ctx, :x) && ctx[:x][2, 4] == node_id

    # Test 9: Add a variable with a non-integer index
    model = create_model()
    ctx = getcontext(model)
    ctx[:z] = ResizableArray(NodeLabel, Val(2))
    @test_throws MethodError add_variable_node!(model, ctx, NodeCreationOptions(), :z, "a")
    @test_throws MethodError add_variable_node!(model, ctx, NodeCreationOptions(), :z, ("a", "a"))
    @test_throws MethodError add_variable_node!(model, ctx, NodeCreationOptions(), :z, ("a", 1))
    @test_throws MethodError add_variable_node!(model, ctx, NodeCreationOptions(), :z, (1, "a"))

    # Test 10: Add a variable with a negative index
    ctx[:x] = ResizableArray(NodeLabel, Val(1))
    @test_throws BoundsError add_variable_node!(model, ctx, NodeCreationOptions(), :x, -1)

    # Test 11: Add a variable with options
    model = create_model()
    ctx = getcontext(model)
    var = add_variable_node!(model, ctx, NodeCreationOptions(kind = :constant, value = 1.0), :x, nothing)
    @test nv(model) == 1 &&
        haskey(ctx, :x) &&
        ctx[:x] == var &&
        is_constant(getproperties(model[var])) &&
        value(getproperties(model[var])) == 1.0

    # Test 12: Add a variable without options
    model = create_model()
    ctx = getcontext(model)
    var = add_variable_node!(model, ctx, :x, nothing)
    @test nv(model) == 1 && haskey(ctx, :x) && ctx[:x] == var
end

@testitem "interface_alias" begin
    using GraphPPL
    import GraphPPL: interface_aliases, StaticInterfaces

    include("model_zoo.jl")

    @test interface_aliases(NormalMeanPrecision, StaticInterfaces((:out, :μ, :τ))) === StaticInterfaces((:out, :μ, :τ))
    @test interface_aliases(NormalMeanPrecision, StaticInterfaces((:out, :mean, :precision))) === StaticInterfaces((:out, :μ, :τ))
end

@testitem "add_atomic_factor_node!" begin
    using Distributions
    using Graphs
    import GraphPPL: create_model, add_atomic_factor_node!, getorcreate!, getcontext, getorcreate!, label_for, getname, NodeCreationOptions

    # Test 1: Add an atomic factor node to the model
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, NodeCreationOptions(), :x, nothing)
    node_id, node_data, node_properties = add_atomic_factor_node!(model, ctx, options, sum)
    @test model[node_id] === node_data
    @test nv(model) == 2 && getname(label_for(model.graph, 2)) == sum

    # Test 2: Add a second atomic factor node to the model with the same name and assert they are different
    node_id, node_data, node_properties = add_atomic_factor_node!(model, ctx, options, sum)
    @test model[node_id] === node_data
    @test nv(model) == 3 && getname(label_for(model.graph, 3)) == sum

    # Test 3: Add an atomic factor node with options
    options = NodeCreationOptions((; an_arbitrary_option = true,))
    node_id, node_data, node_properties = add_atomic_factor_node!(model, ctx, options, sum)
    @test model[node_id] === node_data
    @test nv(model) == 4 && getname(label_for(model.graph, 4)) == sum
    @test_broken false # TODO: (bvdmitri) ideally we would like to test that the option affects the creation here

    #Test 4: Make sure alias is added for the `+` node
    options = NodeCreationOptions()
    node_id, node_data, node_properties = add_atomic_factor_node!(model, ctx, options, +)
    @test model[node_id] === node_data
    @test_broken getname(node_id) == sum # TODO: (bvdmitri) check with Wouter

    # Test 5: Test that creating a node with an instantiated object is supported
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    prior = Normal(0, 1)
    node_id, node_data, node_properties = add_atomic_factor_node!(model, ctx, options, prior)
    @test model[node_id] === node_data
    @test nv(model) == 1 && getname(label_for(model.graph, 1)) == Normal(0, 1)
end

@testitem "add_composite_factor_node!" begin
    using Graphs
    import GraphPPL: create_model, add_composite_factor_node!, getcontext, to_symbol, children, add_variable_node!, Context

    # Add a composite factor node to the model
    model = create_model()
    parent_ctx = getcontext(model)
    child_ctx = getcontext(model)
    add_variable_node!(model, child_ctx, :x, nothing)
    add_variable_node!(model, child_ctx, :y, nothing)
    node_id = add_composite_factor_node!(model, parent_ctx, child_ctx, :f)
    @test nv(model) == 2 &&
        haskey(children(parent_ctx), node_id) &&
        children(parent_ctx)[node_id] === child_ctx &&
        length(child_ctx.individual_variables) == 2

    # Add a composite factor node with a different name
    node_id = add_composite_factor_node!(model, parent_ctx, child_ctx, :g)
    @test nv(model) == 2 &&
        haskey(children(parent_ctx), node_id) &&
        children(parent_ctx)[node_id] === child_ctx &&
        length(child_ctx.individual_variables) == 2

    # Add a composite factor node with an empty child context
    empty_ctx = Context()
    node_id = add_composite_factor_node!(model, parent_ctx, empty_ctx, :h)
    @test nv(model) == 2 &&
        haskey(children(parent_ctx), node_id) &&
        children(parent_ctx)[node_id] === empty_ctx &&
        length(empty_ctx.individual_variables) == 0
end

@testitem "add_edge!(::Model, ::NodeLabel, ::NodeLabel, ::Symbol)" begin
    import GraphPPL:
        create_model, getcontext, nv, ne, NodeData, NodeLabel, EdgeLabel, add_edge!, getorcreate!, generate_nodelabel, NodeCreationOptions

    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x, xdata, xproperties = GraphPPL.add_atomic_factor_node!(model, ctx, options, sum)
    y = getorcreate!(model, ctx, :y, nothing)

    add_edge!(model, x, xproperties, y, :interface)

    @test ne(model) == 1

    @test_throws MethodError add_edge!(model, x, xproperties, y, 123)
end

@testitem "add_edge!(::Model, ::NodeLabel, ::Vector{NodeLabel}, ::Symbol)" begin
    import GraphPPL: create_model, getcontext, nv, ne, NodeData, NodeLabel, EdgeLabel, add_edge!, getorcreate!, NodeCreationOptions
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x, xdata, xproperties = GraphPPL.add_atomic_factor_node!(model, ctx, options, sum)
    y = getorcreate!(model, ctx, :y, nothing)

    variable_nodes = [getorcreate!(model, ctx, i, nothing) for i in [:a, :b, :c]]
    add_edge!(model, x, xproperties, variable_nodes, :interface)

    @test ne(model) == 3 && model[x, variable_nodes[1]] == EdgeLabel(:interface, 1)
end

@testitem "default_parametrization" begin
    include("model_zoo.jl")
    import GraphPPL: default_parametrization, Composite, Atomic

    # Test 1: Add default arguments to Normal call
    @test default_parametrization(Atomic(), Normal, (0, 1)) == (μ = 0, σ = 1)

    # Test 2: Add :in to function call that has default behaviour 
    @test default_parametrization(Atomic(), +, (1, 2)) == (in = (1, 2),)

    # Test 3: Add :in to function call that has default behaviour with nested interfaces
    @test default_parametrization(Atomic(), +, ([1, 1], 2)) == (in = ([1, 1], 2),)

    @test_throws ErrorException default_parametrization(Composite(), gcv, (1, 2))
end

@testitem "contains_nodelabel" begin
    import GraphPPL: create_model, getcontext, getorcreate!, contains_nodelabel, NodeCreationOptions, True, False, MixedArguments

    model = create_model()
    ctx = getcontext(model)
    a = getorcreate!(model, ctx, :x, nothing)
    b = getorcreate!(model, ctx, NodeCreationOptions(kind = :data), :x, nothing)
    c = 1.0

    # Test 1. Tuple based input
    @test contains_nodelabel((a, b, c)) === True()
    @test contains_nodelabel((a, b)) === True()
    @test contains_nodelabel((a,)) === True()
    @test contains_nodelabel((b,)) === True()
    @test contains_nodelabel((c,)) === False()

    # Test 2. Named tuple based input
    @test @inferred(contains_nodelabel((; a = a, b = b, c = c))) === True()
    @test @inferred(contains_nodelabel((; a = a, b = b))) === True()
    @test @inferred(contains_nodelabel((; a = a))) === True()
    @test @inferred(contains_nodelabel((; b = b))) === True()
    @test @inferred(contains_nodelabel((; c = c))) === False()

    # Test 3. MixedArguments based input
    @test @inferred(contains_nodelabel(MixedArguments((), (; a = a, b = b, c = c)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((), (; a = a, b = b)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((), (; a = a)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((), (; b = b)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((), (; c = c)))) === False()

    @test @inferred(contains_nodelabel(MixedArguments((a,), (; b = b, c = c)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((c,), (; a = a, b = b)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((b,), (; a = a)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((c,), (; b = b)))) === True()
    @test @inferred(contains_nodelabel(MixedArguments((c,), (;)))) === False()
    @test @inferred(contains_nodelabel(MixedArguments((), (; c = c)))) === False()
end

@testitem "make_node!(::Atomic)" begin
    include("model_zoo.jl")
    using Graphs
    using BitSetTuples
    import GraphPPL:
        getcontext,
        make_node!,
        create_model,
        getorcreate!,
        factorization_constraint,
        ProxyLabel,
        getname,
        label_for,
        edges,
        MixedArguments,
        prune!,
        fform,
        value,
        NodeCreationOptions,
        getproperties
    # Test 1: Deterministic call returns result of deterministic function and does not create new node
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)
    @test make_node!(model, ctx, options, +, x, (1, 1)) == (nothing, 2)
    @test make_node!(model, ctx, options, sin, x, (0,)) == (nothing, 0)
    @test nv(model) == 1

    # Test 2: Stochastic atomic call returns a new node id
    node_id, _ = make_node!(model, ctx, options, Normal, x, (μ = 0, σ = 1))
    @test nv(model) == 4
    @test getname.(edges(model, node_id)) == [:out, :μ, :σ]
    @test getname.(edges(model, node_id)) == [:out, :μ, :σ]

    # Test 3: Stochastic atomic call with an AbstractArray as rhs_interfaces
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)
    make_node!(model, ctx, options, Normal, x, (0, 1))
    @test nv(model) == 4 && ne(model) == 3

    # Test 4: Deterministic atomic call with nodelabels should create the actual node
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    in1 = getorcreate!(model, ctx, :in1, nothing)
    in2 = getorcreate!(model, ctx, :in2, nothing)
    out = getorcreate!(model, ctx, :out, nothing)
    make_node!(model, ctx, options, +, out, (in1, in2))
    @test nv(model) == 4 && ne(model) == 3

    # Test 5: Deterministic atomic call with nodelabels should create the actual node
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    in1 = getorcreate!(model, ctx, :in1, nothing)
    in2 = getorcreate!(model, ctx, :in2, nothing)
    out = getorcreate!(model, ctx, :out, nothing)
    make_node!(model, ctx, options, +, out, (in = [in1, in2],))
    @test nv(model) == 4

    # Test 6: Stochastic node with default arguments
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)
    node_id, _ = make_node!(model, ctx, options, Normal, x, (0, 1))
    @test nv(model) == 4
    @test getname.(edges(model, node_id)) == [:out, :μ, :σ]
    @test getname.(edges(model, node_id)) == [:out, :μ, :σ]

    # Test 7: Stochastic node with instantiated object
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    uprior = Normal(0, 1)
    x = getorcreate!(model, ctx, :x, nothing)
    node_id = make_node!(model, ctx, options, uprior, x, nothing)
    @test nv(model) == 2

    # Test 8: Deterministic node with nodelabel objects where all interfaces are already defined (no missing interfaces)
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    in1 = getorcreate!(model, ctx, :in1, nothing)
    in2 = getorcreate!(model, ctx, :in2, nothing)
    out = getorcreate!(model, ctx, :out, nothing)
    @test_throws AssertionError make_node!(model, ctx, options, +, out, (in = in1, out = in2))

    # Test 8: Stochastic node with nodelabel objects where we have an array on the rhs (so should create 1 node for [0, 1])
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    out = getorcreate!(model, ctx, :out, nothing)
    nodeid, _ = make_node!(model, ctx, options, ArbitraryNode, out, (in = [0, 1],))
    @test nv(model) == 3 && value(getproperties(model[ctx[:constvar_2]])) == [0, 1]

    # Test 9: Stochastic node with all interfaces defined as constants
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    out = getorcreate!(model, ctx, :out, nothing)
    nodeid, _ = make_node!(model, ctx, options, ArbitraryNode, out, (1, 1))
    @test nv(model) == 4
    @test getname.(edges(model, nodeid)) == [:out, :in, :in]
    @test getname.(edges(model, nodeid)) == [:out, :in, :in]

    #Test 10: Deterministic node with keyword arguments
    function abc(; a = 1, b = 2)
        return a + b
    end
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    out = getorcreate!(model, ctx, :out, nothing)
    @test make_node!(model, ctx, options, abc, out, (a = 1, b = 2)) == (nothing, 3)

    # Test 11: Deterministic node with mixed arguments
    function abc(a; b = 2)
        return a + b
    end
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    out = getorcreate!(model, ctx, :out, nothing)
    @test make_node!(model, ctx, options, abc, out, MixedArguments((2,), (b = 2,))) == (nothing, 4)

    # Test 12: Deterministic node with mixed arguments that has to be materialized should throw error
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    out = getorcreate!(model, ctx, :out, nothing)
    a = getorcreate!(model, ctx, :a, nothing)
    @test_throws ErrorException make_node!(model, ctx, options, abc, out, MixedArguments((a,), (b = 2,)))

    # Test 13: Make stochastic node with aliases
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)
    node_id = make_node!(model, ctx, options, Normal, x, (μ = 0, τ = 1))
    @test any((key) -> fform(key) == NormalMeanPrecision, keys(ctx.factor_nodes))
    @test nv(model) == 4

    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)
    node_id = make_node!(model, ctx, options, Normal, x, (μ = 0, σ = 1))
    @test any((key) -> fform(key) == NormalMeanVariance, keys(ctx.factor_nodes))
    @test nv(model) == 4

    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)
    node_id = make_node!(model, ctx, options, Normal, x, (0, 1))
    @test any((key) -> fform(key) == NormalMeanVariance, keys(ctx.factor_nodes))
    @test nv(model) == 4

    # Test 14: Make deterministic node with ProxyLabels as arguments
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)
    x = ProxyLabel(:x, nothing, x)
    y = getorcreate!(model, ctx, :y, nothing)
    y = ProxyLabel(:y, nothing, y)
    z = getorcreate!(model, ctx, :z, nothing)
    node_id = make_node!(model, ctx, options, +, z, (x, y))
    prune!(model)
    @test nv(model) == 4

    # Test 15: Make stochastic node with aliased interfaces
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    μ = getorcreate!(model, ctx, :μ, nothing)
    σ = getorcreate!(model, ctx, :σ, nothing)
    out = getorcreate!(model, ctx, :out, nothing)
    node_id = first(make_node!(model, ctx, options, NormalMeanVariance, out, (mean = μ, variance = σ)))
    @test GraphPPL.neighbors(model, node_id) == [out, μ, σ]
end

@testitem "materialize_factor_node!" begin
    using Distributions
    using Graphs
    import GraphPPL:
        getcontext,
        materialize_factor_node!,
        create_model,
        getorcreate!,
        factorization_constraint,
        ProxyLabel,
        prune!,
        getname,
        label_for,
        edges,
        NodeCreationOptions

    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)

    # Test 1: Stochastic atomic call returns a new node
    node_id, _, _ = materialize_factor_node!(model, ctx, options, Normal, (out = x, μ = 0, σ = 1))
    @test nv(model) == 4
    @test getname.(edges(model, node_id)) == [:out, :μ, :σ]
    @test getname.(edges(model, node_id)) == [:out, :μ, :σ]

    # Test 3: Stochastic atomic call with an AbstractArray as rhs_interfaces
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)
    materialize_factor_node!(model, ctx, options, Normal, (out = x, μ = 0, σ = 1))
    @test nv(model) == 4 && ne(model) == 3

    # Test 4: Deterministic atomic call with nodelabels should create the actual node
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    in1 = getorcreate!(model, ctx, :in1, nothing)
    in2 = getorcreate!(model, ctx, :in2, nothing)
    out = getorcreate!(model, ctx, :out, nothing)
    materialize_factor_node!(model, ctx, options, +, (out = out, in = (in1, in2)))
    @test nv(model) == 4 && ne(model) == 3

    # Test 14: Make deterministic node with ProxyLabels as arguments
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)
    x = ProxyLabel(:x, nothing, x)
    y = getorcreate!(model, ctx, :y, nothing)
    y = ProxyLabel(:y, nothing, y)
    z = getorcreate!(model, ctx, :z, nothing)
    node_id = materialize_factor_node!(model, ctx, options, +, (out = z, in = (x, y)))
    prune!(model)
    @test nv(model) == 4
end

@testitem "make_node!(::Composite)" begin
    include("model_zoo.jl")
    using Graphs
    import GraphPPL: getcontext, make_node!, create_model, getorcreate!, ProxyLabel, NodeCreationOptions
    #test make node for priors
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)
    make_node!(model, ctx, options, prior, ProxyLabel(:x, nothing, x), ())
    @test nv(model) == 4
    @test ctx[prior, 1][:a] === ProxyLabel(:x, nothing, x)

    #test make node for other composite models
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)
    @test_throws ErrorException make_node!(model, ctx, options, gcv, ProxyLabel(:x, nothing, x), (0, 1))

    # test make node of broadcastable composite model
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    out = getorcreate!(model, ctx, :out, nothing)
    @test_broken broadcaster_ctx, _ = make_node!(model, ctx, options, broadcaster, ProxyLabel(:out, nothing, out), ()) # The broadcasting is broken currently
    @test_broken contains(repr(broadcaster_ctx), "broadcaster")
    @test_broken nv(model) == 103
end

@testitem "prune!(m::Model)" begin
    using Graphs
    import GraphPPL: create_model, getcontext, getorcreate!, prune!, create_model, getorcreate!, add_edge!, NodeCreationOptions

    # Test 1: Prune a node with no edges
    model = create_model()
    ctx = getcontext(model)
    x = getorcreate!(model, ctx, :x, nothing)
    prune!(model)
    @test nv(model) == 0

    # Test 2: Prune two nodes
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, nothing)
    y, ydata, yproperties = GraphPPL.add_atomic_factor_node!(model, ctx, options, sum)
    z = getorcreate!(model, ctx, :z, nothing)
    w = getorcreate!(model, ctx, :w, nothing)

    add_edge!(model, y, yproperties, z, :test)
    prune!(model)
    @test nv(model) == 2
end

@testitem "broadcast" begin
    import GraphPPL: NodeLabel, ResizableArray, create_model, getcontext, getorcreate!, make_node!, Broadcasted, NodeCreationOptions

    # Test 1: Broadcast a vector node
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, 1)
    x = getorcreate!(model, ctx, :x, 2)
    y = getorcreate!(model, ctx, :y, 1)
    y = getorcreate!(model, ctx, :y, 2)
    z = broadcast((x_, y_) -> begin
        var = make_node!(model, ctx, options, +, Broadcasted(:z), (x_, y_))
    end, x, y)
    @test size(z) == (2,)

    # Test 2: Broadcast a matrix node
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, 1, 1)
    x = getorcreate!(model, ctx, :x, 1, 2)
    x = getorcreate!(model, ctx, :x, 2, 1)
    x = getorcreate!(model, ctx, :x, 2, 2)

    y = getorcreate!(model, ctx, :y, 1, 1)
    y = getorcreate!(model, ctx, :y, 1, 2)
    y = getorcreate!(model, ctx, :y, 2, 1)
    y = getorcreate!(model, ctx, :y, 2, 2)
    z = broadcast((x_, y_) -> begin
        var = make_node!(model, ctx, options, +, Broadcasted(:z), (x_, y_))
    end, x, y)
    @test size(z) == (2, 2)

    # Test 3: Broadcast a vector node with a matrix node
    model = create_model()
    ctx = getcontext(model)
    options = NodeCreationOptions()
    x = getorcreate!(model, ctx, :x, 1)
    x = getorcreate!(model, ctx, :x, 2)
    y = getorcreate!(model, ctx, :y, 1, 1)
    y = getorcreate!(model, ctx, :y, 1, 2)
    y = getorcreate!(model, ctx, :y, 2, 1)
    y = getorcreate!(model, ctx, :y, 2, 2)
    z = broadcast((x_, y_) -> begin
        var = make_node!(model, ctx, options, +, Broadcasted(:z), (x_, y_))
    end, x, y)
    @test size(z) == (2, 2)
end

@testitem "getindex for StaticInterfaces" begin
    import GraphPPL: StaticInterfaces

    interfaces = (:a, :b, :c)
    sinterfaces = StaticInterfaces(interfaces)

    for (i, interface) in enumerate(interfaces)
        @test sinterfaces[i] === interface
    end
end

@testitem "sort_interfaces" begin
    import GraphPPL: sort_interfaces
    include("model_zoo.jl")

    # Test 1: Test that sort_interfaces sorts the interfaces in the correct order
    @test sort_interfaces(NormalMeanVariance, (μ = 1, σ = 1, out = 1)) == (out = 1, μ = 1, σ = 1)
    @test sort_interfaces(NormalMeanVariance, (out = 1, μ = 1, σ = 1)) == (out = 1, μ = 1, σ = 1)
    @test sort_interfaces(NormalMeanVariance, (σ = 1, out = 1, μ = 1)) == (out = 1, μ = 1, σ = 1)
    @test sort_interfaces(NormalMeanVariance, (σ = 1, μ = 1, out = 1)) == (out = 1, μ = 1, σ = 1)
    @test sort_interfaces(NormalMeanPrecision, (μ = 1, τ = 1, out = 1)) == (out = 1, μ = 1, τ = 1)
    @test sort_interfaces(NormalMeanPrecision, (out = 1, μ = 1, τ = 1)) == (out = 1, μ = 1, τ = 1)
    @test sort_interfaces(NormalMeanPrecision, (τ = 1, out = 1, μ = 1)) == (out = 1, μ = 1, τ = 1)
    @test sort_interfaces(NormalMeanPrecision, (τ = 1, μ = 1, out = 1)) == (out = 1, μ = 1, τ = 1)

    @test_throws ErrorException sort_interfaces(NormalMeanVariance, (σ = 1, μ = 1, τ = 1))
end

@testitem "prepare_interfaces" begin
    import GraphPPL: prepare_interfaces
    include("model_zoo.jl")

    @test prepare_interfaces(anonymous_in_loop, 1, (y = 1,)) == (x = 1, y = 1)
    @test prepare_interfaces(anonymous_in_loop, 1, (x = 1,)) == (y = 1, x = 1)

    @test prepare_interfaces(type_arguments, 1, (x = 1,)) == (n = 1, x = 1)
    @test prepare_interfaces(type_arguments, 1, (n = 1,)) == (x = 1, n = 1)
end
