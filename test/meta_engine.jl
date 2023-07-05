module test_meta_engine

using Test
using TestSetExtensions
using GraphPPL
include("model_zoo.jl")

@testset ExtendedTestSet "meta_engine" begin
    @testset "FactorMetaDescriptor" begin
        import GraphPPL: FactorMetaDescriptor, IndexedVariable

        @test FactorMetaDescriptor(Normal, (:x, :k, :w)) isa FactorMetaDescriptor{<:Tuple}
        @test FactorMetaDescriptor(Gamma, nothing) isa FactorMetaDescriptor{Nothing}
    end

    @testset "VariableMetaDescriptor" begin
        import GraphPPL: VariableMetaDescriptor, IndexedVariable

        @test VariableMetaDescriptor(IndexedVariable(:x, nothing)) isa
              VariableMetaDescriptor
        @test_throws MethodError VariableMetaDescriptor(1)

    end

    @testset "MetaObject" begin
        import GraphPPL: MetaObject, FactorMetaDescriptor, IndexedVariable


        @test MetaObject(
            FactorMetaDescriptor(Normal, (IndexedVariable(:x, nothing), :k, :w)),
            SomeMeta(),
        ) isa MetaObject{<:FactorMetaDescriptor,SomeMeta}
        @test MetaObject(
            FactorMetaDescriptor(Normal, (:x, :k, :w)),
            (meta = SomeMeta(),),
        ) isa MetaObject{<:FactorMetaDescriptor,<:NamedTuple}
        @test_throws MethodError MetaObject((Normal, (:x, :k, :w)), SomeMeta())

        @test MetaObject(
            VariableMetaDescriptor(IndexedVariable(:x, nothing)),
            SomeMeta(),
        ) isa MetaObject{<:VariableMetaDescriptor,SomeMeta}
        @test MetaObject(
            VariableMetaDescriptor(IndexedVariable(:x, nothing)),
            (meta = SomeMeta(),),
        ) isa MetaObject{<:VariableMetaDescriptor,<:NamedTuple}
        @test_throws MethodError MetaObject(:x, SomeMeta())
    end

    @testset "MetaSpecification" begin
        import GraphPPL: MetaSpecification

        @test MetaSpecification() isa MetaSpecification
    end

    @testset "SpecificSubModelMeta" begin
        import GraphPPL: SpecificSubModelMeta, GeneralSubModelMeta

        @test SpecificSubModelMeta(:x, MetaSpecification()) isa SpecificSubModelMeta
        push!(
            SpecificSubModelMeta(:x, MetaSpecification()),
            MetaObject(
                FactorMetaDescriptor(Normal, (IndexedVariable(:x, nothing), :k, :w)),
                SomeMeta(),
            ),
        )
        push!(
            SpecificSubModelMeta(:x, MetaSpecification()),
            SpecificSubModelMeta(:y, MetaSpecification()),
        )
        push!(
            SpecificSubModelMeta(:x, MetaSpecification()),
            GeneralSubModelMeta(second_submodel, MetaSpecification()),
        )
    end

    @testset "GeneralSubModelMeta" begin
        import GraphPPL: GeneralSubModelMeta, SpecificSubModelMeta

        @test GeneralSubModelMeta(second_submodel, MetaSpecification()) isa
              GeneralSubModelMeta
        push!(
            GeneralSubModelMeta(second_submodel, MetaSpecification()),
            MetaObject(
                FactorMetaDescriptor(Normal, (IndexedVariable(:x, nothing), :k, :w)),
                SomeMeta(),
            ),
        )
        push!(
            GeneralSubModelMeta(second_submodel, MetaSpecification()),
            SpecificSubModelMeta(:y, MetaSpecification()),
        )
        push!(
            GeneralSubModelMeta(second_submodel, MetaSpecification()),
            GeneralSubModelMeta(second_submodel, MetaSpecification()),
        )

    end

    @testset "SubModelMeta" begin
        import GraphPPL: SubModelMeta, SpecificSubModelMeta, GeneralSubModelMeta

        @test SubModelMeta(:x) isa SpecificSubModelMeta
        @test SubModelMeta(second_submodel) isa GeneralSubModelMeta
    end

    @testset "apply!(::Model, ::Context, ::MetaObject)" begin
        import GraphPPL: apply!

        # Test apply for a FactorMeta over a single factor
        model = create_simple_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(
            FactorMetaDescriptor(
                sum,
                (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
            ),
            SomeMeta(),
        )
        apply!(model, context, meta)
        @test model[context[:sum_4]].options[:meta] == SomeMeta()

        # Test apply for a FactorMeta over a single factor where variables are not specified
        model = create_simple_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(FactorMetaDescriptor(sum, nothing), SomeMeta())
        apply!(model, context, meta)
        @test model[context[:sum_4]].options[:meta] == SomeMeta()

        # Test apply for a FactorMeta over a vector of factors
        model = create_vector_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(FactorMetaDescriptor(sum, (:x, :y)), SomeMeta())
        apply!(model, context, meta)
        @test model[context[:sum_4]].options[:meta] == SomeMeta()
        @test model[context[:sum_7]].options[:meta] == SomeMeta()
        @test model[context[:sum_10]].options[:meta] == SomeMeta()
        @test model[context[:sum_12]].options[:meta] == SomeMeta()

        # Test apply for a FactorMeta over a vector of factors without specifying variables
        model = create_vector_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(FactorMetaDescriptor(sum, nothing), SomeMeta())
        apply!(model, context, meta)
        @test model[context[:sum_4]].options[:meta] == SomeMeta()
        @test model[context[:sum_7]].options[:meta] == SomeMeta()
        @test model[context[:sum_10]].options[:meta] == SomeMeta()
        @test model[context[:sum_12]].options[:meta] == SomeMeta()

        # Test apply for a FactorMeta over a single factor with NamedTuple as meta
        model = create_simple_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(
            FactorMetaDescriptor(
                sum,
                (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
            ),
            (meta = SomeMeta(), other = 1),
        )
        apply!(model, context, meta)
        @test model[context[:sum_4]].options[:meta] == SomeMeta()
        @test model[context[:sum_4]].options[:other] == 1

        # Test apply for a FactorMeta over a single factor with NamedTuple as meta
        model = create_simple_model()
        context = GraphPPL.getcontext(model)
        meta =
            MetaObject(FactorMetaDescriptor(sum, nothing), (meta = SomeMeta(), other = 1))
        apply!(model, context, meta)
        @test model[context[:sum_4]].options[:meta] == SomeMeta()
        @test model[context[:sum_4]].options[:other] == 1

        # Test apply for a FactorMeta over a vector of factors with NamedTuple as meta
        model = create_vector_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(
            FactorMetaDescriptor(
                sum,
                (IndexedVariable(:x, nothing), IndexedVariable(:y, nothing)),
            ),
            (meta = SomeMeta(), other = 1),
        )
        apply!(model, context, meta)
        @test model[context[:sum_4]].options[:meta] == SomeMeta()
        @test model[context[:sum_4]].options[:other] == 1
        @test model[context[:sum_7]].options[:meta] == SomeMeta()
        @test model[context[:sum_7]].options[:other] == 1
        @test model[context[:sum_10]].options[:meta] == SomeMeta()
        @test model[context[:sum_10]].options[:other] == 1
        @test model[context[:sum_12]].options[:meta] == SomeMeta()
        @test model[context[:sum_12]].options[:other] == 1

        # Test apply for a FactorMeta over a factor that is specified by an Index
        model = create_vector_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(
            FactorMetaDescriptor(
                sum,
                (IndexedVariable(:x, 1), IndexedVariable(:y, nothing)),
            ),
            (meta = SomeMeta(), other = 1),
        )
        apply!(model, context, meta)
        @test model[context[:sum_4]].options[:meta] == SomeMeta()
        @test model[context[:sum_4]].options[:other] == 1
        @test !haskey(model[context[:sum_7]].options, :meta)

        # Test apply for a FactorMeta over a vector of factors with NamedTuple as meta
        model = create_vector_model()
        context = GraphPPL.getcontext(model)
        meta =
            MetaObject(FactorMetaDescriptor(sum, nothing), (meta = SomeMeta(), other = 1))
        apply!(model, context, meta)
        @test model[context[:sum_4]].options[:meta] == SomeMeta()
        @test model[context[:sum_4]].options[:other] == 1
        @test model[context[:sum_7]].options[:meta] == SomeMeta()
        @test model[context[:sum_7]].options[:other] == 1
        @test model[context[:sum_10]].options[:meta] == SomeMeta()
        @test model[context[:sum_10]].options[:other] == 1
        @test model[context[:sum_12]].options[:meta] == SomeMeta()
        @test model[context[:sum_12]].options[:other] == 1

        # Test that setting q in NamedTuple throws an ErrorException
        model = create_simple_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(FactorMetaDescriptor(sum, (:x, :y)), (meta = SomeMeta(), q = 1))
        @test_throws ErrorException apply!(model, context, meta)

        # Test that setting q in NamedTuple throws an ErrorException
        model = create_simple_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(FactorMetaDescriptor(sum, nothing), (meta = SomeMeta(), q = 1))
        @test_throws ErrorException apply!(model, context, meta)

        # Test apply for a VariableMeta
        model = create_simple_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(VariableMetaDescriptor(IndexedVariable(:x, nothing)), SomeMeta())
        apply!(model, context, meta)
        @test model[context[:x]].options[:meta] == SomeMeta()

        # Test apply for a VariableMeta with NamedTuple as meta
        model = create_simple_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(
            VariableMetaDescriptor(IndexedVariable(:x, nothing)),
            (meta = SomeMeta(), other = 1),
        )
        apply!(model, context, meta)
        @test model[context[:x]].options[:meta] == SomeMeta()

        # Test apply for a VariableMeta with NamedTuple as meta
        model = create_vector_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(
            VariableMetaDescriptor(IndexedVariable(:x, nothing)),
            (meta = SomeMeta(), other = 1),
        )
        apply!(model, context, meta)
        @test model[context[:x][1]].options[:meta] == SomeMeta()
        @test model[context[:x][2]].options[:meta] == SomeMeta()
        @test model[context[:x][3]].options[:meta] == SomeMeta()
        @test model[context[:x][4]].options[:meta] == SomeMeta()

        # Test apply for a VariableMeta with NamedTuple as meta
        model = create_vector_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(
            VariableMetaDescriptor(IndexedVariable(:x, nothing)),
            (meta = SomeMeta(), other = 1),
        )
        apply!(model, context, meta)
        @test model[context[:x][1]].options[:meta] == SomeMeta()
        @test model[context[:x][1]].options[:other] == 1
        @test model[context[:x][2]].options[:meta] == SomeMeta()
        @test model[context[:x][2]].options[:other] == 1
        @test model[context[:x][3]].options[:meta] == SomeMeta()
        @test model[context[:x][3]].options[:other] == 1
        @test model[context[:x][4]].options[:meta] == SomeMeta()

        # Test apply for a VariableMeta with NamedTuple as meta containing q
        model = create_simple_model()
        context = GraphPPL.getcontext(model)
        meta = MetaObject(
            VariableMetaDescriptor(IndexedVariable(:x, nothing)),
            (meta = SomeMeta(), q = 1),
        )
        @test_throws ErrorException apply!(model, context, meta)
    end

    @testset "save_meta!(::Model, ::NodeLabel, ::MetaObject)" begin
        import GraphPPL: save_meta!

        # Test save_meta! for a FactorMeta over a single factor
        model = create_simple_model()
        context = GraphPPL.getcontext(model)
        node = context[:sum_4]
        meta = MetaObject(FactorMetaDescriptor(sum, (:x, :y)), SomeMeta())
        save_meta!(model, node, meta)
        @test model[node].options[:meta] == SomeMeta()

        # Test save_meta! for a FactorMeta with a NamedTuple as meta
        model = create_simple_model()
        context = GraphPPL.getcontext(model)
        node = context[:sum_4]
        meta =
            MetaObject(FactorMetaDescriptor(sum, (:x, :y)), (meta = SomeMeta(), other = 1))
        save_meta!(model, node, meta)
        @test model[node].options[:meta] == SomeMeta()
        @test model[node].options[:other] == 1

        # Test save_meta! for a FactorMeta where we try to specify q in the meta
        model = create_simple_model()
        context = GraphPPL.getcontext(model)
        node = context[:sum_4]
        meta = MetaObject(FactorMetaDescriptor(sum, (:x, :y)), (q = 1,))
        @test_throws ErrorException save_meta!(model, node, meta)

    end
end

end
