@testitem "default_constraints" setup = [TestUtils] begin
    import GraphPPL:
        create_model,
        with_plugins,
        default_constraints,
        getproperties,
        PluginsCollection,
        VariationalConstraintsPlugin,
        hasextra,
        getextra,
        UnspecifiedConstraints

    @test default_constraints(TestUtils.simple_model) == UnspecifiedConstraints
    @test default_constraints(TestUtils.model_with_default_constraints) == @constraints(
        begin
            q(a, d) = q(a)q(d)
        end
    )

    model = create_model(with_plugins(TestUtils.contains_default_constraints(), PluginsCollection(VariationalConstraintsPlugin())))
    ctx = GraphPPL.getcontext(model)
    # Test that default constraints are applied
    for i in 1:10
        node = model[ctx[TestUtils.model_with_default_constraints, i][TestUtils.NormalMeanVariance, 1]]
        @test hasextra(node, :factorization_constraint_indices)
        @test Tuple.(getextra(node, :factorization_constraint_indices)) == ((1,), (2,), (3,))
    end

    # Test that default constraints are not applied if we specify constraints in the context
    c = @constraints begin
        for q in TestUtils.model_with_default_constraints
            q(a, d) = q(a, d)
        end
    end
    model = create_model(with_plugins(TestUtils.contains_default_constraints(), PluginsCollection(VariationalConstraintsPlugin(c))))
    ctx = GraphPPL.getcontext(model)
    for i in 1:10
        node = model[ctx[TestUtils.model_with_default_constraints, i][TestUtils.NormalMeanVariance, 1]]
        @test hasextra(node, :factorization_constraint_indices)
        @test Tuple.(getextra(node, :factorization_constraint_indices)) == ((1, 2), (3,))
    end

    # Test that default constraints are not applied if we specify constraints for a specific instance of the submodel
    c = @constraints begin
        for q in (TestUtils.model_with_default_constraints, 1)
            q(a, d) = q(a, d)
        end
    end
    model = create_model(with_plugins(TestUtils.contains_default_constraints(), PluginsCollection(VariationalConstraintsPlugin(c))))
    ctx = GraphPPL.getcontext(model)
    for i in 1:10
        node = model[ctx[TestUtils.model_with_default_constraints, i][TestUtils.NormalMeanVariance, 1]]
        @test hasextra(node, :factorization_constraint_indices)
        if i == 1
            @test Tuple.(getextra(node, :factorization_constraint_indices)) == ((1, 2), (3,))
        else
            @test Tuple.(getextra(node, :factorization_constraint_indices)) == ((1,), (2,), (3,))
        end
    end
end

@testitem "show constraints" begin
    using Distributions
    using GraphPPL

    constraint = @constraints begin
        q(x)::Normal
    end
    @test occursin(r"q\(x\) ::(.*?)Normal", repr(constraint))

    constraint = @constraints begin
        q(x, y) = q(x)q(y)
    end
    @test occursin(r"q\(x, y\) = q\(x\)q\(y\)", repr(constraint))

    constraint = @constraints begin
        μ(x)::Normal
    end
    @test occursin(r"μ\(x\) ::(.*?)Normal", repr(constraint))

    constraint = @constraints begin
        q(x, y) = q(x)q(y)
        μ(x)::Normal
    end
    @test occursin(r"q\(x, y\) = q\(x\)q\(y\)", repr(constraint))
    @test occursin(r"μ\(x\) ::(.*?)Normal", repr(constraint))
end