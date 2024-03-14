@testitem "FactorizationConstraintEntry" begin
    import GraphPPL: FactorizationConstraintEntry, IndexedVariable

    # Test 1: Test FactorisationConstraintEntry
    @test FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))) isa FactorizationConstraintEntry

    a = FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)))
    b = FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)))
    @test a == b
    c = FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing), IndexedVariable(:z, nothing)))
    @test a != c
    d = FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:p, nothing)))
    @test a != d

    # Test 2: Test FactorisationConstraintEntry with mixed IndexedVariable types
    a = FactorizationConstraintEntry((IndexedVariable(:x, 1), IndexedVariable(:y, nothing)))
end

@testitem "CombinedRange" begin
    import GraphPPL: CombinedRange, is_splitted, FunctionalIndex, IndexedVariable
    for left in 1:3, right in 5:8
        cr = CombinedRange(left, right)

        @test firstindex(cr) === left
        @test lastindex(cr) === right
        @test !is_splitted(cr)
        @test length(cr) === lastindex(cr) - firstindex(cr) + 1

        for i in left:right
            @test i ∈ cr
            @test !((i + lastindex(cr) + 1) ∈ cr)
        end
    end
    range = CombinedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))
    @test firstindex(range).f === firstindex
    @test lastindex(range).f === lastindex
    @test_throws MethodError length(range)

    # Test IndexedVariable with CombinedRange equality
    lhs = IndexedVariable(:x, CombinedRange(1, 2))
    rhs = IndexedVariable(:x, CombinedRange(1, 2))
    @test lhs == rhs
    @test lhs === rhs
    @test lhs != IndexedVariable(:x, CombinedRange(1, 3))
    @test lhs !== IndexedVariable(:x, CombinedRange(1, 3))
    @test lhs != IndexedVariable(:y, CombinedRange(1, 2))
    @test lhs !== IndexedVariable(:y, CombinedRange(1, 2))
end

@testitem "SplittedRange" begin
    import GraphPPL: SplittedRange, is_splitted, FunctionalIndex, IndexedVariable
    for left in 1:3, right in 5:8
        cr = SplittedRange(left, right)

        @test firstindex(cr) === left
        @test lastindex(cr) === right
        @test is_splitted(cr)
        @test length(cr) === lastindex(cr) - firstindex(cr) + 1

        for i in left:right
            @test i ∈ cr
            @test !((i + lastindex(cr) + 1) ∈ cr)
        end
    end
    range = SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))
    @test firstindex(range).f === firstindex
    @test lastindex(range).f === lastindex
    @test_throws MethodError length(range)

    # Test IndexedVariable with SplittedRange equality
    lhs = IndexedVariable(:x, SplittedRange(1, 2))
    rhs = IndexedVariable(:x, SplittedRange(1, 2))
    @test lhs == rhs
    @test lhs === rhs
    @test lhs != IndexedVariable(:x, SplittedRange(1, 3))
    @test lhs !== IndexedVariable(:x, SplittedRange(1, 3))
    @test lhs != IndexedVariable(:y, SplittedRange(1, 2))
    @test lhs !== IndexedVariable(:y, SplittedRange(1, 2))
end

@testitem "__factorization_specification_resolve_index" begin
    using GraphPPL
    import GraphPPL: __factorization_specification_resolve_index, FunctionalIndex, CombinedRange, SplittedRange, NodeLabel, ResizableArray

    collection = ResizableArray(NodeLabel, Val(1))
    for i in 1:10
        collection[i] = NodeLabel(:x, i)
    end

    # Test 1: Test __factorization_specification_resolve_index with FunctionalIndex
    index = FunctionalIndex{:begin}(firstindex)
    @test __factorization_specification_resolve_index(index, collection) === firstindex(collection)

    @test_throws ErrorException __factorization_specification_resolve_index(index, collection[1])

    # Test 2: Test __factorization_specification_resolve_index with CombinedRange
    index = CombinedRange(1, 5)
    @test __factorization_specification_resolve_index(index, collection) === index
    index = CombinedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))
    @test __factorization_specification_resolve_index(index, collection) === CombinedRange(1, 10)
    index = CombinedRange(5, FunctionalIndex{:end}(lastindex))
    @test __factorization_specification_resolve_index(index, collection) === CombinedRange(5, 10)
    index = CombinedRange(1, 20)
    @test_throws ErrorException __factorization_specification_resolve_index(index, collection)

    @test_throws ErrorException __factorization_specification_resolve_index(index, collection[1])

    # Test 3: Test __factorization_specification_resolve_index with SplittedRange
    index = SplittedRange(1, 5)
    @test __factorization_specification_resolve_index(index, collection) === index
    index = SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))
    @test __factorization_specification_resolve_index(index, collection) === SplittedRange(1, 10)
    index = SplittedRange(5, FunctionalIndex{:end}(lastindex))
    @test __factorization_specification_resolve_index(index, collection) === SplittedRange(5, 10)
    index = SplittedRange(1, 20)
    @test_throws ErrorException __factorization_specification_resolve_index(index, collection)

    @test_throws ErrorException __factorization_specification_resolve_index(index, collection[1])

    # Test 4: Test __factorization_specification_resolve_index with Array of indices
    index = SplittedRange(
        [FunctionalIndex{:begin}(firstindex), FunctionalIndex{:begin}(firstindex)],
        [FunctionalIndex{:end}(lastindex), FunctionalIndex{:end}(lastindex)]
    )
    collection = GraphPPL.ResizableArray(GraphPPL.NodeLabel, Val(2))
    for i in 1:3
        for j in 1:5
            collection[i, j] = GraphPPL.NodeLabel(:x, i * j)
        end
    end
end

@testitem "factorization_split" begin
    import GraphPPL: factorization_split, FactorizationConstraintEntry, IndexedVariable, FunctionalIndex, CombinedRange, SplittedRange

    # Test 1: Test factorization_split with single split
    @test factorization_split(
        (FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),)),),
        (FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),)),)
    ) == (
        FactorizationConstraintEntry((
            IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
        ),),
    )

    @test factorization_split(
        (
            FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),))
        ),
        (
            FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),)),
            FactorizationConstraintEntry((IndexedVariable(:z, nothing),))
        )
    ) == (
        FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
        FactorizationConstraintEntry((
            IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
        )),
        FactorizationConstraintEntry((IndexedVariable(:z, nothing),))
    )

    @test factorization_split(
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)), IndexedVariable(:y, FunctionalIndex{:begin}(firstindex))
            )),
        ),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, FunctionalIndex{:end}(lastindex)), IndexedVariable(:y, FunctionalIndex{:end}(lastindex))
            )),
        )
    ) == (
        FactorizationConstraintEntry((
            IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
            IndexedVariable(:y, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex)))
        )),
    )

    # Test factorization_split with only FactorizationConstraintEntrys
    @test factorization_split(
        FactorizationConstraintEntry((
            IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)), IndexedVariable(:y, FunctionalIndex{:begin}(firstindex))
        )),
        FactorizationConstraintEntry((
            IndexedVariable(:x, FunctionalIndex{:end}(lastindex)), IndexedVariable(:y, FunctionalIndex{:end}(lastindex))
        ))
    ) == FactorizationConstraintEntry((
        IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
        IndexedVariable(:y, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex)))
    ))

    # Test mixed behaviour 
    @test factorization_split(
        (
            FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),))
        ),
        FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),))
    ) == (
        FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
        FactorizationConstraintEntry((
            IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
        ))
    )

    @test factorization_split(
        FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:begin}(firstindex)),)),
        (
            FactorizationConstraintEntry((IndexedVariable(:x, FunctionalIndex{:end}(lastindex)),)),
            FactorizationConstraintEntry((IndexedVariable(:z, nothing),),)
        )
    ) == (
        FactorizationConstraintEntry((
            IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
        )),
        FactorizationConstraintEntry((IndexedVariable(:z, nothing),))
    )
end

@testitem "FactorizationConstraint" begin
    import GraphPPL: FactorizationConstraint, FactorizationConstraintEntry, IndexedVariable, FunctionalIndex, CombinedRange, SplittedRange

    # Test 1: Test FactorizationConstraint with single variables
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))),)
    ) isa Any
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing),)), FactorizationConstraintEntry((IndexedVariable(:y, nothing),)))
    ) isa Any
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)), (FactorizationConstraintEntry((IndexedVariable(:x, nothing),)),)
    )
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, nothing),), (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))),)
    )

    # Test 2: Test FactorizationConstraint with indexed variables
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, 1), IndexedVariable(:y, 1))),)
    ) isa Any
    @test FactorizationConstraint(
        (IndexedVariable(:x, 1), IndexedVariable(:y, 1)),
        (FactorizationConstraintEntry((IndexedVariable(:x, 1),)), FactorizationConstraintEntry((IndexedVariable(:y, 1),)))
    ) isa FactorizationConstraint
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, 1), IndexedVariable(:y, 1)), (FactorizationConstraintEntry((IndexedVariable(:x, 1),)),)
    )
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, 1),), (FactorizationConstraintEntry((IndexedVariable(:x, 1), IndexedVariable(:y, 1))),)
    )

    # Test 3: Test FactorizationConstraint with SplittedRanges
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing),),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
            )),
        )
    ) isa FactorizationConstraint
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, nothing),),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, SplittedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
                IndexedVariable(:y, nothing)
            )),
        )
    )

    # Test 4: Test FactorizationConstraint with CombinedRanges
    @test FactorizationConstraint(
        (IndexedVariable(:x, nothing),),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, CombinedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
            )),
        )
    ) isa FactorizationConstraint
    @test_throws ErrorException FactorizationConstraint(
        (IndexedVariable(:x, nothing)),
        (
            FactorizationConstraintEntry((
                IndexedVariable(:x, CombinedRange(FunctionalIndex{:begin}(firstindex), FunctionalIndex{:end}(lastindex))),
                IndexedVariable(:y, nothing)
            )),
        )
    )

    # Test 5: Test FactorizationConstraint  with duplicate entries
    @test_throws ErrorException constraint = FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing), IndexedVariable(:out, nothing)),
        (
            FactorizationConstraintEntry((IndexedVariable(:x, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:x, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:y, nothing),)),
            FactorizationConstraintEntry((IndexedVariable(:out, nothing),))
        )
    )
end

@testitem "multiply(::FactorizationConstraintEntry, ::FactorizationConstraintEntry)" begin
    import GraphPPL: FactorizationConstraintEntry, IndexedVariable

    entry = FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)))
    global x = entry
    for i in 1:3
        global x = x * x
        @test x == Tuple([entry for _ in 1:(2^i)])
    end
end

@testitem "push!(::Constraints, ::Constraint)" begin
    using Distributions
    import GraphPPL:
        Constraints,
        Constraint,
        FactorizationConstraint,
        FactorizationConstraintEntry,
        PosteriorFormConstraint,
        MessageFormConstraint,
        SpecificSubModelConstraints,
        GeneralSubModelConstraints,
        IndexedVariable,
        FactorID

    # Test 1: Test push! with FactorizationConstraint
    constraints = Constraints()
    constraint = FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),),)
    )
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = FactorizationConstraint(
        (IndexedVariable(:x, 1), IndexedVariable(:y, 1)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))),)
    )
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = FactorizationConstraint(
        (IndexedVariable(:y, nothing), IndexedVariable(:x, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))),)
    )
    @test_throws ErrorException push!(constraints, constraint)

    # Test 2: Test push! with PosteriorFormConstraint
    constraint = PosteriorFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = PosteriorFormConstraint((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = PosteriorFormConstraint(IndexedVariable(:x, 1), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = PosteriorFormConstraint([IndexedVariable(:x, 1), IndexedVariable(:y, 1)], Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)

    # Test 3: Test push! with MessageFormConstraint
    constraint = MessageFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
    constraint = MessageFormConstraint(IndexedVariable(:x, 2), Normal)
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)

    # Test 4: Test push! with SpecificSubModelConstraints
    constraint = SpecificSubModelConstraints(FactorID(sum, 3), Constraints())
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)

    # Test 5: Test push! with GeneralSubModelConstraints
    constraint = GeneralSubModelConstraints(sum, Constraints())
    push!(constraints, constraint)
    @test_throws ErrorException push!(constraints, constraint)
end

@testitem "push!(::SubModelConstraints, c::Constraint)" begin
    import GraphPPL:
        Constraint,
        GeneralSubModelConstraints,
        SpecificSubModelConstraints,
        FactorizationConstraint,
        FactorizationConstraintEntry,
        PosteriorFormConstraint,
        MessageFormConstraint,
        getconstraint,
        Constraints,
        IndexedVariable

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    # Test 1: Test push! with FactorizationConstraint
    constraints = GeneralSubModelConstraints(gcv)
    constraint = FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))),)
    )
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([
        FactorizationConstraint(
            (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
            (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),),)
        )
    ],)
    @test_throws MethodError push!(constraints, "string")

    # Test 2: Test push! with PosteriorFormConstraint
    constraints = GeneralSubModelConstraints(gcv)
    constraint = PosteriorFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([PosteriorFormConstraint(IndexedVariable(:x, nothing), Normal)],)
    @test_throws MethodError push!(constraints, "string")

    # Test 3: Test push! with MessageFormConstraint
    constraints = GeneralSubModelConstraints(gcv)
    constraint = MessageFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([MessageFormConstraint(IndexedVariable(:x, nothing), Normal)],)
    @test_throws MethodError push!(constraints, "string")

    # Test 4: Test push! with SpecificSubModelConstraints
    constraints = SpecificSubModelConstraints(GraphPPL.FactorID(gcv, 3))
    constraint = FactorizationConstraint(
        (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
        (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing))),)
    )
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([
        FactorizationConstraint(
            (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
            (FactorizationConstraintEntry((IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),),)
        )
    ],)
    @test_throws MethodError push!(constraints, "string")

    # Test 5: Test push! with PosteriorFormConstraint
    constraints = GeneralSubModelConstraints(gcv)
    constraint = PosteriorFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([PosteriorFormConstraint(IndexedVariable(:x, nothing), Normal)],)
    @test_throws MethodError push!(constraints, "string")

    # Test 6: Test push! with MessageFormConstraint
    constraints = GeneralSubModelConstraints(gcv)
    constraint = MessageFormConstraint(IndexedVariable(:x, nothing), Normal)
    push!(constraints, constraint)
    @test getconstraint(constraints) == Constraints([MessageFormConstraint(IndexedVariable(:x, nothing), Normal)],)
    @test_throws MethodError push!(constraints, "string")
end

@testitem "is_factorized" begin
    import GraphPPL: is_factorized, create_model, getcontext, getproperties, getorcreate!, variable_nodes, NodeCreationOptions

    include("../../testutils.jl")

    m = create_test_model(plugins = GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin()))
    ctx = getcontext(m)

    x_1 = getorcreate!(m, ctx, NodeCreationOptions(factorized = true), :x_1, nothing)
    @test is_factorized(m[x_1])

    x_2 = getorcreate!(m, ctx, NodeCreationOptions(factorized = true), :x_2, nothing)
    @test is_factorized(m[x_2])

    x_3 = getorcreate!(m, ctx, NodeCreationOptions(factorized = true), :x_3, 1)
    @test is_factorized(m[x_3[1]])

    x_4 = getorcreate!(m, ctx, NodeCreationOptions(factorized = true), :x_4, 1)
    @test is_factorized(m[x_4[1]])

    x_5 = getorcreate!(m, ctx, NodeCreationOptions(factorized = true), :x_5, 1, 2)
    @test is_factorized(m[x_5[1, 2]])

    x_6 = getorcreate!(m, ctx, NodeCreationOptions(factorized = true), :x_6, 1, 2, 3)
    @test is_factorized(m[x_6[1, 2, 3]])
end

@testitem "is_factorized || is_constant" begin
    import GraphPPL:
        is_constant, is_factorized, create_model, with_plugins, getcontext, getproperties, getorcreate!, variable_nodes, NodeCreationOptions

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    m = create_test_model(plugins = GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin()))
    ctx = getcontext(m)
    x = getorcreate!(m, ctx, NodeCreationOptions(kind = :data, factorized = true), :x, nothing)
    @test is_factorized(m[x])

    for model_fn in ModelsInTheZooWithoutArguments
        model = create_model(with_plugins(model_fn(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
        for label in variable_nodes(model)
            nodedata = model[label]
            if is_constant(getproperties(nodedata))
                @test is_factorized(nodedata)
            else
                @test !is_factorized(nodedata)
            end
        end
    end
end

@testitem "Application of PosteriorFormConstraint" begin
    import GraphPPL: create_model, PosteriorFormConstraint, IndexedVariable, apply_constraints!, getextra, hasextra

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    struct ArbitraryFunctionalFormConstraint end

    # Test saving of PosteriorFormConstraint in single variable
    model = create_model(simple_model())
    context = GraphPPL.getcontext(model)
    constraint = PosteriorFormConstraint(IndexedVariable(:x, nothing), ArbitraryFunctionalFormConstraint())
    apply_constraints!(model, context, constraint)
    for node in filter(GraphPPL.as_variable(:x), model)
        @test getextra(model[node], :posterior_form_constraint) == ArbitraryFunctionalFormConstraint()
    end

    # Test saving of PosteriorFormConstraint in multiple variables
    model = create_model(vector_model())
    context = GraphPPL.getcontext(model)
    constraint = PosteriorFormConstraint(IndexedVariable(:x, nothing), ArbitraryFunctionalFormConstraint())
    apply_constraints!(model, context, constraint)
    for node in filter(GraphPPL.as_variable(:x), model)
        @test getextra(model[node], :posterior_form_constraint) == ArbitraryFunctionalFormConstraint()
    end
    for node in filter(GraphPPL.as_variable(:y), model)
        @test !hasextra(model[node], :posterior_form_constraint)
    end

    # Test saving of PosteriorFormConstraint in single variable in array
    model = create_model(vector_model())
    context = GraphPPL.getcontext(model)
    constraint = PosteriorFormConstraint(IndexedVariable(:x, 1), ArbitraryFunctionalFormConstraint())
    apply_constraints!(model, context, constraint)
    applied_node = context[:x][1]
    for node in filter(GraphPPL.as_variable(:x), model)
        if node == applied_node
            @test getextra(model[node], :posterior_form_constraint) == ArbitraryFunctionalFormConstraint()
        else
            @test !hasextra(model[node], :posterior_form_constraint)
        end
    end
end

@testitem "Application of MessageFormConstraint" begin
    import GraphPPL: create_model, MessageFormConstraint, IndexedVariable, apply_constraints!, hasextra, getextra

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    struct ArbitraryMessageFormConstraint end

    # Test saving of MessageFormConstraint in single variable
    model = create_model(simple_model())
    context = GraphPPL.getcontext(model)
    constraint = MessageFormConstraint(IndexedVariable(:x, nothing), ArbitraryMessageFormConstraint())
    node = first(filter(GraphPPL.as_variable(:x), model))
    apply_constraints!(model, context, constraint)
    @test getextra(model[node], :message_form_constraint) == ArbitraryMessageFormConstraint()

    # Test saving of MessageFormConstraint in multiple variables
    model = create_model(vector_model())
    context = GraphPPL.getcontext(model)
    constraint = MessageFormConstraint(IndexedVariable(:x, nothing), ArbitraryMessageFormConstraint())
    apply_constraints!(model, context, constraint)
    for node in filter(GraphPPL.as_variable(:x), model)
        @test getextra(model[node], :message_form_constraint) == ArbitraryMessageFormConstraint()
    end
    for node in filter(GraphPPL.as_variable(:y), model)
        @test !hasextra(model[node], :message_form_constraint)
    end

    # Test saving of MessageFormConstraint in single variable in array
    model = create_model(vector_model())
    context = GraphPPL.getcontext(model)
    constraint = MessageFormConstraint(IndexedVariable(:x, 1), ArbitraryMessageFormConstraint())
    apply_constraints!(model, context, constraint)
    applied_node = context[:x][1]
    for node in filter(GraphPPL.as_variable(:x), model)
        if node == applied_node
            @test getextra(model[node], :message_form_constraint) == ArbitraryMessageFormConstraint()
        else
            @test !hasextra(model[node], :message_form_constraint)
        end
    end
end

@testitem "save constraints with constants via `mean_field_constraint!`" begin
    using BitSetTuples
    import GraphPPL:
        create_model,
        with_plugins,
        getextra,
        mean_field_constraint!,
        getproperties,
        VariationalConstraintsPlugin,
        PluginsCollection,
        VariationalConstraintsFactorizationBitSetKey

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    model = create_model(with_plugins(simple_model(), GraphPPL.PluginsCollection(VariationalConstraintsPlugin())))
    ctx = GraphPPL.getcontext(model)

    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(3), 1)) == ((1,), (2, 3), (2, 3))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(3), 2)) == ((1, 3), (2,), (1, 3))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(3), 3)) == ((1, 2), (1, 2), (3,))

    node = ctx[NormalMeanVariance, 2]
    constraint_bitset = getextra(model[node], VariationalConstraintsFactorizationBitSetKey)
    @test tupled_contents(intersect!(constraint_bitset, mean_field_constraint!(BoundedBitSetTuple(3), 1))) == ((1,), (2, 3), (2, 3))
    @test tupled_contents(intersect!(constraint_bitset, mean_field_constraint!(BoundedBitSetTuple(3), 2))) == ((1,), (2,), (3,))

    node = ctx[NormalMeanVariance, 1]
    constraint_bitset = getextra(model[node], VariationalConstraintsFactorizationBitSetKey)
    # Here it is the mean field because the original model has `x ~ Normal(0, 1)` and `0` and `1` are constants 
    @test tupled_contents(intersect!(constraint_bitset, mean_field_constraint!(BoundedBitSetTuple(3), 1))) == ((1,), (2,), (3,))
end

@testitem "materialize_constraints!(:Model, ::NodeLabel, ::FactorNodeData)" begin
    using BitSetTuples
    import GraphPPL:
        create_model, with_plugins, materialize_constraints!, EdgeLabel, get_constraint_names, getproperties, getextra, setextra!

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    # Test 1: Test materialize with a Full Factorization constraint
    model = create_model(simple_model())
    ctx = GraphPPL.getcontext(model)
    node = ctx[NormalMeanVariance, 2]

    # Force overwrite the bitset and the constraints
    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(3))
    materialize_constraints!(model, node)
    @test Tuple.(getextra(model[node], :factorization_constraint_indices)) == ((1, 2, 3),)

    node = ctx[NormalMeanVariance, 1]
    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(((1,), (2,), (3,))))
    materialize_constraints!(model, node)
    @test Tuple.(getextra(model[node], :factorization_constraint_indices)) == ((1,), (2,), (3,))

    # Test 2: Test materialize with an applied constraint
    model = create_model(simple_model())
    ctx = GraphPPL.getcontext(model)
    node = ctx[NormalMeanVariance, 2]

    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(((1,), (2, 3), (2, 3))))
    materialize_constraints!(model, node)
    @test Tuple.(getextra(model[node], :factorization_constraint_indices)) == ((1,), (2, 3))

    # # Test 3: Check that materialize_constraints! throws if the constraint is not a valid partition
    model = create_model(simple_model())
    ctx = GraphPPL.getcontext(model)
    node = ctx[NormalMeanVariance, 2]

    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(((1,), (3,), (1, 3))))
    @test_throws ErrorException materialize_constraints!(model, node)

    # Test 4: Check that materialize_constraints! throws if the constraint is not a valid partition
    model = create_model(simple_model())
    ctx = GraphPPL.getcontext(model)
    node = ctx[NormalMeanVariance, 2]

    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(((1,), (1,), (3,))))
    @test_throws ErrorException materialize_constraints!(model, node)
end

@testitem "Resolve Factorization Constraints" begin
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
        SplittedRange

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    model = create_model(outer())
    ctx = GraphPPL.getcontext(model)
    inner_context = ctx[inner, 1]

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

    model = create_terminated_model(filled_matrix_model)
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
    model = create_terminated_model(filled_matrix_model)
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

    model = create_terminated_model(uneven_matrix)
    ctx = GraphPPL.getcontext(model)
    let constraint = GraphPPL.FactorizationConstraint(
            (IndexedVariable(:prec, [1, 3]), IndexedVariable(:y, nothing)),
            (FactorizationConstraintEntry((IndexedVariable(:prec, [1, 3]),)), FactorizationConstraintEntry((IndexedVariable(:y, nothing),)))
        )
        result = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((
                ResolvedIndexedVariable(:prec, 3, ctx), ResolvedIndexedVariable(:y, CombinedRange(1, 10), ctx)
            ),),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:prec, 3, ctx),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, CombinedRange(1, 10), ctx),))
            )
        )
        @test resolve(model, ctx, constraint) == result
    end

    model = create_terminated_model(uneven_matrix)
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
    insert!(
        context.vector_variables,
        :w,
        ResizableArray([NodeLabel(:w, 1), NodeLabel(:w, 2), NodeLabel(:w, 3), NodeLabel(:w, 4), NodeLabel(:w, 5)])
    )

    insert!(
        context.tensor_variables,
        :prec,
        ResizableArray([[NodeLabel(:prec, 1), NodeLabel(:prec, 2), NodeLabel(:prec, 3)], [NodeLabel(:prec, 4), NodeLabel(:prec, 5), NodeLabel(:prec, 6)]])
    )

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

@testitem "convert_to_bitsets" begin
    using BitSetTuples
    import GraphPPL:
        create_model,
        with_plugins,
        ResolvedFactorizationConstraint,
        ResolvedConstraintLHS,
        ResolvedFactorizationConstraintEntry,
        ResolvedIndexedVariable,
        SplittedRange,
        CombinedRange,
        apply_constraints!,
        getproperties

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    model = create_model(with_plugins(outer(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
    context = GraphPPL.getcontext(model)
    inner_context = context[inner, 1]
    inner_inner_context = inner_context[inner_inner, 1]

    normal_node = inner_inner_context[NormalMeanVariance, 1]
    neighbors = model[GraphPPL.neighbors(model, normal_node)]

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:w, 2:3, context),)),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, 2, context),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, 3, context),))
            )
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
        @test tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1, 2, 3), (1, 2), (1, 3))
    end

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:w, 4:5, context),)),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, 4, context),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, 5, context),))
            )
        )
        @test !GraphPPL.is_applicable(neighbors, constraint)
    end

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:w, 2:3, context),)),
            (ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, SplittedRange(2, 3), context),)),)
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
        @test tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1, 2, 3), (1, 2), (1, 3))
    end

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:w, 2:3, context), ResolvedIndexedVariable(:y, nothing, context))),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, SplittedRange(2, 3), context),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, nothing, context),))
            )
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
        @test tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1,), (2,), (3,))
    end

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:w, 2:3, context), ResolvedIndexedVariable(:y, nothing, context))),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, 2, context),)),
                ResolvedFactorizationConstraintEntry((
                    ResolvedIndexedVariable(:w, 3, context), ResolvedIndexedVariable(:y, nothing, context)
                ))
            )
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
        @test tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1, 3), (2,), (1, 3))
    end

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:w, 2:3, context), ResolvedIndexedVariable(:y, nothing, context))),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, CombinedRange(2, 3), context),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, nothing, context),))
            )
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
        @test tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1,), (2, 3), (2, 3))
    end

    model = create_model(with_plugins(multidim_array(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
    context = GraphPPL.getcontext(model)
    normal_node = context[NormalMeanVariance, 5]
    neighbors = model[GraphPPL.neighbors(model, normal_node)]

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:x, nothing, context),),),
            (ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:x, SplittedRange(1, 9), context),)),)
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
        @test tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1, 3), (2, 3), (1, 2, 3))
    end

    model = create_model(with_plugins(multidim_array(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
    context = GraphPPL.getcontext(model)
    normal_node = context[NormalMeanVariance, 5]
    neighbors = model[GraphPPL.neighbors(model, normal_node)]

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:x, nothing, context),),),
            (ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:x, CombinedRange(1, 9), context),)),)
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
        @test tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1, 2, 3), (1, 2, 3), (1, 2, 3))
    end

    # Test ResolvedFactorizationConstraints over anonymous variables

    model = create_model(with_plugins(node_with_only_anonymous(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
    context = GraphPPL.getcontext(model)
    normal_node = context[NormalMeanVariance, 6]
    neighbors = model[GraphPPL.neighbors(model, normal_node)]
    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:y, nothing, context),),),
            (ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, SplittedRange(1, 10), context),)),)
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
    end

    # Test ResolvedFactorizationConstraints over multiple anonymous variables
    model = create_model(with_plugins(node_with_two_anonymous(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
    context = GraphPPL.getcontext(model)
    normal_node = context[NormalMeanVariance, 6]
    neighbors = model[GraphPPL.neighbors(model, normal_node)]
    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:y, nothing, context),),),
            (ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, SplittedRange(1, 10), context),)),)
        )
        @test GraphPPL.is_applicable(neighbors, constraint)

        # This shouldn't throw and resolve because both anonymous variables are 1-to-1 and referenced by constraint.
        @test tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1, 2, 3), (1, 2), (1, 3))
    end

    # Test ResolvedFactorizationConstraints over ambiguous anonymouys variables
    model = create_model(with_plugins(node_with_ambiguous_anonymous(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
    context = GraphPPL.getcontext(model)
    normal_node = last(filter(GraphPPL.as_node(NormalMeanVariance), model))
    neighbors = model[GraphPPL.neighbors(model, normal_node)]
    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:y, nothing, context),),),
            (ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, SplittedRange(1, 10), context),)),)
        )
        @test GraphPPL.is_applicable(neighbors, constraint)

        # This test should throw since we cannot resolve the constraint
        @test_throws ErrorException GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)
    end

    # Test ResolvedFactorizationConstraint with a Mixture node
    model = create_model(with_plugins(mixture(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
    context = GraphPPL.getcontext(model)
    mixture_node = first(filter(GraphPPL.as_node(Mixture), model))
    neighbors = model[GraphPPL.neighbors(model, mixture_node)]
    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((
                ResolvedIndexedVariable(:m1, nothing, context),
                ResolvedIndexedVariable(:m2, nothing, context),
                ResolvedIndexedVariable(:m3, nothing, context),
                ResolvedIndexedVariable(:m4, nothing, context)
            ),),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:m1, nothing, context),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:m2, nothing, context),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:m3, nothing, context),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:m4, nothing, context),))
            )
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
        @test tupled_contents(GraphPPL.convert_to_bitsets(model, mixture_node, neighbors, constraint)) == tupled_contents(
            BitSetTuple([
                collect(1:9),
                [1, 2, 6, 7, 8, 9],
                [1, 3, 6, 7, 8, 9],
                [1, 4, 6, 7, 8, 9],
                [1, 5, 6, 7, 8, 9],
                collect(1:9),
                collect(1:9),
                collect(1:9),
                collect(1:9)
            ])
        )
    end
end

@testitem "lazy_bool_allequal" begin
    import GraphPPL: lazy_bool_allequal

    @testset begin
        itr = [1, 2, 3, 4]

        outcome, value = lazy_bool_allequal(x -> x > 0, itr)
        @test outcome === true
        @test value === true

        outcome, value = lazy_bool_allequal(x -> x < 0, itr)
        @test outcome === true
        @test value === false
    end

    @testset begin
        itr = [1, 2, -1, -2]

        outcome, value = lazy_bool_allequal(x -> x > 0, itr)
        @test outcome === false
        @test value === true

        outcome, value = lazy_bool_allequal(x -> x < 0, itr)
        @test outcome === false
        @test value === false
    end

    @testset begin
        # We do not support it for now, but we can add it in the future
        @test_throws ErrorException lazy_bool_allequal(x -> x > 0, [])
    end
end

@testitem "default_constraints" begin
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

    include("../../testutils.jl")

    using .TestUtils.ModelZoo

    @test default_constraints(simple_model) == UnspecifiedConstraints
    @test default_constraints(model_with_default_constraints) == @constraints(
        begin
            q(a, d) = q(a)q(d)
        end
    )

    model = create_model(with_plugins(contains_default_constraints(), PluginsCollection(VariationalConstraintsPlugin())))
    ctx = GraphPPL.getcontext(model)
    # Test that default constraints are applied
    for i in 1:10
        node = model[ctx[model_with_default_constraints, i][NormalMeanVariance, 1]]
        @test hasextra(node, :factorization_constraint_indices)
        @test Tuple.(getextra(node, :factorization_constraint_indices)) == ((1,), (2,), (3,))
    end

    # Test that default constraints are not applied if we specify constraints in the context
    c = @constraints begin
        for q in model_with_default_constraints
            q(a, d) = q(a, d)
        end
    end
    model = create_model(with_plugins(contains_default_constraints(), PluginsCollection(VariationalConstraintsPlugin(c))))
    ctx = GraphPPL.getcontext(model)
    for i in 1:10
        node = model[ctx[model_with_default_constraints, i][NormalMeanVariance, 1]]
        @test hasextra(node, :factorization_constraint_indices)
        @test Tuple.(getextra(node, :factorization_constraint_indices)) == ((1, 2), (3,))
    end

    # Test that default constraints are not applied if we specify constraints for a specific instance of the submodel
    c = @constraints begin
        for q in (model_with_default_constraints, 1)
            q(a, d) = q(a, d)
        end
    end
    model = create_model(with_plugins(contains_default_constraints(), PluginsCollection(VariationalConstraintsPlugin(c))))
    ctx = GraphPPL.getcontext(model)
    for i in 1:10
        node = model[ctx[model_with_default_constraints, i][NormalMeanVariance, 1]]
        @test hasextra(node, :factorization_constraint_indices)
        if i == 1
            @test Tuple.(getextra(node, :factorization_constraint_indices)) == ((1, 2), (3,))
        else
            @test Tuple.(getextra(node, :factorization_constraint_indices)) == ((1,), (2,), (3,))
        end
    end
end

@testitem "mean_field_constraint!" begin
    using BitSetTuples
    import GraphPPL: mean_field_constraint!

    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(5))) == ((1,), (2,), (3,), (4,), (5,))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(10))) == ((1,), (2,), (3,), (4,), (5,), (6,), (7,), (8,), (9,), (10,))

    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(1), 1)) == ((1,),)
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(5), 3)) ==
        ((1, 2, 4, 5), (1, 2, 4, 5), (3,), (1, 2, 4, 5), (1, 2, 4, 5))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(1), (1,))) == ((1,),)
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(2), (1,))) == ((1,), (2,))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(2), (2,))) == ((1,), (2,))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(5), (1, 2))) == ((1,), (2,), (3, 4, 5), (3, 4, 5), (3, 4, 5))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(5), (1, 3, 5))) == ((1,), (2, 4), (3,), (2, 4), (5,))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(5), (1, 2, 3, 4, 5))) == ((1,), (2,), (3,), (4,), (5,))
    @test_throws BoundsError mean_field_constraint!(BoundedBitSetTuple(5), (1, 2, 3, 4, 5, 6)) == ((1,), (2,), (3,), (4,), (5,))
end

@testitem "Apply constraints to matrix variables" begin
    import GraphPPL: getproperties, PluginsCollection, VariationalConstraintsPlugin, getextra, getcontext

    include("../../model_zoo.jl")

    # Test for constraints applied to a model with matrix variables
    c = @constraints begin
        q(x, y) = q(x)q(y)
    end
    model = create_terminated_model(filled_matrix_model; plugins = PluginsCollection(VariationalConstraintsPlugin(c)))

    for node in filter(as_node(Normal), model)
        @test getextra(model[node], :factorization_constraint_indices) == ([1], [2], [3])
    end

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
    constraints_1 = @constraints begin
        q(prec, y) = q(prec)q(y)
    end

    model = create_terminated_model(uneven_matrix; plugins = PluginsCollection(VariationalConstraintsPlugin(constraints_1)))
    for node in filter(as_node(Normal), model)
        @test getextra(model[node], :factorization_constraint_indices) == ([1], [2], [3])
    end

    constraints_2 = @constraints begin
        q(prec[1], y) = q(prec[1])q(y)
    end

    model = create_terminated_model(uneven_matrix; plugins = PluginsCollection(VariationalConstraintsPlugin(constraints_2)))
    ctx = getcontext(model)
    for node in filter(as_node(Normal), model)
        if any(x -> x ∈ GraphPPL.neighbors(model, node), ctx[:prec][1])
            @test getextra(model[node], :factorization_constraint_indices) == ([1], [2], [3])
        else
            @test getextra(model[node], :factorization_constraint_indices) == ([1, 3], [2])
        end
    end

    constraints_3 = @constraints begin
        q(prec[2], y) = q(prec[2])q(y)
    end

    model = create_terminated_model(uneven_matrix; plugins = PluginsCollection(VariationalConstraintsPlugin(constraints_3)))
    ctx = getcontext(model)
    for node in filter(as_node(Normal), model)
        if any(x -> x ∈ GraphPPL.neighbors(model, node), ctx[:prec][2])
            @test getextra(model[node], :factorization_constraint_indices) == ([1], [2], [3])
        else
            @test getextra(model[node], :factorization_constraint_indices) == ([1, 3], [2])
        end
    end

    constraints_4 = @constraints begin
        q(prec[1, 3], y) = q(prec[1, 3])q(y)
    end
    model = create_terminated_model(uneven_matrix; plugins = PluginsCollection(VariationalConstraintsPlugin(constraints_4)))
    ctx = getcontext(model)
    for node in filter(as_node(Normal), model)
        if ctx[:prec][1, 3] ∈ GraphPPL.neighbors(model, node)
            @test getextra(model[node], :factorization_constraint_indices) == ([1], [2], [3])
        else
            @test getextra(model[node], :factorization_constraint_indices) == ([1, 3], [2])
        end
    end

    constraints_5 = @constraints begin
        q(prec, y) = q(prec[(1,1):(3, 3)])q(y)
    end
    @test_throws GraphPPL.Graphs.NotImplementedError model = create_terminated_model(uneven_matrix; plugins = PluginsCollection(VariationalConstraintsPlugin(constraints_5)))
end
