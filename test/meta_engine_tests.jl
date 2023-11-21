@testitem "FactorMetaDescriptor" begin
    include("model_zoo.jl")
    import GraphPPL: FactorMetaDescriptor, IndexedVariable

    @test FactorMetaDescriptor(Normal, (:x, :k, :w)) isa FactorMetaDescriptor{<:Tuple}
    @test FactorMetaDescriptor(Gamma, nothing) isa FactorMetaDescriptor{Nothing}
end

@testitem "VariableMetaDescriptor" begin
    import GraphPPL: VariableMetaDescriptor, IndexedVariable

    @test VariableMetaDescriptor(IndexedVariable(:x, nothing)) isa VariableMetaDescriptor
    @test_throws MethodError VariableMetaDescriptor(1)
end

@testitem "MetaObject" begin
    include("model_zoo.jl")
    import GraphPPL: MetaObject, FactorMetaDescriptor, IndexedVariable, VariableMetaDescriptor

    @test MetaObject(FactorMetaDescriptor(Normal, (IndexedVariable(:x, nothing), :k, :w)), SomeMeta()) isa MetaObject{<:FactorMetaDescriptor, SomeMeta}
    @test MetaObject(FactorMetaDescriptor(Normal, (:x, :k, :w)), (meta = SomeMeta(),)) isa MetaObject{<:FactorMetaDescriptor, <:NamedTuple}
    @test_throws MethodError MetaObject((Normal, (:x, :k, :w)), SomeMeta())

    @test MetaObject(VariableMetaDescriptor(IndexedVariable(:x, nothing)), SomeMeta()) isa MetaObject{<:VariableMetaDescriptor, SomeMeta}
    @test MetaObject(VariableMetaDescriptor(IndexedVariable(:x, nothing)), (meta = SomeMeta(),)) isa MetaObject{<:VariableMetaDescriptor, <:NamedTuple}
    @test_throws MethodError MetaObject(:x, SomeMeta())
end

@testitem "MetaSpecification" begin
    import GraphPPL: MetaSpecification

    @test MetaSpecification() isa MetaSpecification
end

@testitem "SpecificSubModelMeta" begin
    include("model_zoo.jl")
    import GraphPPL: SpecificSubModelMeta, GeneralSubModelMeta, MetaSpecification, IndexedVariable, FactorMetaDescriptor, MetaObject

    @test SpecificSubModelMeta(GraphPPL.FactorID(sum, 1), MetaSpecification()) isa SpecificSubModelMeta
    push!(SpecificSubModelMeta(GraphPPL.FactorID(sum, 1)), MetaObject(FactorMetaDescriptor(Normal, (IndexedVariable(:x, nothing), :k, :w)), SomeMeta()))
    push!(SpecificSubModelMeta(GraphPPL.FactorID(sum, 1), MetaSpecification()), SpecificSubModelMeta(GraphPPL.FactorID(sum, 1), MetaSpecification()))
    push!(SpecificSubModelMeta(GraphPPL.FactorID(sum, 1), MetaSpecification()), GeneralSubModelMeta(gcv, MetaSpecification()))
end

@testitem "GeneralSubModelMeta" begin
    include("model_zoo.jl")
    import GraphPPL: SpecificSubModelMeta, GeneralSubModelMeta, MetaSpecification, IndexedVariable, FactorMetaDescriptor, MetaObject, getgeneralssubmodelmeta

    @test GeneralSubModelMeta(gcv, MetaSpecification()) isa GeneralSubModelMeta
    push!(GeneralSubModelMeta(gcv, MetaSpecification()), MetaObject(FactorMetaDescriptor(Normal, (IndexedVariable(:x, nothing), :k, :w)), SomeMeta()))
    push!(GeneralSubModelMeta(gcv, MetaSpecification()), SpecificSubModelMeta(GraphPPL.FactorID(sum, 1), MetaSpecification()))
    meta = MetaSpecification()
    push!(meta, GeneralSubModelMeta(gcv, MetaSpecification()))
end

@testitem "filter general and specific submodel meta" begin
    import GraphPPL: MetaSpecification, GeneralSubModelMeta, SpecificSubModelMeta, getspecificsubmodelmeta, getgeneralsubmodelmeta, FactorID, getkey

    meta = MetaSpecification()
    push!(meta, GeneralSubModelMeta(sin, MetaSpecification()))
    @test length(getgeneralsubmodelmeta(meta)) === 1
    @test length(getspecificsubmodelmeta(meta)) === 0

    push!(meta, SpecificSubModelMeta(FactorID(sum, 1), MetaSpecification()))

    @test length(getgeneralsubmodelmeta(meta)) === 1
    @test length(getspecificsubmodelmeta(meta)) === 1

    @test getspecificsubmodelmeta(meta, FactorID(sum, 1)).tag == FactorID(sum, 1)
    @test getspecificsubmodelmeta(meta, FactorID(sum, 5)) === nothing

    @test getgeneralsubmodelmeta(meta, sin).fform == sin
end

# @testitem "apply!(::Model, ::Context, ::MetaObject)" begin
#     include("model_zoo.jl")
#     import GraphPPL:
#         apply!,
#         IndexedVariable,
#         MetaObject,
#         getcontext,
#         FactorMetaDescriptor,
#         VariableMetaDescriptor,
#         meta

#     # Test apply for a FactorMeta over a single factor
#     model = create_terminated_model(simple_model)
#     context = getcontext(model)
#     metadata = MetaObject(
#         FactorMetaDescriptor(
#             NormalMeanVariance,
#             (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
#         ),
#         SomeMeta(),
#     )
#     apply!(model, context, metadata)
#     node = first(
#         intersect(
#             GraphPPL.neighbors(model, context[:x]),
#             GraphPPL.neighbors(model, context[:y]),
#         ),
#     )
#     @test meta(model[node]) == SomeMeta()

#     # Test apply for a FactorMeta over a single factor where variables are not specified
#     model = create_terminated_model(simple_model)
#     context = GraphPPL.getcontext(model)
#     metadata = MetaObject(FactorMetaDescriptor(NormalMeanVariance, nothing), SomeMeta())
#     apply!(model, context, metadata)
#     @test meta(model[node]) == SomeMeta()

#     # Test apply for a FactorMeta over a vector of factors
#     model = create_terminated_model(vector_model)
#     context = GraphPPL.getcontext(model)
#     metadata = MetaObject(FactorMetaDescriptor(NormalMeanVariance, (:x, :y)), SomeMeta())
#     apply!(model, context, metadata)
#     for node in intersect(
#         GraphPPL.neighbors(model, context[:x]),
#         GraphPPL.neighbors(model, context[:y]),
#     )
#         @test meta(model[node]) == SomeMeta()
#     end

#     # Test apply for a FactorMeta over a vector of factors without specifying variables
#     model = create_terminated_model(vector_model)
#     context = GraphPPL.getcontext(model)
#     metadata = MetaObject(FactorMetaDescriptor(NormalMeanVariance, nothing), SomeMeta())
#     apply!(model, context, metadata)
#     for node in intersect(
#         GraphPPL.neighbors(model, context[:x]),
#         GraphPPL.neighbors(model, context[:y]),
#     )
#         @test meta(model[node]) == SomeMeta()
#     end

#     # Test apply for a FactorMeta over a single factor with NamedTuple as meta
#     model = create_terminated_model(simple_model)
#     context = GraphPPL.getcontext(model)
#     metadata = MetaObject(
#         FactorMetaDescriptor(
#             NormalMeanVariance,
#             (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
#         ),
#         (meta = SomeMeta(), other = 1),
#     )
#     apply!(model, context, metadata)
#     node = first(
#         intersect(
#             GraphPPL.neighbors(model, context[:x]),
#             GraphPPL.neighbors(model, context[:y]),
#         ),
#     )
#     @test meta(model[node])[:meta] == SomeMeta()
#     @test meta(model[node])[:other] == 1

#     # Test apply for a FactorMeta over a single factor with NamedTuple as meta
#     model = create_terminated_model(simple_model)
#     context = GraphPPL.getcontext(model)
#     metadata = MetaObject(
#         FactorMetaDescriptor(NormalMeanVariance, nothing),
#         (meta = SomeMeta(), other = 1),
#     )
#     apply!(model, context, metadata)
#     node = first(
#         intersect(
#             GraphPPL.neighbors(model, context[:x]),
#             GraphPPL.neighbors(model, context[:y]),
#         ),
#     )
#     @test meta(model[node])[:meta] == SomeMeta()
#     @test meta(model[node])[:other] == 1

#     # Test apply for a FactorMeta over a vector of factors with NamedTuple as meta
#     model = create_terminated_model(vector_model)
#     context = GraphPPL.getcontext(model)
#     metadata = MetaObject(
#         FactorMetaDescriptor(
#             NormalMeanVariance,
#             (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
#         ),
#         (meta = SomeMeta(), other = 1),
#     )
#     apply!(model, context, metadata)
#     for node in intersect(
#         GraphPPL.neighbors(model, context[:x]),
#         GraphPPL.neighbors(model, context[:y]),
#     )
#         @test meta(model[node])[:meta] == SomeMeta()
#         @test meta(model[node])[:other] == 1
#     end

#     # Test apply for a FactorMeta over a factor that is specified by an Index
#     model = create_terminated_model(vector_model)
#     context = GraphPPL.getcontext(model)
#     metadata = MetaObject(
#         FactorMetaDescriptor(
#             NormalMeanVariance,
#             (IndexedVariable(:x, 1), IndexedVariable(:y, nothing)),
#         ),
#         (meta = SomeMeta(), other = 1),
#     )
#     @show meta.(getindex.(Ref(model), GraphPPL.factor_nodes(model)))
#     apply!(model, context, metadata)
#     node = first(
#         intersect(
#             GraphPPL.neighbors(model, context[:x][1]),
#             GraphPPL.neighbors(model, context[:y]),
#         ),
#     )
#     @test meta(model[node])[:meta] == SomeMeta()
#     @test meta(model[node])[:other] == 1
#     other_node = last(
#         intersect(
#             GraphPPL.neighbors(model, context[:x][3]),
#             GraphPPL.neighbors(model, context[:y]),
#         ),
#     )

#     @test meta(model[other_node]) === nothing

#     # Test apply for a FactorMeta over a vector of factors with NamedTuple as meta
#     model = create_terminated_model(vector_model)
#     context = GraphPPL.getcontext(model)
#     meta = MetaObject(
#         FactorMetaDescriptor(NormalMeanVariance, nothing),
#         (meta = SomeMeta(), other = 1),
#     )
#     apply!(model, context, meta)
#     for node in intersect(
#         GraphPPL.neighbors(model, context[:x]),
#         GraphPPL.neighbors(model, context[:y]),
#     )
#         @test node_options(model[node])[:meta] == SomeMeta()
#         @test node_options(model[node])[:other] == 1
#     end

#     # Test that setting q in NamedTuple throws an ErrorException
#     model = create_terminated_model(simple_model)
#     context = GraphPPL.getcontext(model)
#     meta = MetaObject(
#         FactorMetaDescriptor(NormalMeanVariance, (:x, :y)),
#         (meta = SomeMeta(), q = 1),
#     )
#     @test_throws ErrorException apply!(model, context, meta)

#     # Test that setting q in NamedTuple throws an ErrorException
#     model = create_terminated_model(simple_model)
#     context = GraphPPL.getcontext(model)
#     meta = MetaObject(
#         FactorMetaDescriptor(NormalMeanVariance, nothing),
#         (meta = SomeMeta(), q = 1),
#     )
#     @test_throws ErrorException apply!(model, context, meta)

#     # Test apply for a VariableMeta
#     model = create_terminated_model(simple_model)
#     context = GraphPPL.getcontext(model)
#     meta = MetaObject(VariableMetaDescriptor(IndexedVariable(:x, nothing)), SomeMeta())
#     apply!(model, context, meta)
#     @test meta(model[context[:x]]) == SomeMeta()

#     # Test apply for a VariableMeta with NamedTuple as meta
#     model = create_terminated_model(simple_model)
#     context = GraphPPL.getcontext(model)
#     meta = MetaObject(
#         VariableMetaDescriptor(IndexedVariable(:x, nothing)),
#         (meta = SomeMeta(), other = 1),
#     )
#     apply!(model, context, meta)
#     @test node_options(model[context[:x]])[:meta] == SomeMeta()

#     Test apply for a VariableMeta with NamedTuple as meta
#     model = create_terminated_model(vector_model)
#     context = GraphPPL.getcontext(model)
#     meta = MetaObject(
#         VariableMetaDescriptor(IndexedVariable(:x, nothing)),
#         (meta = SomeMeta(), other = 1),
#     )
#     apply!(model, context, meta)
#     @test model[context[:x][1]].options[:meta] == SomeMeta()
#     @test model[context[:x][2]].options[:meta] == SomeMeta()
#     @test model[context[:x][3]].options[:meta] == SomeMeta()

#     # Test apply for a VariableMeta with NamedTuple as meta
#     model = create_terminated_model(vector_model)
#     context = GraphPPL.getcontext(model)
#     meta = MetaObject(
#         VariableMetaDescriptor(IndexedVariable(:x, nothing)),
#         (meta = SomeMeta(), other = 1),
#     )
#     apply!(model, context, meta)
#     @test model[context[:x][1]].options[:meta] == SomeMeta()
#     @test model[context[:x][1]].options[:other] == 1
#     @test model[context[:x][2]].options[:meta] == SomeMeta()
#     @test model[context[:x][2]].options[:other] == 1
#     @test model[context[:x][3]].options[:meta] == SomeMeta()
#     @test model[context[:x][3]].options[:other] == 1

#     # Test apply for a VariableMeta with NamedTuple as meta containing q
#     model = create_terminated_model(simple_model)
#     context = GraphPPL.getcontext(model)
#     meta = MetaObject(
#         VariableMetaDescriptor(IndexedVariable(:x, nothing)),
#         (meta = SomeMeta(), q = 1),
#     )
#     @test_throws ErrorException apply!(model, context, meta)
# end

# @testitem "save_meta!(::Model, ::NodeLabel, ::MetaObject)" begin
#     include("model_zoo.jl")
#     import GraphPPL:
#         save_meta!,
#         node_options,
#         IndexedVariable,
#         MetaObject,
#         getcontext,
#         FactorMetaDescriptor,
#         VariableMetaDescriptor,
#         SomeMeta,
#         neighbors,
#         node_options

#     # Test save_meta! for a FactorMeta over a single factor
#     model = create_terminated_model(simple_model)
#     context = getcontext(model)
#     node = first(intersect(neighbors(model, context[:x]), neighbors(model, context[:y])))
#     meta = MetaObject(FactorMetaDescriptor(NormalMeanVariance, (:x, :y)), SomeMeta())
#     save_meta!(model, node, meta)
#     @test node_options(model[node])[:meta] == SomeMeta()

#     # Test save_meta! for a FactorMeta with a NamedTuple as meta
#     model = create_terminated_model(simple_model)
#     context = GraphPPL.getcontext(model)
#     node = first(intersect(neighbors(model, context[:x]), neighbors(model, context[:y])))
#     meta = MetaObject(
#         FactorMetaDescriptor(NormalMeanVariance, (:x, :y)),
#         (meta = SomeMeta(), other = 1),
#     )
#     save_meta!(model, node, meta)
#     @test node_options(model[node])[:meta] == SomeMeta()
#     @test node_options(model[node])[:other] == 1

#     # Test save_meta! for a FactorMeta where we try to specify q in the meta
#     model = create_terminated_model(simple_model)
#     context = GraphPPL.getcontext(model)
#     node = first(intersect(neighbors(model, context[:x]), neighbors(model, context[:y])))
#     meta = MetaObject(FactorMetaDescriptor(NormalMeanVariance, (:x, :y)), (q = 1,))
#     @test_throws ErrorException save_meta!(model, node, meta)

# end
