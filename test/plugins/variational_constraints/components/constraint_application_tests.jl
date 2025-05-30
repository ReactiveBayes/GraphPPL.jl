@testitem "is_factorized" setup = [TestUtils] begin
    import GraphPPL: is_factorized, AbstractNodeData, AbstractNodeProperties, getproperties, getlink

    mutable struct MockNodeData{T} <: AbstractNodeData
        properties::T
        extras::Dict{Symbol, Any}
    end

    # Mock implementation to test pure functions without requiring model setup
    struct MockVariableNodeProperties <: AbstractNodeProperties
        is_constant::Bool
        link::Union{Nothing, Vector{MockNodeData}}
    end

    Base.getproperty(p::MockVariableNodeProperties, name::Symbol) =
        if name === :link
            getfield(p, :link)
        else
            getfield(p, name)
        end

    getproperties(data::MockNodeData) = data.properties
    GraphPPL.getextra(data::MockNodeData, key::Symbol) = get(data.extras, key, nothing)
    GraphPPL.hasextra(data::MockNodeData, key::Symbol) = haskey(data.extras, key)
    GraphPPL.getlink(props::MockVariableNodeProperties) = props.link
    GraphPPL.is_constant(props::MockVariableNodeProperties) = props.is_constant
    # Test 1: Basic constant variable
    node1_props = MockVariableNodeProperties(true, nothing)
    node1 = MockNodeData{MockVariableNodeProperties}(node1_props, Dict{Symbol, Any}())
    @test is_factorized(node1)

    # Test 2: Variable with factorized flag
    node2_props = MockVariableNodeProperties(false, nothing)
    node2 = MockNodeData{MockVariableNodeProperties}(node2_props, Dict{Symbol, Any}(:factorized => true))
    @test is_factorized(node2)

    # Test 3: Variable without factorized flag
    node3_props = MockVariableNodeProperties(false, nothing)
    node3 = MockNodeData{MockVariableNodeProperties}(node3_props, Dict{Symbol, Any}())
    @test !is_factorized(node3)

    # Test 4: Variable with factorized links
    node4_link1_props = MockVariableNodeProperties(true, nothing)
    node4_link1 = MockNodeData{MockVariableNodeProperties}(node4_link1_props, Dict{Symbol, Any}())
    node4_link2_props = MockVariableNodeProperties(false, nothing)
    node4_link2 = MockNodeData{MockVariableNodeProperties}(node4_link2_props, Dict{Symbol, Any}(:factorized => true))
    node4_links = [node4_link1, node4_link2]
    node4_props = MockVariableNodeProperties(false, node4_links)
    node4 = MockNodeData{MockVariableNodeProperties}(node4_props, Dict{Symbol, Any}())
    @test is_factorized(node4)

    # Test 5: Variable with non-factorized links
    node5_link1_props = MockVariableNodeProperties(true, nothing)
    node5_link1 = MockNodeData{MockVariableNodeProperties}(node5_link1_props, Dict{Symbol, Any}())
    node5_link2_props = MockVariableNodeProperties(false, nothing)
    node5_link2 = MockNodeData{MockVariableNodeProperties}(node5_link2_props, Dict{Symbol, Any}())
    node5_links = [node5_link1, node5_link2]
    node5_props = MockVariableNodeProperties(false, node5_links)
    node5 = MockNodeData{MockVariableNodeProperties}(node5_props, Dict{Symbol, Any}())
    @test !is_factorized(node5)

    # Test 6: Variable with mixed factorized/non-factorized links
    node6_link1_props = MockVariableNodeProperties(true, nothing)
    node6_link1 = MockNodeData{MockVariableNodeProperties}(node6_link1_props, Dict{Symbol, Any}())
    node6_link2_props = MockVariableNodeProperties(false, nothing)
    node6_link2 = MockNodeData{MockVariableNodeProperties}(node6_link2_props, Dict{Symbol, Any}())
    node6_links = [node6_link1, node6_link2]
    node6_props = MockVariableNodeProperties(false, node6_links)
    node6 = MockNodeData{MockVariableNodeProperties}(node6_props, Dict{Symbol, Any}())
    @test !is_factorized(node6)
end

@testitem "is_factorized || is_constant" setup = [TestUtils] begin
    import GraphPPL:
        is_constant, is_factorized, create_model, with_plugins, getcontext, getproperties, getorcreate!, variable_nodes, NodeCreationOptions

    m = TestUtils.create_test_model(plugins = GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin()))
    ctx = getcontext(m)
    x = getorcreate!(m, ctx, NodeCreationOptions(kind = :data, factorized = true), :x, nothing)
    @test is_factorized(m[x])

    for model_fn in TestUtils.ModelsInTheZooWithoutArguments
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

@testitem "mean_field_constraint!" setup = [TestUtils] begin
    import GraphPPL: mean_field_constraint!, BoundedBitSetTuple, contents

    # Test 1: Basic mean field constraint
    bitset = BoundedBitSetTuple(3)
    fill!(contents(bitset), true)

    mean_field_constraint!(bitset)
    for i in 1:3
        for j in 1:3
            if i == j
                @test bitset[i, j]
            else
                @test !bitset[i, j]
            end
        end
    end

    # Test 2: Mean field constraint with specific index
    bitset = BoundedBitSetTuple(3)
    fill!(contents(bitset), true)

    mean_field_constraint!(bitset, 2)
    # Check that row/column 2 is all zeros except for [2,2]
    for i in 1:3
        for j in 1:3
            if i == 2 && j == 2
                @test bitset[i, j]
            elseif i == 2 || j == 2
                @test !bitset[i, j]
            else
                @test bitset[i, j]
            end
        end
    end

    # Test 3: Mean field constraint with multiple indices
    bitset = BoundedBitSetTuple(4)
    fill!(contents(bitset), true)

    mean_field_constraint!(bitset, (1, 3))
    for i in 1:4
        for j in 1:4
            if (i == 1 && j == 1) || (i == 3 && j == 3)
                @test bitset[i, j]
            elseif i == 1 || j == 1 || i == 3 || j == 3
                @test !bitset[i, j]
            else
                @test bitset[i, j]
            end
        end
    end
end

@testitem "is_valid_partition" setup = [TestUtils] begin
    import GraphPPL: is_valid_partition

    # Test valid partitions
    valid1 = [[1, 0, 0], [0, 1, 1]]
    @test is_valid_partition(valid1)

    valid2 = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    @test is_valid_partition(valid2)

    # Test invalid partitions

    # Element missing from any partition
    invalid1 = [[1, 0, 0], [0, 1, 0]]
    @test !is_valid_partition(invalid1)

    # Element in multiple partitions
    invalid2 = [[1, 1, 0], [0, 1, 1]]
    @test !is_valid_partition(invalid2)

    # Empty partition set
    invalid3 = Vector{Int}[]
    @test_broken !is_valid_partition(invalid3)
end

@testitem "materialize_is_factorized_neighbors!" setup = [TestUtils] begin
    import GraphPPL: materialize_is_factorized_neighbors!, BoundedBitSetTuple, NodeData, is_factorized, AbstractNodeData

    # Mock implementation
    mutable struct MockNodeData <: AbstractNodeData
        factorized::Bool
    end

    GraphPPL.is_factorized(n::MockNodeData) = n.factorized

    # Test 1: All factorized neighbors
    bitset = BoundedBitSetTuple(3)
    fill!(bitset.contents, true)
    neighbors = [MockNodeData(true), MockNodeData(true), MockNodeData(true)]

    materialize_is_factorized_neighbors!(bitset, neighbors)
    for i in 1:3
        for j in 1:3
            if i == j
                @test bitset[i, j]
            else
                @test !bitset[i, j]
            end
        end
    end

    # Test 2: Mixed factorized/non-factorized neighbors
    bitset = BoundedBitSetTuple(3)
    fill!(bitset.contents, true)
    neighbors = [MockNodeData(true), MockNodeData(false), MockNodeData(true)]

    materialize_is_factorized_neighbors!(bitset, neighbors)
    for i in 1:3
        for j in 1:3
            if (i == j) || (i != 1 && i != 3 && j != 1 && j != 3)
                @test bitset[i, j]
            elseif (i == 1 || i == 3 || j == 1 || j == 3) && i != j
                @test !bitset[i, j]
            end
        end
    end

    # Test 3: No factorized neighbors
    bitset = BoundedBitSetTuple(3)
    fill!(bitset.contents, true)
    neighbors = [MockNodeData(false), MockNodeData(false), MockNodeData(false)]

    materialize_is_factorized_neighbors!(bitset, neighbors)
    for i in 1:3
        for j in 1:3
            @test bitset[i, j]
        end
    end
end

@testitem "convert_to_bitsets" setup = [TestUtils] begin
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

    model = create_model(with_plugins(TestUtils.outer(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
    context = GraphPPL.getcontext(model)
    inner_context = context[TestUtils.inner, 1]
    inner_inner_context = inner_context[TestUtils.inner_inner, 1]

    normal_node = inner_inner_context[TestUtils.NormalMeanVariance, 1]
    neighbors = model[GraphPPL.neighbors(model, normal_node)]

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:w, 2:3, context),)),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, 2, context),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, 3, context),))
            )
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
        @test_broken tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1, 2, 3), (1, 2), (1, 3))
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
        @test_broken tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1, 2, 3), (1, 2), (1, 3))
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
        @test_broken tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1, 3), (2,), (1, 3))
    end

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:w, 2:3, context), ResolvedIndexedVariable(:y, nothing, context))),
            (
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:w, CombinedRange(2, 3), context),)),
                ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, nothing, context),))
            )
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
        @test_broken tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1,), (2, 3), (2, 3))
    end

    model = create_model(with_plugins(TestUtils.multidim_array(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
    context = GraphPPL.getcontext(model)
    normal_node = context[TestUtils.NormalMeanVariance, 5]
    neighbors = model[GraphPPL.neighbors(model, normal_node)]

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:x, nothing, context),),),
            (ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:x, SplittedRange(1, 9), context),)),)
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
        @test tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1, 3), (2, 3), (1, 2, 3))
    end

    model = create_model(with_plugins(TestUtils.multidim_array(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
    context = GraphPPL.getcontext(model)
    normal_node = context[TestUtils.NormalMeanVariance, 5]
    neighbors = model[GraphPPL.neighbors(model, normal_node)]

    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:x, nothing, context),),),
            (ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:x, CombinedRange(1, 9), context),)),)
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
        @test tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1, 2, 3), (1, 2, 3), (1, 2, 3))
    end

    # Test ResolvedFactorizationConstraints over anonymous variables

    model = create_model(
        with_plugins(TestUtils.node_with_only_anonymous(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin()))
    )
    context = GraphPPL.getcontext(model)
    normal_node = context[TestUtils.NormalMeanVariance, 6]
    neighbors = model[GraphPPL.neighbors(model, normal_node)]
    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:y, nothing, context),),),
            (ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, SplittedRange(1, 10), context),)),)
        )
        @test GraphPPL.is_applicable(neighbors, constraint)
    end

    # Test ResolvedFactorizationConstraints over multiple anonymous variables
    model = create_model(
        with_plugins(TestUtils.node_with_two_anonymous(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin()))
    )
    context = GraphPPL.getcontext(model)
    normal_node = context[TestUtils.NormalMeanVariance, 6]
    neighbors = model[GraphPPL.neighbors(model, normal_node)]
    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:y, nothing, context),),),
            (ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, SplittedRange(1, 10), context),)),)
        )
        @test GraphPPL.is_applicable(neighbors, constraint)

        # This shouldn't throw and resolve because both anonymous variables are 1-to-1 and referenced by constraint.
        @test_broken tupled_contents(GraphPPL.convert_to_bitsets(model, normal_node, neighbors, constraint)) == ((1, 2, 3), (1, 2), (1, 3))
    end

    # Test ResolvedFactorizationConstraints over ambiguous anonymouys variables
    model = create_model(
        with_plugins(TestUtils.node_with_ambiguous_anonymous(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin()))
    )
    context = GraphPPL.getcontext(model)
    normal_node = last(filter(GraphPPL.as_node(TestUtils.NormalMeanVariance), model))
    neighbors = model[GraphPPL.neighbors(model, normal_node)]
    let constraint = ResolvedFactorizationConstraint(
            ResolvedConstraintLHS((ResolvedIndexedVariable(:y, nothing, context),),),
            (ResolvedFactorizationConstraintEntry((ResolvedIndexedVariable(:y, SplittedRange(1, 10), context),)),)
        )
        @test GraphPPL.is_applicable(neighbors, constraint)

        # This test should throw since we cannot resolve the constraint
        @test_throws GraphPPL.UnresolvableFactorizationConstraintError GraphPPL.convert_to_bitsets(
            model, normal_node, neighbors, constraint
        )
    end

    # Test ResolvedFactorizationConstraint with a Mixture node
    model = create_model(with_plugins(TestUtils.mixture(), GraphPPL.PluginsCollection(GraphPPL.VariationalConstraintsPlugin())))
    context = GraphPPL.getcontext(model)
    mixture_node = first(filter(GraphPPL.as_node(TestUtils.Mixture), model))
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
        @test_broken tupled_contents(GraphPPL.convert_to_bitsets(model, mixture_node, neighbors, constraint)) == tupled_contents(
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

@testitem "Application of MarginalFormConstraint" setup = [TestUtils] begin
    import GraphPPL:
        create_model,
        MarginalFormConstraint,
        IndexedVariable,
        apply_constraints!,
        getextra,
        hasextra,
        VariationalConstraintsMarginalFormConstraintKey

    struct ArbitraryFunctionalFormConstraint end

    # Test saving of MarginalFormConstraint in single variable
    model = create_model(TestUtils.simple_model())
    context = GraphPPL.getcontext(model)
    constraint = MarginalFormConstraint(IndexedVariable(:x, nothing), ArbitraryFunctionalFormConstraint())
    apply_constraints!(model, context, constraint)
    for node in filter(GraphPPL.as_variable(:x), model)
        @test getextra(model[node], VariationalConstraintsMarginalFormConstraintKey) == ArbitraryFunctionalFormConstraint()
    end

    # Test saving of MarginalFormConstraint in multiple variables
    model = create_model(TestUtils.vector_model())
    context = GraphPPL.getcontext(model)
    constraint = MarginalFormConstraint(IndexedVariable(:x, nothing), ArbitraryFunctionalFormConstraint())
    apply_constraints!(model, context, constraint)
    for node in filter(GraphPPL.as_variable(:x), model)
        @test getextra(model[node], VariationalConstraintsMarginalFormConstraintKey) == ArbitraryFunctionalFormConstraint()
    end
    for node in filter(GraphPPL.as_variable(:y), model)
        @test !hasextra(model[node], VariationalConstraintsMarginalFormConstraintKey)
    end

    # Test saving of MarginalFormConstraint in single variable in array
    model = create_model(TestUtils.vector_model())
    context = GraphPPL.getcontext(model)
    constraint = MarginalFormConstraint(IndexedVariable(:x, 1), ArbitraryFunctionalFormConstraint())
    apply_constraints!(model, context, constraint)
    applied_node = context[:x][1]
    for node in filter(GraphPPL.as_variable(:x), model)
        if node == applied_node
            @test getextra(model[node], VariationalConstraintsMarginalFormConstraintKey) == ArbitraryFunctionalFormConstraint()
        else
            @test !hasextra(model[node], VariationalConstraintsMarginalFormConstraintKey)
        end
    end
end

@testitem "Application of MessageFormConstraint" setup = [TestUtils] begin
    import GraphPPL:
        create_model,
        MessageFormConstraint,
        IndexedVariable,
        apply_constraints!,
        hasextra,
        getextra,
        VariationalConstraintsMessagesFormConstraintKey

    struct ArbitraryMessageFormConstraint end

    # Test saving of MessageFormConstraint in single variable
    model = create_model(TestUtils.simple_model())
    context = GraphPPL.getcontext(model)
    constraint = MessageFormConstraint(IndexedVariable(:x, nothing), ArbitraryMessageFormConstraint())
    node = first(filter(GraphPPL.as_variable(:x), model))
    apply_constraints!(model, context, constraint)
    @test getextra(model[node], VariationalConstraintsMessagesFormConstraintKey) == ArbitraryMessageFormConstraint()

    # Test saving of MessageFormConstraint in multiple variables
    model = create_model(TestUtils.vector_model())
    context = GraphPPL.getcontext(model)
    constraint = MessageFormConstraint(IndexedVariable(:x, nothing), ArbitraryMessageFormConstraint())
    apply_constraints!(model, context, constraint)
    for node in filter(GraphPPL.as_variable(:x), model)
        @test getextra(model[node], VariationalConstraintsMessagesFormConstraintKey) == ArbitraryMessageFormConstraint()
    end
    for node in filter(GraphPPL.as_variable(:y), model)
        @test !hasextra(model[node], VariationalConstraintsMessagesFormConstraintKey)
    end

    # Test saving of MessageFormConstraint in single variable in array
    model = create_model(TestUtils.vector_model())
    context = GraphPPL.getcontext(model)
    constraint = MessageFormConstraint(IndexedVariable(:x, 1), ArbitraryMessageFormConstraint())
    apply_constraints!(model, context, constraint)
    applied_node = context[:x][1]
    for node in filter(GraphPPL.as_variable(:x), model)
        if node == applied_node
            @test getextra(model[node], VariationalConstraintsMessagesFormConstraintKey) == ArbitraryMessageFormConstraint()
        else
            @test !hasextra(model[node], VariationalConstraintsMessagesFormConstraintKey)
        end
    end
end

@testitem "save constraints with constants via `mean_field_constraint!`" setup = [TestUtils] begin
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

    model = create_model(with_plugins(TestUtils.simple_model(), GraphPPL.PluginsCollection(VariationalConstraintsPlugin())))
    ctx = GraphPPL.getcontext(model)

    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(3), 1)) == ((1,), (2, 3), (2, 3))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(3), 2)) == ((1, 3), (2,), (1, 3))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(3), 3)) == ((1, 2), (1, 2), (3,))

    node = ctx[TestUtils.NormalMeanVariance, 2]
    constraint_bitset = getextra(model[node], VariationalConstraintsFactorizationBitSetKey)
    @test tupled_contents(intersect!(constraint_bitset, mean_field_constraint!(BoundedBitSetTuple(3), 1))) == ((1,), (2, 3), (2, 3))
    @test tupled_contents(intersect!(constraint_bitset, mean_field_constraint!(BoundedBitSetTuple(3), 2))) == ((1,), (2,), (3,))

    node = ctx[TestUtils.NormalMeanVariance, 1]
    constraint_bitset = getextra(model[node], VariationalConstraintsFactorizationBitSetKey)
    # Here it is the mean field because the original model has `x ~ Normal(0, 1)` and `0` and `1` are constants 
    @test tupled_contents(intersect!(constraint_bitset, mean_field_constraint!(BoundedBitSetTuple(3), 1))) == ((1,), (2,), (3,))
end

@testitem "materialize_constraints!(:Model, ::NodeLabel, ::FactorNodeData)" setup = [TestUtils] begin
    using BitSetTuples
    import GraphPPL:
        create_model,
        with_plugins,
        materialize_constraints!,
        EdgeLabel,
        get_constraint_names,
        getproperties,
        getextra,
        setextra!,
        VariationalConstraintsPlugin

    model = create_model(TestUtils.simple_model())
    ctx = GraphPPL.getcontext(model)
    node = ctx[TestUtils.NormalMeanVariance, 2]

    # Test 1: Test materialize with a Full Factorization constraint
    node = ctx[TestUtils.NormalMeanVariance, 2]

    # Force overwrite the bitset and the constraints
    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(3))
    materialize_constraints!(model, node)
    @test Tuple.(getextra(model[node], :factorization_constraint_indices)) == ((1, 2, 3),)

    node = ctx[TestUtils.NormalMeanVariance, 1]
    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(((1,), (2,), (3,))))
    materialize_constraints!(model, node)
    @test Tuple.(getextra(model[node], :factorization_constraint_indices)) == ((1,), (2,), (3,))

    # Test 2: Test materialize with an applied constraint
    model = create_model(TestUtils.simple_model())
    ctx = GraphPPL.getcontext(model)
    node = ctx[TestUtils.NormalMeanVariance, 2]

    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(((1,), (2, 3), (2, 3))))
    materialize_constraints!(model, node)
    @test Tuple.(getextra(model[node], :factorization_constraint_indices)) == ((1,), (2, 3))

    # # Test 3: Check that materialize_constraints! throws if the constraint is not a valid partition
    model = create_model(TestUtils.simple_model())
    ctx = GraphPPL.getcontext(model)
    node = ctx[TestUtils.NormalMeanVariance, 2]

    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(((1,), (3,), (1, 3))))
    @test_throws ErrorException materialize_constraints!(model, node)

    # Test 4: Check that materialize_constraints! throws if the constraint is not a valid partition
    model = create_model(TestUtils.simple_model())
    ctx = GraphPPL.getcontext(model)
    node = ctx[TestUtils.NormalMeanVariance, 2]

    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(((1,), (1,), (3,))))
    @test_throws ErrorException materialize_constraints!(model, node)
end

@testitem "Apply constraints to matrix variables" setup = [TestUtils] begin
    using Distributions
    import GraphPPL:
        getproperties,
        PluginsCollection,
        VariationalConstraintsPlugin,
        getextra,
        getcontext,
        with_plugins,
        create_model,
        NotImplementedError,
        @model

    # Test for constraints applied to a model with matrix variables
    c = @constraints begin
        q(x, y) = q(x)q(y)
    end
    model = create_model(with_plugins(TestUtils.filled_matrix_model(), PluginsCollection(VariationalConstraintsPlugin(c))))

    for node in filter(TestUtils.as_node(TestUtils.Normal), model)
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

    model = create_model(with_plugins(uneven_matrix(), PluginsCollection(VariationalConstraintsPlugin(constraints_1))))
    for node in filter(as_node(Normal), model)
        @test getextra(model[node], :factorization_constraint_indices) == ([1], [2], [3])
    end

    constraints_2 = @constraints begin
        q(prec[1], y) = q(prec[1])q(y)
    end

    model = create_model(with_plugins(uneven_matrix(), PluginsCollection(VariationalConstraintsPlugin(constraints_2))))
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

    model = create_model(with_plugins(uneven_matrix(), PluginsCollection(VariationalConstraintsPlugin(constraints_3))))
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
    model = create_model(with_plugins(uneven_matrix(), PluginsCollection(VariationalConstraintsPlugin(constraints_4))))
    ctx = getcontext(model)
    for node in filter(as_node(Normal), model)
        if any(x -> x ∈ GraphPPL.neighbors(model, node), ctx[:prec][1, 3])
            @test getextra(model[node], :factorization_constraint_indices) == ([1], [2], [3])
        else
            @test getextra(model[node], :factorization_constraint_indices) == ([1, 3], [2])
        end
    end

    constraints_5 = @constraints begin
        q(prec, y) = q(prec[(1, 1):(3, 3)])q(y)
    end
    @test_throws GraphPPL.UnresolvableFactorizationConstraintError local model = create_model(
        with_plugins(uneven_matrix(), PluginsCollection(VariationalConstraintsPlugin(constraints_5)))
    )

    @test_throws GraphPPL.NotImplementedError local constraints_5 = @constraints begin
        q(prec, y) = q(prec[(1, 1)]) .. q(prec[(3, 3)])q(y)
    end

    @model function inner_matrix(y, mat)
        for i in 1:2
            for j in 1:2
                mat[i, j] ~ Normal(0, 1)
            end
        end
        y ~ Normal(mat[1, 1], mat[2, 2])
    end

    @model function outer_matrix()
        local mat
        for i in 1:3
            for j in 1:3
                mat[i, j] ~ Normal(0, 1)
            end
        end
        y ~ inner_matrix(mat = mat[2:3, 2:3])
    end

    constraints_7 = @constraints begin
        for q in inner_matrix
            q(mat, y) = q(mat)q(y)
        end
    end
    @test_throws GraphPPL.UnresolvableFactorizationConstraintError local model = create_model(
        with_plugins(outer_matrix(), PluginsCollection(VariationalConstraintsPlugin(constraints_7)))
    )

    @model function mixed_v(y, v)
        for i in 1:3
            v[i] ~ Normal(0, 1)
        end
        y ~ Normal(v[1], v[2])
    end

    @model function mixed_m()
        v1 ~ Normal(0, 1)
        v2 ~ Normal(0, 1)
        v3 ~ Normal(0, 1)
        y ~ mixed_v(v = [v1, v2, v3])
    end

    constraints_8 = @constraints begin
        for q in mixed_v
            q(v, y) = q(v)q(y)
        end
    end

    @test_throws GraphPPL.UnresolvableFactorizationConstraintError local model = create_model(
        with_plugins(mixed_m(), PluginsCollection(VariationalConstraintsPlugin(constraints_8)))
    )

    @model function ordinary_v()
        local v
        for i in 1:3
            v[i] ~ Normal(0, 1)
        end
        y ~ Normal(v[1], v[2])
    end

    constraints_9 = @constraints begin
        q(v[1:2]) = q(v[1])q(v[2])
        q(v, y) = q(v)q(y)
    end

    model = create_model(with_plugins(ordinary_v(), PluginsCollection(VariationalConstraintsPlugin(constraints_9))))
    ctx = getcontext(model)
    for node in filter(as_node(Normal), model)
        @test getextra(model[node], :factorization_constraint_indices) == ([1], [2], [3])
    end

    @model function operate_slice(y, v)
        local v
        for i in 1:3
            v[i] ~ Normal(0, 1)
        end
        y ~ Normal(v[1], v[2])
    end

    @model function pass_slice()
        local m
        for i in 1:3
            for j in 1:3
                m[i, j] ~ Normal(0, 1)
            end
        end
        v = GraphPPL.ResizableArray(m[:, 1])
        y ~ operate_slice(v = v)
    end

    constraints_10 = @constraints begin
        for q in operate_slice
            q(v, y) = q(v[begin]) .. q(v[end])q(y)
        end
    end

    @test_throws GraphPPL.NotImplementedError local model = create_model(
        with_plugins(pass_slice(), PluginsCollection(VariationalConstraintsPlugin(constraints_10)))
    )

    constraints_11 = @constraints begin
        q(x, z, y) = q(z)(q(x[begin + 1]) .. q(x[end]))(q(y[begin + 1]) .. q(y[end]))
    end

    model = create_model(with_plugins(TestUtils.vector_model(), PluginsCollection(VariationalConstraintsPlugin(constraints_11))))

    ctx = getcontext(model)
    for node in filter(as_node(Normal), model)
        if any(x -> x ∈ GraphPPL.neighbors(model, node), ctx[:y][1])
            @test getextra(model[node], :factorization_constraint_indices) == ([1], [2, 3])
        else
            @test getextra(model[node], :factorization_constraint_indices) == ([1], [2], [3])
        end
    end

    constraints_12 = @constraints begin
        q(mat) = q(mat[begin]) .. q(mat[end])
    end
    @test_throws NotImplementedError local model = create_model(
        with_plugins(outer_matrix(), PluginsCollection(VariationalConstraintsPlugin(constraints_12)))
    )

    @model function some_matrix()
        local mat
        for i in 1:3
            for j in 1:3
                mat[i, j] ~ Normal(0, 1)
            end
        end
        y ~ Normal(mat[1, 1], mat[2, 2])
    end

    constraints_13 = @constraints begin
        q(mat) = MeanField()
        q(mat, y) = q(mat)q(y)
    end
    model = create_model(with_plugins(some_matrix(), PluginsCollection(VariationalConstraintsPlugin(constraints_13))))
    ctx = getcontext(model)
    for node in filter(as_node(Normal), model)
        @test getextra(model[node], :factorization_constraint_indices) == ([1], [2], [3])
    end
end

@testitem "Test factorization constraint with automatically folded data/const variables" begin
    using Distributions
    import GraphPPL:
        getproperties,
        PluginsCollection,
        VariationalConstraintsPlugin,
        NodeCreationOptions,
        getorcreate!,
        with_plugins,
        create_model,
        getextra,
        VariationalConstraintsFactorizationIndicesKey,
        @model

    @model function fold_datavars(f, a, b)
        y ~ Normal(f(f(a, b), f(a, b)), 0.5)
    end

    @testset for f in (+, *, (a, b) -> a + b, (a, b) -> a * b), case in (1, 2, 3)
        model = create_model(with_plugins(fold_datavars(f = f), PluginsCollection(VariationalConstraintsPlugin()))) do model, ctx
            if case === 1
                return (
                    a = getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 0.35), :a, nothing),
                    b = getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 0.54), :b, nothing)
                )
            elseif case === 2
                return (
                    a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :a, nothing),
                    b = getorcreate!(model, ctx, NodeCreationOptions(kind = :constant, value = 0.54), :b, nothing)
                )
            elseif case === 3
                return (
                    a = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :a, nothing),
                    b = getorcreate!(model, ctx, NodeCreationOptions(kind = :data, factorized = true), :b, nothing)
                )
            end
        end

        @test length(collect(filter(as_node(Normal), model))) === 1
        @test length(collect(filter(as_node(f), model))) === 0

        foreach(collect(filter(as_node(Normal), model))) do node
            @test getextra(model[node], VariationalConstraintsFactorizationIndicesKey) == ([1], [2], [3])
        end
    end
end

@testitem "Application of MarginalFormConstraint" setup = [TestUtils] begin
    import GraphPPL:
        create_model,
        MarginalFormConstraint,
        IndexedVariable,
        apply_constraints!,
        getextra,
        hasextra,
        VariationalConstraintsMarginalFormConstraintKey

    struct ArbitraryFunctionalFormConstraint end

    # Test saving of MarginalFormConstraint in single variable
    model = create_model(TestUtils.simple_model())
    context = GraphPPL.getcontext(model)
    constraint = MarginalFormConstraint(IndexedVariable(:x, nothing), ArbitraryFunctionalFormConstraint())
    apply_constraints!(model, context, constraint)
    for node in filter(GraphPPL.as_variable(:x), model)
        @test getextra(model[node], VariationalConstraintsMarginalFormConstraintKey) == ArbitraryFunctionalFormConstraint()
    end

    # Test saving of MarginalFormConstraint in multiple variables
    model = create_model(TestUtils.vector_model())
    context = GraphPPL.getcontext(model)
    constraint = MarginalFormConstraint(IndexedVariable(:x, nothing), ArbitraryFunctionalFormConstraint())
    apply_constraints!(model, context, constraint)
    for node in filter(GraphPPL.as_variable(:x), model)
        @test getextra(model[node], VariationalConstraintsMarginalFormConstraintKey) == ArbitraryFunctionalFormConstraint()
    end
    for node in filter(GraphPPL.as_variable(:y), model)
        @test !hasextra(model[node], VariationalConstraintsMarginalFormConstraintKey)
    end

    # Test saving of MarginalFormConstraint in single variable in array
    model = create_model(TestUtils.vector_model())
    context = GraphPPL.getcontext(model)
    constraint = MarginalFormConstraint(IndexedVariable(:x, 1), ArbitraryFunctionalFormConstraint())
    apply_constraints!(model, context, constraint)
    applied_node = context[:x][1]
    for node in filter(GraphPPL.as_variable(:x), model)
        if node == applied_node
            @test getextra(model[node], VariationalConstraintsMarginalFormConstraintKey) == ArbitraryFunctionalFormConstraint()
        else
            @test !hasextra(model[node], VariationalConstraintsMarginalFormConstraintKey)
        end
    end
end

@testitem "Application of MessageFormConstraint" setup = [TestUtils] begin
    import GraphPPL:
        create_model,
        MessageFormConstraint,
        IndexedVariable,
        apply_constraints!,
        hasextra,
        getextra,
        VariationalConstraintsMessagesFormConstraintKey

    struct ArbitraryMessageFormConstraint end

    # Test saving of MessageFormConstraint in single variable
    model = create_model(TestUtils.simple_model())
    context = GraphPPL.getcontext(model)
    constraint = MessageFormConstraint(IndexedVariable(:x, nothing), ArbitraryMessageFormConstraint())
    node = first(filter(GraphPPL.as_variable(:x), model))
    apply_constraints!(model, context, constraint)
    @test getextra(model[node], VariationalConstraintsMessagesFormConstraintKey) == ArbitraryMessageFormConstraint()

    # Test saving of MessageFormConstraint in multiple variables
    model = create_model(TestUtils.vector_model())
    context = GraphPPL.getcontext(model)
    constraint = MessageFormConstraint(IndexedVariable(:x, nothing), ArbitraryMessageFormConstraint())
    apply_constraints!(model, context, constraint)
    for node in filter(GraphPPL.as_variable(:x), model)
        @test getextra(model[node], VariationalConstraintsMessagesFormConstraintKey) == ArbitraryMessageFormConstraint()
    end
    for node in filter(GraphPPL.as_variable(:y), model)
        @test !hasextra(model[node], VariationalConstraintsMessagesFormConstraintKey)
    end

    # Test saving of MessageFormConstraint in single variable in array
    model = create_model(TestUtils.vector_model())
    context = GraphPPL.getcontext(model)
    constraint = MessageFormConstraint(IndexedVariable(:x, 1), ArbitraryMessageFormConstraint())
    apply_constraints!(model, context, constraint)
    applied_node = context[:x][1]
    for node in filter(GraphPPL.as_variable(:x), model)
        if node == applied_node
            @test getextra(model[node], VariationalConstraintsMessagesFormConstraintKey) == ArbitraryMessageFormConstraint()
        else
            @test !hasextra(model[node], VariationalConstraintsMessagesFormConstraintKey)
        end
    end
end

@testitem "save constraints with constants via `mean_field_constraint!`" setup = [TestUtils] begin
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

    model = create_model(with_plugins(TestUtils.simple_model(), GraphPPL.PluginsCollection(VariationalConstraintsPlugin())))
    ctx = GraphPPL.getcontext(model)

    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(3), 1)) == ((1,), (2, 3), (2, 3))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(3), 2)) == ((1, 3), (2,), (1, 3))
    @test tupled_contents(mean_field_constraint!(BoundedBitSetTuple(3), 3)) == ((1, 2), (1, 2), (3,))

    node = ctx[TestUtils.NormalMeanVariance, 2]
    constraint_bitset = getextra(model[node], VariationalConstraintsFactorizationBitSetKey)
    @test tupled_contents(intersect!(constraint_bitset, mean_field_constraint!(BoundedBitSetTuple(3), 1))) == ((1,), (2, 3), (2, 3))
    @test tupled_contents(intersect!(constraint_bitset, mean_field_constraint!(BoundedBitSetTuple(3), 2))) == ((1,), (2,), (3,))

    node = ctx[TestUtils.NormalMeanVariance, 1]
    constraint_bitset = getextra(model[node], VariationalConstraintsFactorizationBitSetKey)
    # Here it is the mean field because the original model has `x ~ Normal(0, 1)` and `0` and `1` are constants 
    @test tupled_contents(intersect!(constraint_bitset, mean_field_constraint!(BoundedBitSetTuple(3), 1))) == ((1,), (2,), (3,))
end

@testitem "materialize_constraints!(:Model, ::NodeLabel, ::FactorNodeData)" setup = [TestUtils] begin
    using BitSetTuples
    import GraphPPL:
        create_model,
        with_plugins,
        materialize_constraints!,
        EdgeLabel,
        get_constraint_names,
        getproperties,
        getextra,
        setextra!,
        VariationalConstraintsPlugin

    model = create_model(TestUtils.simple_model())
    ctx = GraphPPL.getcontext(model)
    node = ctx[TestUtils.NormalMeanVariance, 2]

    # Test 1: Test materialize with a Full Factorization constraint
    node = ctx[TestUtils.NormalMeanVariance, 2]

    # Force overwrite the bitset and the constraints
    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(3))
    materialize_constraints!(model, node)
    @test Tuple.(getextra(model[node], :factorization_constraint_indices)) == ((1, 2, 3),)

    node = ctx[TestUtils.NormalMeanVariance, 1]
    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(((1,), (2,), (3,))))
    materialize_constraints!(model, node)
    @test Tuple.(getextra(model[node], :factorization_constraint_indices)) == ((1,), (2,), (3,))

    # Test 2: Test materialize with an applied constraint
    model = create_model(TestUtils.simple_model())
    ctx = GraphPPL.getcontext(model)
    node = ctx[TestUtils.NormalMeanVariance, 2]

    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(((1,), (2, 3), (2, 3))))
    materialize_constraints!(model, node)
    @test Tuple.(getextra(model[node], :factorization_constraint_indices)) == ((1,), (2, 3))

    # # Test 3: Check that materialize_constraints! throws if the constraint is not a valid partition
    model = create_model(TestUtils.simple_model())
    ctx = GraphPPL.getcontext(model)
    node = ctx[TestUtils.NormalMeanVariance, 2]

    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(((1,), (3,), (1, 3))))
    @test_throws ErrorException materialize_constraints!(model, node)

    # Test 4: Check that materialize_constraints! throws if the constraint is not a valid partition
    model = create_model(TestUtils.simple_model())
    ctx = GraphPPL.getcontext(model)
    node = ctx[TestUtils.NormalMeanVariance, 2]

    setextra!(model[node], :factorization_constraint_bitset, BoundedBitSetTuple(((1,), (1,), (3,))))
    @test_throws ErrorException materialize_constraints!(model, node)
end
