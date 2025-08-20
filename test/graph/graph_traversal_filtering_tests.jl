@testitem "factor_nodes" setup = [TestUtils] begin
    import GraphPPL: create_model, factor_nodes, is_factor, labels

    for modelfn in TestUtils.ModelsInTheZooWithoutArguments
        model = create_model(modelfn())
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

@testitem "factor_nodes with lambda function" setup = [TestUtils] begin
    import GraphPPL: create_model, factor_nodes, is_factor, labels

    for model_fn in TestUtils.ModelsInTheZooWithoutArguments
        model = create_model(model_fn())
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

@testitem "variable_nodes" setup = [TestUtils] begin
    import GraphPPL: create_model, variable_nodes, is_variable, labels

    for model_fn in TestUtils.ModelsInTheZooWithoutArguments
        model = create_model(model_fn())
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

@testitem "variable_nodes with lambda function" setup = [TestUtils] begin
    import GraphPPL: create_model, variable_nodes, is_variable, labels

    for model_fn in TestUtils.ModelsInTheZooWithoutArguments
        model = create_model(model_fn())
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

@testitem "variable_nodes with anonymous variables" setup = [TestUtils] begin
    # The idea here is that the `variable_nodes` must return ALL anonymous variables as well
    using Distributions
    import GraphPPL: create_model, variable_nodes, getname, is_anonymous, getproperties

    TestUtils.@model function simple_submodel_with_2_anonymous_for_variable_nodes(z, x, y)
        # Creates two anonymous variables here
        z ~ Normal(x + 1, y - 1)
    end

    TestUtils.@model function simple_submodel_with_3_anonymous_for_variable_nodes(z, x, y)
        # Creates three anonymous variables here
        z ~ Normal(x + 1, y - 1 + 1)
    end

    TestUtils.@model function simple_model_for_variable_nodes(submodel)
        xref ~ Normal(0, 1)
        y ~ Gamma(1, 1)
        zref ~ submodel(x = xref, y = y)
    end

    @testset let submodel = simple_submodel_with_2_anonymous_for_variable_nodes
        model = create_model(simple_model_for_variable_nodes(submodel = submodel))
        @test length(collect(variable_nodes(model))) === 11
        @test length(collect(filter(v -> is_anonymous(getproperties(model[v])), collect(variable_nodes(model))))) === 2
    end

    @testset let submodel = simple_submodel_with_3_anonymous_for_variable_nodes
        model = create_model(simple_model_for_variable_nodes(submodel = submodel))
        @test length(collect(variable_nodes(model))) === 13 # +1 for new anonymous +1 for new constant
        @test length(collect(filter(v -> is_anonymous(getproperties(model[v])), collect(variable_nodes(model))))) === 3
    end
end

@testitem "filter(::Predicate, ::Model)" setup = [TestUtils] begin
    import GraphPPL: create_model, as_node, as_context, as_variable
    using Distributions

    model = create_model(TestUtils.simple_model())
    result = collect(filter(as_node(Normal) | as_variable(:x), model))
    @test length(result) == 3

    model = create_model(TestUtils.outer())
    result = collect(filter(as_node(Gamma) & as_context(TestUtils.inner_inner), model))
    @test length(result) == 0

    result = collect(filter(as_node(Gamma) | as_context(TestUtils.inner_inner), model))
    @test length(result) == 6

    result = collect(filter(as_node(Normal) & as_context(TestUtils.inner_inner; children = true), model))
    @test length(result) == 1
end

@testitem "filter(::FactorNodePredicate, ::Model)" setup = [TestUtils] begin
    import GraphPPL: create_model, as_node, getcontext
    using Distributions

    model = create_model(TestUtils.simple_model())
    context = getcontext(model)
    result = filter(as_node(Normal), model)
    @test collect(result) == [context[TestUtils.NormalMeanVariance, 1], context[TestUtils.NormalMeanVariance, 2]]
    result = filter(as_node(), model)
    @test collect(result) ==
        [context[TestUtils.NormalMeanVariance, 1], context[TestUtils.GammaShapeScale, 1], context[TestUtils.NormalMeanVariance, 2]]
end

@testitem "filter(::VariableNodePredicate, ::Model)" setup = [TestUtils] begin
    import GraphPPL: create_model, as_variable, getcontext, variable_nodes

    model = create_model(TestUtils.simple_model())
    context = getcontext(model)
    result = filter(as_variable(:x), model)
    @test collect(result) == [context[:x]...]
    result = filter(as_variable(), model)
    @test collect(result) == collect(variable_nodes(model))
end

@testitem "filter(::SubmodelPredicate, Model)" setup = [TestUtils] begin
    import GraphPPL: create_model, as_context

    model = create_model(TestUtils.outer())

    result = filter(as_context(TestUtils.inner), model)
    @test length(collect(result)) == 0

    result = filter(as_context(TestUtils.inner; children = true), model)
    @test length(collect(result)) == 1

    result = filter(as_context(TestUtils.inner_inner), model)
    @test length(collect(result)) == 1

    result = filter(as_context(TestUtils.outer; children = true), model)
    @test length(collect(result)) == 22
end