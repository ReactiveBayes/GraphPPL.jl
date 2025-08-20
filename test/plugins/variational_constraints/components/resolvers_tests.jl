@testitem "ResolvedIndexedVariable" setup = [TestUtils] begin
    import GraphPPL: ResolvedIndexedVariable, IndexedVariable, getname, index, getcontext

    var = ResolvedIndexedVariable(IndexedVariable(:x, 1), Context())
    @test getname(var) == :x
    @test index(var) == 1
    @test getcontext(var) isa Context
end

@testitem "ResolvedConstraintLHS" setup = [TestUtils] begin
    import GraphPPL: ResolvedConstraintLHS, ResolvedIndexedVariable, IndexedVariable, getvariables

    ctx = Context()
    var1 = ResolvedIndexedVariable(IndexedVariable(:x, 1), ctx)
    var2 = ResolvedIndexedVariable(IndexedVariable(:y, 2), ctx)

    lhs = ResolvedConstraintLHS((var1, var2))
    @test getvariables(lhs) == (var1, var2)

    lhs1 = ResolvedConstraintLHS((var1, var2))
    lhs2 = ResolvedConstraintLHS((var1, var2))
    @test lhs1 == lhs2

    lhs3 = ResolvedConstraintLHS((var2, var1))
    @test lhs1 != lhs3
end

@testitem "ResolvedFactorizationConstraintEntry" setup = [TestUtils] begin
    import GraphPPL: ResolvedFactorizationConstraintEntry, ResolvedIndexedVariable, IndexedVariable, getvariables

    ctx = Context()
    var1 = ResolvedIndexedVariable(IndexedVariable(:x, 1), ctx)
    var2 = ResolvedIndexedVariable(IndexedVariable(:y, 2), ctx)

    entry = ResolvedFactorizationConstraintEntry((var1, var2))
    @test getvariables(entry) == (var1, var2)
end

@testitem "ResolvedFactorizationConstraint" setup = [TestUtils] begin
    import GraphPPL:
        ResolvedFactorizationConstraint,
        ResolvedConstraintLHS,
        ResolvedFactorizationConstraintEntry,
        ResolvedIndexedVariable,
        IndexedVariable,
        lhs,
        rhs

    ctx = Context()
    var1 = ResolvedIndexedVariable(IndexedVariable(:x, 1), ctx)
    var2 = ResolvedIndexedVariable(IndexedVariable(:y, 2), ctx)

    resolved_lhs = ResolvedConstraintLHS((var1, var2))
    entry1 = ResolvedFactorizationConstraintEntry((var1,))
    entry2 = ResolvedFactorizationConstraintEntry((var2,))

    constraint = ResolvedFactorizationConstraint(resolved_lhs, (entry1, entry2))
    @test lhs(constraint) == resolved_lhs
    @test rhs(constraint) == (entry1, entry2)

    constraint1 = ResolvedFactorizationConstraint(resolved_lhs, (entry1, entry2))
    constraint2 = ResolvedFactorizationConstraint(resolved_lhs, (entry1, entry2))
    @test constraint1 == constraint2

    constraint3 = ResolvedFactorizationConstraint(resolved_lhs, (entry2, entry1))
    @test constraint1 != constraint3
end

@testitem "ResolvedFunctionalFormConstraint" setup = [TestUtils] begin
    import GraphPPL: ResolvedFunctionalFormConstraint, ResolvedConstraintLHS, ResolvedIndexedVariable, IndexedVariable, lhs, rhs
    using Distributions

    ctx = Context()
    var1 = ResolvedIndexedVariable(IndexedVariable(:x, 1), ctx)
    var2 = ResolvedIndexedVariable(IndexedVariable(:y, 2), ctx)

    resolved_lhs = ResolvedConstraintLHS((var1, var2))

    constraint = ResolvedFunctionalFormConstraint(resolved_lhs, Normal)
    @test lhs(constraint) == resolved_lhs
    @test rhs(constraint) == Normal
end

@testitem "ConstraintStack" setup = [TestUtils] begin
    import GraphPPL:
        ConstraintStack,
        ResolvedFactorizationConstraint,
        ResolvedConstraintLHS,
        ResolvedFactorizationConstraintEntry,
        ResolvedIndexedVariable,
        IndexedVariable,
        constraints,
        context_counts

    ctx1 = Context()
    ctx2 = Context()
    var1 = ResolvedIndexedVariable(IndexedVariable(:x, 1), ctx1)
    var2 = ResolvedIndexedVariable(IndexedVariable(:y, 2), ctx1)

    resolved_lhs = ResolvedConstraintLHS((var1, var2))
    entry1 = ResolvedFactorizationConstraintEntry((var1,))
    entry2 = ResolvedFactorizationConstraintEntry((var2,))

    constraint1 = ResolvedFactorizationConstraint(resolved_lhs, (entry1, entry2))
    constraint2 = ResolvedFactorizationConstraint(resolved_lhs, (entry2, entry1))

    stack = ConstraintStack()
    @test isempty(context_counts(stack))

    push!(stack, constraint1, ctx1)
    @test context_counts(stack)[ctx1] == 1
    @test isempty(get(context_counts(stack), ctx2, Dict()))

    push!(stack, constraint2, ctx1)
    @test context_counts(stack)[ctx1] == 2

    push!(stack, constraint1, ctx2)
    @test context_counts(stack)[ctx1] == 2
    @test context_counts(stack)[ctx2] == 1

    @test pop!(stack, ctx1)
    @test context_counts(stack)[ctx1] == 1

    @test pop!(stack, ctx1)
    @test context_counts(stack)[ctx1] == 0

    @test !pop!(stack, ctx1)
    @test context_counts(stack)[ctx1] == 0

    @test pop!(stack, ctx2)
    @test context_counts(stack)[ctx2] == 0

    @test !pop!(stack, ctx2)
end

@testitem "Resolve Factorization Constraints" setup = [TestUtils] begin
    using Distributions
    import GraphPPL:
        create_model,
        FactorizationConstraint,
        FactorizationConstraintEntry,
        IndexedVariable,
        resolve,
        ResolvedFactorizationConstraint,
        ResolvedConstraintLHS,
        ResolvedFactorizationConstraintEntry,
        ResolvedIndexedVariable,
        CombinedRange,
        SplittedRange,
        @model

    model = create_model(TestUtils.outer())
    ctx = GraphPPL.getcontext(model)
    inner_context = ctx[TestUtils.inner, 1]

    # Test resolve constraint in child model

    let constraint = FactorizationConstraint(
            (IndexedVariable(:α, nothing), IndexedVariable(:θ, nothing)),
            (FactorizationConstraintEntry((IndexedVariable(:α, nothing),)), FactorizationConstraintEntry((IndexedVariable(:θ, nothing),)))
        )
        result = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:y, nothing, ctx), ResolvedIndexedVariable(:w, CombinedRange(2, 3), ctx)),),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, nothing, ctx),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, CombinedRange(2, 3), ctx),))
            )
        )
        @test resolve(model, inner_context, constraint) == result
    end

    # Test constraint in top level model

    let constraint = FactorizationConstraint(
            (IndexedVariable(:y, nothing), IndexedVariable(:w, nothing)),
            (FactorizationConstraintEntry((IndexedVariable(:y, nothing),)), FactorizationConstraintEntry((IndexedVariable(:w, nothing),)))
        )
        result = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:y, nothing, ctx), ResolvedIndexedVariable(:w, CombinedRange(1, 5), ctx)),),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, nothing, ctx),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, CombinedRange(1, 5), ctx),))
            )
        )
        @test resolve(model, ctx, constraint) == result
    end

    # Test a constraint that is not applicable at all

    let constraint = FactorizationConstraint(
            (IndexedVariable(:i, nothing), IndexedVariable(:dont, nothing), IndexedVariable(:apply, nothing)),
            (
                FactorizationConstraintEntry((IndexedVariable(:i, nothing),)),
                FactorizationConstraintEntry((IndexedVariable(:dont, nothing),)),
                FactorizationConstraintEntry((IndexedVariable(:apply, nothing),))
            )
        )
        result = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((),),
            (ResolvedFactorizationConstraintEntry(()), ResolvedFactorizationConstraintEntry(()), ResolvedFactorizationConstraintEntry(()))
        )
        @test resolve(model, ctx, constraint) == result
    end

    model = create_model(TestUtils.filled_matrix_model())
    ctx = GraphPPL.getcontext(model)

    let constraint = FactorizationConstraint(
            (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
            (FactorizationConstraintEntry((IndexedVariable(:x, nothing),)), FactorizationConstraintEntry((IndexedVariable(:y, nothing),)))
        )
        result = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((
                ResolvedIndexedVariable(:x, CombinedRange(1, 9), ctx), ResolvedIndexedVariable(:y, CombinedRange(1, 9), ctx)
            ),),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:x, CombinedRange(1, 9), ctx),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, CombinedRange(1, 9), ctx),))
            )
        )
        @test resolve(model, ctx, constraint) == result
    end
    model = create_model(TestUtils.filled_matrix_model())
    ctx = GraphPPL.getcontext(model)

    let constraint = FactorizationConstraint(
            (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
            (FactorizationConstraintEntry((IndexedVariable(:x, nothing),)), FactorizationConstraintEntry((IndexedVariable(:y, nothing),)))
        )
        result = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((
                ResolvedIndexedVariable(:x, CombinedRange(1, 9), ctx), ResolvedIndexedVariable(:y, CombinedRange(1, 9), ctx)
            ),),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:x, CombinedRange(1, 9), ctx),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, CombinedRange(1, 9), ctx),))
            )
        )
        @test resolve(model, ctx, constraint) == result
    end

    # Test a constraint that mentions a lower-dimensional slice of a matrix variable

    @model function uneven_matrix()
        local prec
        local y
        for i in 1:3
            for j in 1:3
                prec[i, j] ~ Gamma(1, 1)
                y[i, j] ~ Normal(0, prec[i, j])
            end
        end
        prec[2, 4] ~ Gamma(1, 1)
        y[2, 4] ~ Normal(0, prec[2, 4])
    end

    model = create_model(uneven_matrix())
    ctx = GraphPPL.getcontext(model)
    let constraint = GraphPPL.FactorizationConstraint(
            (IndexedVariable(:prec, [1, 3]), IndexedVariable(:y, nothing)),
            (
                FactorizationConstraintEntry((IndexedVariable(:prec, [1, 3]),)),
                FactorizationConstraintEntry((IndexedVariable(:y, nothing),))
            )
        )
        result = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:prec, 3, ctx), ResolvedIndexedVariable(:y, CombinedRange(1, 10), ctx)),),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:prec, 3, ctx),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, CombinedRange(1, 10), ctx),))
            )
        )
        @test resolve(model, ctx, constraint) == result
    end
end

@testitem "Resolved Constraints in" begin
    import GraphPPL:
        ResolvedFactorizationConstraint,
        ResolvedConstraintLHS,
        ResolvedFactorizationConstraintEntry,
        ResolvedIndexedVariable,
        SplittedRange,
        getname,
        index,
        VariableNodeProperties,
        NodeLabel,
        ResizableArray

    context = GraphPPL.Context()
    context[:w] = ResizableArray([NodeLabel(:w, 1), NodeLabel(:w, 2), NodeLabel(:w, 3), NodeLabel(:w, 4), NodeLabel(:w, 5)])
    context[:prec] = ResizableArray([
        [NodeLabel(:prec, 1), NodeLabel(:prec, 2), NodeLabel(:prec, 3)], [NodeLabel(:prec, 4), NodeLabel(:prec, 5), NodeLabel(:prec, 6)]
    ])

    variable = ResolvedIndexedVariable(:w, 2:3, context)
    node_data = GraphPPL.NodeData(context, VariableNodeProperties(name = :w, index = 2))
    @test node_data ∈ variable

    variable = ResolvedIndexedVariable(:w, 2:3, context)
    node_data = GraphPPL.NodeData(GraphPPL.Context(), VariableNodeProperties(name = :w, index = 2))
    @test !(node_data ∈ variable)

    variable = ResolvedIndexedVariable(:w, 2, context)
    node_data = GraphPPL.NodeData(context, VariableNodeProperties(name = :w, index = 2))
    @test node_data ∈ variable

    variable = ResolvedIndexedVariable(:w, SplittedRange(2, 3), context)
    node_data = GraphPPL.NodeData(context, VariableNodeProperties(name = :w, index = 2))
    @test node_data ∈ variable

    variable = ResolvedIndexedVariable(:w, SplittedRange(10, 15), context)
    node_data = GraphPPL.NodeData(context, VariableNodeProperties(name = :w, index = 2))
    @test !(node_data ∈ variable)

    variable = ResolvedIndexedVariable(:x, nothing, context)
    node_data = GraphPPL.NodeData(context, VariableNodeProperties(name = :x, index = 2))
    @test node_data ∈ variable

    variable = ResolvedIndexedVariable(:x, nothing, context)
    node_data = GraphPPL.NodeData(context, VariableNodeProperties(name = :x, index = nothing))
    @test node_data ∈ variable

    variable = ResolvedIndexedVariable(:prec, 3, context)
    node_data = GraphPPL.NodeData(context, VariableNodeProperties(name = :prec, index = (1, 3)))
    @test node_data ∈ variable
end