
@testitem "Context" begin
    import GraphPPL: Context

    ctx1 = Context()
    @test typeof(ctx1) == Context && ctx1.prefix == "" && length(ctx1.individual_variables) == 0 && ctx1.depth == 0

    io = IOBuffer()
    show(io, ctx1)
    output = String(take!(io))
    @test !isempty(output)
    @test contains(output, "identity") # fform

    # By default `returnval` is not defined
    @test_throws UndefRefError GraphPPL.returnval(ctx1)
    for i in 1:10
        GraphPPL.returnval!(ctx1, (i, "$i"))
        @test GraphPPL.returnval(ctx1) == (i, "$i")
    end

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
        Context,
        NodeLabel,
        ResizableArray,
        ProxyLabel,
        individual_variables,
        vector_variables,
        tensor_variables,
        proxies,
        children,
        proxylabel

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
    ctx[:proxy] = proxylabel(:proxy, xlab, nothing)
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

    include("testutils.jl")

    model = create_test_model()
    @test getcontext(model) == model.graph[]
    add_variable_node!(model, getcontext(model), NodeCreationOptions(), :x, nothing)
    @test getcontext(model)[:x] == model.graph[][:x]
end

@testitem "path_to_root(::Context)" begin
    import GraphPPL: create_model, Context, path_to_root, getcontext

    include("testutils.jl")

    using .TestUtils.ModelZoo

    ctx = Context()
    @test path_to_root(ctx) == [ctx]

    model = create_model(outer())
    ctx = getcontext(model)
    inner_context = ctx[inner, 1]
    inner_inner_context = inner_context[inner_inner, 1]
    @test path_to_root(inner_inner_context) == [inner_inner_context, inner_context, ctx]
end

@testitem "VarDict" begin
    using Distributions
    import GraphPPL:
        Context, VarDict, create_model, getorcreate!, datalabel, NodeCreationOptions, getcontext, is_random, is_data, getproperties

    include("testutils.jl")

    ctx = Context()
    vardict = VarDict(ctx)
    @test isa(vardict, VarDict)

    @model function submodel(y, x_prev, x_next)
        γ ~ Gamma(1, 1)
        x_next ~ Normal(x_prev, γ)
        y ~ Normal(x_next, 1)
    end

    @model function state_space_model_with_new(y)
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], 1)
        for i in 2:length(y)
            y[i] ~ submodel(x_next = new(x[i]), x_prev = x[i - 1])
        end
    end

    ydata = ones(10)
    model = create_model(state_space_model_with_new()) do model, ctx
        y = datalabel(model, ctx, NodeCreationOptions(kind = :data), :y, ydata)
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

@testitem "setindex!(::Context, ::ResizableArray{NodeLabel}, ::Symbol)" begin
    import GraphPPL: NodeLabel, ResizableArray, Context, vector_variables, tensor_variables

    context = Context()
    context[:x] = ResizableArray(NodeLabel, Val(1))
    @test haskey(vector_variables(context), :x)

    context[:y] = ResizableArray(NodeLabel, Val(2))
    @test haskey(tensor_variables(context), :y)
end