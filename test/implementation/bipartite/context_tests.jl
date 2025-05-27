@testitem "Context Creation" setup = [MockLabels] begin
    import GraphPPL: ContextInterface, create_root_context, create_child_context, proxylabel

    # Test root context creation
    root_ctx = create_root_context(Context)
    @test root_ctx isa ContextInterface
    @test get_depth(root_ctx) == 0
    @test get_parent(root_ctx) === nothing

    # Test child context creation with proxy label
    interface_var = MockNodeLabel()
    proxy = proxylabel(:inputs, interface_var, nothing)
    interfaces = (inputs = proxy,)
    child_ctx = create_child_context(root_ctx, sin, interfaces)
    @test child_ctx isa ContextInterface
    @test get_depth(child_ctx) == 1
    @test get_parent(child_ctx) === root_ctx
    @test get_functional_form(child_ctx) == sin
end

@testitem "Basic Context Properties" setup = [MockLabels] begin
    import GraphPPL:
        create_root_context,
        create_child_context,
        get_depth,
        get_functional_form,
        get_prefix,
        get_parent,
        get_short_name,
        get_returnval,
        set_returnval!,
        get_path_to_root,
        proxylabel

    # Create test contexts
    root_ctx = create_root_context(Context)
    interface_var = MockNodeLabel()
    proxy = proxylabel(:inputs, interface_var, nothing)
    interfaces = (inputs = proxy,)
    child_ctx = create_child_context(root_ctx, sin, interfaces)
    grandchild_ctx = create_child_context(child_ctx, cos, interfaces)

    # Test depth hierarchy
    @test get_depth(root_ctx) == 0
    @test get_depth(child_ctx) == 1
    @test get_depth(grandchild_ctx) == 2

    # Test functional forms
    @test get_functional_form(child_ctx) == sin
    @test get_functional_form(grandchild_ctx) == cos

    # Test prefix and naming
    @test !isempty(get_prefix(root_ctx))
    @test !isempty(get_prefix(child_ctx))
    @test !isempty(get_short_name(root_ctx))
    @test !isempty(get_short_name(child_ctx))

    # Test parent relationships
    @test get_parent(root_ctx) === nothing
    @test get_parent(child_ctx) === root_ctx
    @test get_parent(grandchild_ctx) === child_ctx

    # Test return value setting and getting
    set_returnval!(child_ctx, 42)
    @test get_returnval(child_ctx) == 42
    set_returnval!(child_ctx, "test")
    @test get_returnval(child_ctx) == "test"

    # Test path to root
    root_path = get_path_to_root(grandchild_ctx)
    @test length(root_path) == 3
    @test root_path[1] === grandchild_ctx
    @test root_path[2] === child_ctx
    @test root_path[3] === root_ctx
end

@testitem "Variable Operations" setup = [MockLabels] begin
    import GraphPPL: create_root_context, get_variable, set_variable!, has_variable

    ctx = create_root_context(Context)

    # Test scalar variable
    var = MockNodeLabel()
    set_variable!(ctx, var, nothing)
    @test has_variable(ctx, :x, nothing)
    @test get_variable(ctx, :x, nothing) === var

    # Test vector variable
    vec_var = [MockNodeLabel() for _ in 1:3]
    set_variable!(ctx, vec_var, :vec)
    @test has_variable(ctx, :vec, 1)
    @test get_variable(ctx, :vec, 1) === vec_var[1]
    @test get_variable(ctx, :vec, 2) === vec_var[2]

    # Test tensor variable
    tensor_var = reshape([MockNodeLabel() for _ in 1:6], 2, 3)
    set_variable!(ctx, tensor_var, ())
    @test has_variable(ctx, :tensor, (1, 1))
    @test get_variable(ctx, :tensor, (1, 1)) === tensor_var[1, 1]
    @test get_variable(ctx, :tensor, (2, 3)) === tensor_var[2, 3]

    # Test non-existent variables
    @test !has_variable(ctx, :nonexistent, nothing)
    @test_throws Exception get_variable(ctx, :nonexistent, nothing)
end

@testitem "Factor Operations" setup = [MockLabels] begin
    import GraphPPL: create_root_context, get_factor, set_factor_node!

    ctx = create_root_context(Context)

    # Create test factors
    factor1 = MockFactorNodeLabel()
    factor2 = MockFactorNodeLabel()

    # Test setting and getting factors
    set_factor_node!(ctx, sin, :factor1, factor1)
    set_factor_node!(ctx, cos, :factor2, factor2)

    @test get_factor(ctx, :factor1) === factor1
    @test get_factor(ctx, :factor2) === factor2

    # Test non-existent factors
    @test_throws Exception get_factor(ctx, :nonexistent)
end

@testitem "Child Context Operations" setup = [MockLabels] begin
    import GraphPPL: create_root_context, create_child_context, get_child_context, set_child_context!, proxylabel

    root_ctx = create_root_context(Context)

    # Create interface variables
    interface_var1 = MockNodeLabel()
    interface_var2 = MockNodeLabel()

    # Create and set child contexts with proper proxy labels
    proxy1 = proxylabel(:inputs, interface_var1, nothing)
    proxy2 = proxylabel(:inputs, interface_var2, nothing)

    interfaces1 = (inputs = proxy1,)
    interfaces2 = (inputs = proxy2,)

    child1 = create_child_context(root_ctx, sin, interfaces1)
    child2 = create_child_context(root_ctx, cos, interfaces2)

    set_child_context!(root_ctx, sin, :child1, child1)
    set_child_context!(root_ctx, cos, :child2, child2)

    # Test retrieving child contexts
    @test get_child_context(root_ctx, sin, :child1) === child1
    @test get_child_context(root_ctx, cos, :child2) === child2

    # Test nested child contexts
    proxy3 = proxylabel(:inputs, interface_var1, nothing)
    interfaces3 = (inputs = proxy3,)
    grandchild = create_child_context(child1, tan, interfaces3)
    set_child_context!(child1, tan, :grandchild, grandchild)
    @test get_child_context(child1, tan, :grandchild) === grandchild

    # Test non-existent child contexts
    @test_throws Exception get_child_context(root_ctx, tan, :nonexistent)
end

@testitem "Markov Blanket Operations" setup = [MockLabels] begin
    import GraphPPL: create_root_context, create_child_context, get_variable, set_variable!, proxylabel

    # Create contexts
    parent_ctx = create_root_context(Context)

    # Setup interface variables in parent
    interface_var = MockNodeLabel()
    set_variable!(parent_ctx, interface_var, nothing)

    # Create child with markov blanket using proper proxy label
    proxy = proxylabel(:inputs, interface_var, nothing)
    interfaces = (inputs = proxy,)
    child_ctx = create_child_context(parent_ctx, sin, interfaces)

    # Test if interface variables are accessible in child
    @test get_variable(child_ctx, :inputs, nothing) === interface_var

    # Test nested markov blanket propagation
    grandchild_ctx = create_child_context(child_ctx, cos, interfaces)
    @test get_variable(grandchild_ctx, :inputs, nothing) === interface_var
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

@testitem "getcontext(::Model)" setup = [TestUtils] begin
    import GraphPPL: Context, getcontext, create_model, add_variable_node!, NodeCreationOptions

    model = TestUtils.create_test_model()
    @test getcontext(model) == model.graph[]
    add_variable_node!(model, getcontext(model), NodeCreationOptions(), :x, nothing)
    @test getcontext(model)[:x] == model.graph[][:x]
end

@testitem "path_to_root(::Context)" setup = [TestUtils] begin
    import GraphPPL: create_model, Context, path_to_root, getcontext

    ctx = Context()
    @test path_to_root(ctx) == [ctx]

    model = create_model(TestUtils.outer())
    ctx = getcontext(model)
    inner_context = ctx[TestUtils.inner, 1]
    inner_inner_context = inner_context[TestUtils.inner_inner, 1]
    @test path_to_root(inner_inner_context) == [inner_inner_context, inner_context, ctx]
end

@testitem "VarDict" setup = [TestUtils] begin
    using Distributions
    import GraphPPL:
        Context, VarDict, create_model, getorcreate!, datalabel, NodeCreationOptions, getcontext, is_random, is_data, getproperties

    ctx = Context()
    vardict = VarDict(ctx)
    @test isa(vardict, VarDict)

    TestUtils.@model function submodel(y, x_prev, x_next)
        γ ~ Gamma(1, 1)
        x_next ~ Normal(x_prev, γ)
        y ~ Normal(x_next, 1)
    end

    TestUtils.@model function state_space_model_with_new(y)
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