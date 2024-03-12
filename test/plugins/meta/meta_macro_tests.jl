@testitem "check_for_returns" begin
    include("../../model_zoo.jl")
    import GraphPPL: check_for_returns_meta, apply_pipeline

    # Test 1: check_for_returns_meta with one statement
    input = quote
        Normal(x, y) -> some_meta()
    end
    @test_expression_generating apply_pipeline(input, check_for_returns_meta) input

    # Test 2: check_for_returns_meta with a return statement
    input = quote
        Normal(x, y) -> some_meta()
        return nothing
    end
    @test_throws ErrorException("The meta macro does not support return statements.") apply_pipeline(input, check_for_returns_meta)
end
@testitem "add_meta_constructor" begin
    include("../../model_zoo.jl")
    import GraphPPL: add_meta_construction

    # Test 1: add_constraints_construction to regular constraint specification
    input = quote
        GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
        NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
        x -> MySecondCustomMetaObject(arg3)
    end
    output = quote
        __meta__ = GraphPPL.MetaSpecification()
        $input
        __meta__
    end
    @test_expression_generating add_meta_construction(input) output

    # Test 2: add_constraints_construction to constraint specification with nested model specification
    input = quote
        GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
        NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
        x -> MySecondCustomMetaObject(arg3)
        for meta in submodel
            GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
            NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
            x -> MySecondCustomMetaObject(arg3)
        end
    end
    output = quote
        __meta__ = GraphPPL.MetaSpecification()
        $input
        __meta__
    end
    @test_expression_generating add_meta_construction(input) output

    # Test 3: add_constraints_construction to constraint specification with function specification
    input = quote 
        function somemeta()
            GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
            NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
            x -> MySecondCustomMetaObject(arg3)
        end
    end
    output = quote 
        function somemeta()
            __meta__ = GraphPPL.MetaSpecification()
            GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
            NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
            x -> MySecondCustomMetaObject(arg3)
            return __meta__
        end
    end
    @test_expression_generating add_meta_construction(input) output

    # Test 4: add_constraints_construction to constraint specification with function specification and arguments
    input = quote 
        function somemeta(x, y)
            GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
            NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
            x -> MySecondCustomMetaObject(arg3)
        end
    end
    output = quote 
        function somemeta(x, y)
            __meta__ = GraphPPL.MetaSpecification()
            GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
            NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
            x -> MySecondCustomMetaObject(arg3)
            return __meta__
        end
    end
    @test_expression_generating add_meta_construction(input) output

    # Test 5: add_constraints_construction to constraint specification with function specification and arguments and keyword arguments
    input = quote 
        function somemeta(x, y; z)
            GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
            NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
            x -> MySecondCustomMetaObject(arg3)
        end
    end
    output = quote 
        function somemeta(x, y; z)
            __meta__ = GraphPPL.MetaSpecification()
            GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
            NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
            x -> MySecondCustomMetaObject(arg3)
            return __meta__
        end
    end
    @test_expression_generating add_meta_construction(input) output

    # Test 6: add_constraints_construction to constraint specification with function specification and only keyword arguments
    input = quote 
        function somemeta(; z)
            GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
            NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
            x -> MySecondCustomMetaObject(arg3)
        end
    end
    output = quote 
        function somemeta(; z)
            __meta__ = GraphPPL.MetaSpecification()
            GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
            NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
            x -> MySecondCustomMetaObject(arg3)
            return __meta__
        end
    end
    @test_expression_generating add_meta_construction(input) output
end

@testitem "create_submodel_meta" begin
    include("../../model_zoo.jl")
    import GraphPPL: create_submodel_meta, apply_pipeline
    # Test 1: create_submodel_meta with one nested layer
    input = quote
        __meta__ = GraphPPL.MetaSpecification()
        GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
        NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
        for meta in submodel
            NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
            x -> MySecondCustomMetaObject(arg3)
        end
        NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
        x -> MySecondCustomMetaObject(arg3)
        __meta__
    end
    output = quote
        __meta__ = GraphPPL.MetaSpecification()
        GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
        NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
        let __outer_meta__ = __meta__
            let __meta__ = GraphPPL.GeneralSubModelMeta(submodel)
                NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
                x -> MySecondCustomMetaObject(arg3)
                push!(__outer_meta__, __meta__)
            end
        end
        NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
        x -> MySecondCustomMetaObject(arg3)
        __meta__
    end
    @test_expression_generating apply_pipeline(input, create_submodel_meta) output

    # Test 2: create_submodel_meta with two nested layers
    input = quote
        __meta__ = GraphPPL.MetaSpecification()
        GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
        NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
        for meta in submodel
            GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
            NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
            for meta in (subsubmodel, 1)
                GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
                NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
            end
        end
        GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
        NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
        __meta__
    end
    output = quote
        __meta__ = GraphPPL.MetaSpecification()
        GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
        NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
        let __outer_meta__ = __meta__
            let __meta__ = GraphPPL.GeneralSubModelMeta(submodel)
                GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
                NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
                let __outer_meta__ = __meta__
                    let __meta__ = GraphPPL.SpecificSubModelMeta(GraphPPL.FactorID(subsubmodel, 1))
                        GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
                        NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
                        push!(__outer_meta__, __meta__)
                    end
                end
                push!(__outer_meta__, __meta__)
            end
        end
        GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
        NormalMeanVariance() -> MyCustomMetaObject(arg1, arg2)
        __meta__
    end
    @test_expression_generating apply_pipeline(input, create_submodel_meta) output
end

@testitem "convert_meta_variables" begin
    include("../../model_zoo.jl")
    import GraphPPL: convert_meta_variables, apply_pipeline

    # Test 1: convert_meta_variables with non-indexed variables in Factor meta call
    input = quote
        some_function(x, y) -> some_meta()
    end
    output = quote
        some_function(GraphPPL.IndexedVariable(:x, nothing), GraphPPL.IndexedVariable(:y, nothing)) -> some_meta()
    end
    @test_expression_generating apply_pipeline(input, convert_meta_variables) output

    # Test 2: convert_meta_variables with indexed variables in Factor meta call
    input = quote
        some_function(x[i], y[j]) -> some_meta()
    end
    output = quote
        some_function(GraphPPL.IndexedVariable(:x, i), GraphPPL.IndexedVariable(:y, j)) -> some_meta()
    end
    @test_expression_generating apply_pipeline(input, convert_meta_variables) output

    # Test 3: convert_meta_variables with non-indexed variables in Variable meta call
    input = quote
        x -> some_meta()
    end
    output = quote
        GraphPPL.IndexedVariable(:x, nothing) -> some_meta()
    end
    @test_expression_generating apply_pipeline(input, convert_meta_variables) output

    # Test 4: convert_meta_variables with indexed variables in Variable meta call
    input = quote
        x[i] -> some_meta()
    end
    output = quote
        GraphPPL.IndexedVariable(:x, i) -> some_meta()
    end
    @test_expression_generating apply_pipeline(input, convert_meta_variables) output
end

@testitem "convert_meta_object" begin
    include("../../model_zoo.jl")
    import GraphPPL: convert_meta_object, apply_pipeline

    # Test 1: convert_meta_object with Factor meta call

    input = quote
        some_function(GraphPPL.IndexedVariable(:x, nothing), GraphPPL.IndexedVariable(:y, nothing)) -> some_meta()
    end
    output = quote
        push!(
            __meta__,
            GraphPPL.MetaObject(
                GraphPPL.FactorMetaDescriptor(
                    some_function, (GraphPPL.IndexedVariable(:x, nothing), GraphPPL.IndexedVariable(:y, nothing))
                ),
                some_meta()
            )
        )
    end
    @test_expression_generating apply_pipeline(input, convert_meta_object) output

    # Test 2: convert_meta_object with Variable meta call
    input = quote
        GraphPPL.IndexedVariable(:x, nothing) -> some_meta()
    end
    output = quote
        push!(__meta__, GraphPPL.MetaObject(GraphPPL.VariableMetaDescriptor(GraphPPL.IndexedVariable(:x, nothing)), some_meta()))
    end
    @test_expression_generating apply_pipeline(input, convert_meta_object) output
end

@testitem "meta_macro_interior" begin
    include("../../model_zoo.jl")
    import GraphPPL: meta_macro_interior

    # Test 1: meta_macro_interor with one statement
    input = quote
        x -> some_meta()
    end
    output = quote
        __meta__ = GraphPPL.MetaSpecification()
        push!(__meta__, GraphPPL.MetaObject(GraphPPL.VariableMetaDescriptor(GraphPPL.IndexedVariable(:x, nothing)), some_meta()))
        __meta__
    end
    @test_expression_generating meta_macro_interior(input) output

    # Test 2: meta_macro_interor with multiple statements
    input = quote
        x -> some_meta()
        Normal(x, y) -> some_other_meta()
    end
    output = quote
        __meta__ = GraphPPL.MetaSpecification()
        push!(__meta__, GraphPPL.MetaObject(GraphPPL.VariableMetaDescriptor(GraphPPL.IndexedVariable(:x, nothing)), some_meta()))
        push!(
            __meta__,
            GraphPPL.MetaObject(
                GraphPPL.FactorMetaDescriptor(Normal, (GraphPPL.IndexedVariable(:x, nothing), GraphPPL.IndexedVariable(:y, nothing))),
                some_other_meta()
            )
        )
        __meta__
    end
    @test_expression_generating meta_macro_interior(input) output

    # Test 3: meta_macro_interor with multiple statements and a submodel definition
    input = quote
        x -> some_meta()
        Normal(x, y) -> some_other_meta()
        for meta in submodel
            x -> some_meta()
            Normal(x, y) -> some_other_meta()
        end
    end
    output = quote
        __meta__ = GraphPPL.MetaSpecification()
        push!(__meta__, GraphPPL.MetaObject(GraphPPL.VariableMetaDescriptor(GraphPPL.IndexedVariable(:x, nothing)), some_meta()))
        push!(
            __meta__,
            GraphPPL.MetaObject(
                GraphPPL.FactorMetaDescriptor(Normal, (GraphPPL.IndexedVariable(:x, nothing), GraphPPL.IndexedVariable(:y, nothing))),
                some_other_meta()
            )
        )
        let __outer_meta__ = __meta__
            let __meta__ = GraphPPL.GeneralSubModelMeta(submodel)
                push!(__meta__, GraphPPL.MetaObject(GraphPPL.VariableMetaDescriptor(GraphPPL.IndexedVariable(:x, nothing)), some_meta()))
                push!(
                    __meta__,
                    GraphPPL.MetaObject(
                        GraphPPL.FactorMetaDescriptor(
                            Normal, (GraphPPL.IndexedVariable(:x, nothing), GraphPPL.IndexedVariable(:y, nothing))
                        ),
                        some_other_meta()
                    )
                )
                push!(__outer_meta__, __meta__)
            end
        end
        __meta__
    end
    @test_expression_generating meta_macro_interior(input) output
end
