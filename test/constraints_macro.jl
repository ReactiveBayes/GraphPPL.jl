module test_constraints_macro

using Test
using GraphPPL
using TestSetExtensions
using MacroTools
include("model_zoo.jl")

@testset ExtendedTestSet "constraints_macro.jl" begin

    @testset "check_for_returns" begin
        import GraphPPL: check_for_returns, apply_pipeline

        # Test 1: check_for_returns with no returns
        input = quote
            q(x, y) = q(x)q(y)
            q(x)::PointMass
        end
        output = input
        @test_expression_generating apply_pipeline(input, check_for_returns) output

        # Test 2: check_for_returns with one return
        input = quote
            q(x, y) = q(x)q(y)
            q(x)::PointMass
            return q(x)
        end
        @test_throws ErrorException apply_pipeline(input, check_for_returns)

        # Test 3: check_for_returns with two returns
        input = quote
            return abc
            return 1
            q(x, y) = q(x)q(y)
            q(x)::PointMass
        end
        @test_throws ErrorException apply_pipeline(input, check_for_returns)
    end

    @testset "add_constraints_construction" begin
        import GraphPPL: add_constraints_construction

        # Test 1: add_constraints_construction to regular constraint specification
        input = quote
            q(x, y) = q(x)q(y)
            q(x)::PointMass
        end
        output = quote
            __constraints__ = GraphPPL.Constraints()
            q(x, y) = q(x)q(y)
            q(x)::PointMass
            __constraints__
        end
        @test_expression_generating add_constraints_construction(input) output

        # Test 2: add_constraints_construction to constraint specification with nested model specification
        input = quote
            q(x, y) = q(x)q(y)
            q(x)::PointMass
            for q in submodel
                q(x, y) = q(x)q(y)
                q(x)::PointMass
            end
        end
        output = quote
            __constraints__ = GraphPPL.Constraints()
            q(x, y) = q(x)q(y)
            q(x)::PointMass
            for q in submodel
                q(x, y) = q(x)q(y)
                q(x)::PointMass
            end
            __constraints__
        end
        @test_expression_generating add_constraints_construction(input) output
    end

    @testset "replace_begin_end" begin
        import GraphPPL: replace_begin_end, apply_pipeline

        # Test 1: replace_begin_end with one begin and end
        input = quote
            q(x) = q(x[begin]) .. q(x[end])
        end
        output = quote
            q(x) =
                q(x[GraphPPL.FunctionalIndex{:begin}(firstindex)]) ..
                q(x[GraphPPL.FunctionalIndex{:end}(lastindex)])
        end
        @test_expression_generating apply_pipeline(input, replace_begin_end) output

        # Test 2: replace_begin_end with two begins and ends
        input = quote
            q(x) = q(x[begin, begin]) .. q(x[end, end])
        end
        output = quote
            q(x) =
                q(
                    x[
                        GraphPPL.FunctionalIndex{:begin}(firstindex),
                        GraphPPL.FunctionalIndex{:begin}(firstindex),
                    ],
                ) .. q(
                    x[
                        GraphPPL.FunctionalIndex{:end}(lastindex),
                        GraphPPL.FunctionalIndex{:end}(lastindex),
                    ],
                )
        end
        @test_expression_generating apply_pipeline(input, replace_begin_end) output

        # Test 3: replace_begin_end with mixed begin and ends
        input = quote
            q(x) = q(x[begin, 1]) .. q(x[end, 2])
        end
        output = quote
            q(x) =
                q(x[GraphPPL.FunctionalIndex{:begin}(firstindex), 1]) ..
                q(x[GraphPPL.FunctionalIndex{:end}(lastindex), 2])
        end
        @test_expression_generating apply_pipeline(input, replace_begin_end) output

        # Test 4: replace_begin_end with composite index 
        input = quote
            q(x) = q(x[begin+1])q(x[end-1])q(x[1])q(x[end])
        end
        output = quote
            q(x) =
                q(x[GraphPPL.FunctionalIndex{:begin}(firstindex)+1]) *
                q(x[GraphPPL.FunctionalIndex{:end}(lastindex)-1]) *
                q(x[1]) *
                q(x[GraphPPL.FunctionalIndex{:end}(lastindex)])
        end
        @test_expression_generating apply_pipeline(input, replace_begin_end) output
    end

    @testset "create_submodel_constraints" begin
        import GraphPPL: create_submodel_constraints, apply_pipeline

        # Test 1: create_submodel_constraints with one nested layer
        input = quote
            __constraints__ = GraphPPL.Constraints()
            q(x, y) = q(x)q(y)
            q(x)::PointMass
            for q in submodel
                q(z) = q(z[begin]) .. q(z[end])
            end
            q(a, b, c) = q(a)q(b)q(c)
            return __constraints__
        end
        output = quote
            __constraints__ = GraphPPL.Constraints()
            q(x, y) = q(x)q(y)
            q(x)::PointMass
            let __outer_constraints__ = __constraints__
                let __constraints__ = begin
                        try
                            GraphPPL.SubModelConstraints(submodel)
                        catch
                            GraphPPL.SubModelConstraints(:submodel)
                        end
                    end
                    q(z) = q(z[begin]) .. q(z[end])
                    push!(__outer_constraints__, __constraints__)
                end
            end
            q(a, b, c) = q(a)q(b)q(c)
            return __constraints__
        end
        @test_expression_generating apply_pipeline(input, create_submodel_constraints) output

        # Test 2: create_submodel_constraints with two nested layers
        input = quote
            __constraints__ = GraphPPL.Constraints()
            q(x, y) = q(x)q(y)
            for q in submodel
                q(z) = q(z[begin]) .. q(z[end])
                for q in subsubmodel
                    q(w) = q(w[begin]) .. q(w[end])
                end
            end
            q(a, b, c) = q(a)q(b)q(c)
            return __constraints__
        end
        output = quote
            __constraints__ = GraphPPL.Constraints()
            q(x, y) = q(x)q(y)
            let __outer_constraints__ = __constraints__
                let __constraints__ = begin
                        try
                            GraphPPL.SubModelConstraints(submodel)
                        catch
                            GraphPPL.SubModelConstraints(:submodel)
                        end
                    end
                    q(z) = q(z[begin]) .. q(z[end])
                    let __outer_constraints__ = __constraints__
                        let __constraints__ = begin
                                try
                                    GraphPPL.SubModelConstraints(subsubmodel)
                                catch
                                    GraphPPL.SubModelConstraints(:subsubmodel)
                                end
                            end
                            q(w) = q(w[begin]) .. q(w[end])
                            push!(__outer_constraints__, __constraints__)
                        end
                    end
                    push!(__outer_constraints__, __constraints__)
                end
            end
            q(a, b, c) = q(a)q(b)q(c)
            return __constraints__
        end
        @test_expression_generating apply_pipeline(input, create_submodel_constraints) output
    end

    @testset "create_factorization_split" begin
        import GraphPPL: create_factorization_split, apply_pipeline

        # Test 1: create_factorization_split with one factorization split
        input = quote
            q(x) = q(x[begin]) .. q(x[end])
        end
        output = quote
            q(x) = GraphPPL.factorization_split(q(x[begin]), q(x[end]))
        end
        @test_expression_generating apply_pipeline(input, create_factorization_split) output

        # Test 2: create_factorization_split with two factorization splits
        input = quote
            q(x, y) = q(x[begin], y[begin]) .. q(x[end], y[end])
        end
        output = quote
            q(x, y) = GraphPPL.factorization_split(q(x[begin], y[begin]), q(x[end], y[end]))
        end
        @test_expression_generating apply_pipeline(input, create_factorization_split) output

        # Test 3: create_factorization_split with two a factorization split and more entries
        input = quote
            q(x, y, z) = q(y)q(x[begin]) .. q(x[end])q(z)
        end
        output = quote
            q(x, y, z) = GraphPPL.factorization_split(q(y)q(x[begin]), q(x[end])q(z))
        end
        @test_expression_generating apply_pipeline(input, create_factorization_split) output

        # Test 4: create_factorization_split with two factorization splits and more entries
    end

    @testset "create_factorization_combinedrange" begin
        import GraphPPL: create_factorization_combinedrange, apply_pipeline

        # Test 1: create_factorization_combinedrange with one combined range
        input = quote
            q(x) = q(x[begin:end])
        end
        output = quote
            q(x) = q(x[GraphPPL.CombinedRange(begin, end)])
        end
        @test_expression_generating apply_pipeline(
            input,
            create_factorization_combinedrange,
        ) output
    end

    @testset "convert_variable_statements" begin
        import GraphPPL: convert_variable_statements, apply_pipeline

        # Test 1: convert_variable_statements with a single variable statement
        input = quote
            q(x) = factorization_split(
                q(x[GraphPPL.FunctionalIndex{:begin}(firstindex)]),
                q(x[GraphPPL.FunctionalIndex{:end}(lastindex)]),
            )
        end
        output = quote
            q(GraphPPL.IndexedVariable(:x, nothing)) = factorization_split(
                q(
                    GraphPPL.IndexedVariable(
                        :x,
                        GraphPPL.FunctionalIndex{:begin}(firstindex),
                    ),
                ),
                q(GraphPPL.IndexedVariable(:x, GraphPPL.FunctionalIndex{:end}(lastindex))),
            )
        end
        @test_expression_generating apply_pipeline(input, convert_variable_statements) output

        # Test 2: convert_variable_statements with a multi-indexed variable statement
        input = quote
            q(x, y) = q(x)q(y[1, 1])q(y[2, 2])
        end
        output = quote
            q(GraphPPL.IndexedVariable(:x, nothing), GraphPPL.IndexedVariable(:y, nothing)) =
                q(
                    GraphPPL.IndexedVariable(:x, nothing),
                )q(
                    GraphPPL.IndexedVariable(:y, [1, 1]),
                )q(GraphPPL.IndexedVariable(:y, [2, 2]))
        end
        @test_expression_generating apply_pipeline(input, convert_variable_statements) output

        # Test 3: convert_variable_statements with a message constraint
        input = quote
            μ(x)::PointMass
        end
        output = quote
            μ(GraphPPL.IndexedVariable(:x, nothing))::PointMass
        end
        @test_expression_generating apply_pipeline(input, convert_variable_statements) output

        # Test 4: convert_variable_statements with a message constraint with indcides
        input = quote
            μ(x[1, 1])::PointMass
        end
        output = quote
            μ(GraphPPL.IndexedVariable(:x, [1, 1]))::PointMass
        end
        @test_expression_generating apply_pipeline(input, convert_variable_statements) output

        # Test 5: convert_variable_statements with a CombinedRange
        input = quote
            μ(x[CombinedRange(1, 2)])::PointMass
        end
        output = quote
            μ(GraphPPL.IndexedVariable(:x, CombinedRange(1, 2)))::PointMass
        end
        @test_expression_generating apply_pipeline(input, convert_variable_statements) output

        # Test 6: convert_variable_statements with a CombinedRange
        input = quote
            q(x) = q(x[CombinedRange(1, 2)])
        end
        output = quote
            q(GraphPPL.IndexedVariable(:x, nothing)) =
                q(GraphPPL.IndexedVariable(:x, CombinedRange(1, 2)))
        end
        @test_expression_generating apply_pipeline(input, convert_variable_statements) output

    end

    @testset "convert_functionalform_constraints" begin
        import GraphPPL: convert_functionalform_constraints, apply_pipeline, IndexedVariable

        # Test 1: convert_functionalform_constraints with a single functional form constraint
        input = quote
            q(GraphPPL.IndexedVariable(:x, nothing))::PointMass
        end
        output = quote
            push!(
                __constraints__,
                GraphPPL.FunctionalFormConstraint(
                    GraphPPL.IndexedVariable(:x, nothing),
                    PointMass,
                ),
            )
        end
        @test_expression_generating apply_pipeline(
            input,
            convert_functionalform_constraints,
        ) output

        # Test 2: convert_functionalform_constraints with a functional form constraint over multiple variables
        input = quote
            q(
                GraphPPL.IndexedVariable(:x, nothing),
                GraphPPL.IndexedVariable(:y, nothing),
            )::PointMass
        end
        output = quote
            push!(
                __constraints__,
                GraphPPL.FunctionalFormConstraint(
                    [
                        GraphPPL.IndexedVariable(:x, nothing),
                        GraphPPL.IndexedVariable(:y, nothing),
                    ],
                    PointMass,
                ),
            )
        end
        @test_expression_generating apply_pipeline(
            input,
            convert_functionalform_constraints,
        ) output

        # Test 3: convert_functionalform_constraints with a functional form constraint in a nested constraint specification
        input = quote
            q(
                GraphPPL.IndexedVariable(:x, nothing),
                GraphPPL.IndexedVariable(:y, nothing),
            )::PointMass
            let __outer_constraints__ = __constraints__
                let __constraints__ = begin
                        try
                            GraphPPL.SubModelConstraints(submodel)
                        catch
                            GraphPPL.SubModelConstraints(:submodel)
                        end
                    end
                    q(
                        GraphPPL.IndexedVariable(:x, nothing),
                        GraphPPL.IndexedVariable(:y, nothing),
                    )::PointMass
                    let __outer_constraints__ = __constraints__
                        let __constraints__ = begin
                                try
                                    GraphPPL.SubModelConstraints(subsubmodel)
                                catch
                                    GraphPPL.SubModelConstraints(:subsubmodel)
                                end
                            end
                            q(
                                GraphPPL.IndexedVariable(:x, nothing),
                                GraphPPL.IndexedVariable(:y, nothing),
                            )::PointMass
                            push!(__outer_constraints__, __constraints__)
                        end
                    end
                    push!(__outer_constraints__, __constraints__)
                end
            end
        end
        output = quote
            push!(
                __constraints__,
                GraphPPL.FunctionalFormConstraint(
                    [
                        GraphPPL.IndexedVariable(:x, nothing),
                        GraphPPL.IndexedVariable(:y, nothing),
                    ],
                    PointMass,
                ),
            )
            let __outer_constraints__ = __constraints__
                let __constraints__ = begin
                        try
                            GraphPPL.SubModelConstraints(submodel)
                        catch
                            GraphPPL.SubModelConstraints(:submodel)
                        end
                    end
                    push!(
                        __constraints__,
                        GraphPPL.FunctionalFormConstraint(
                            [
                                GraphPPL.IndexedVariable(:x, nothing),
                                GraphPPL.IndexedVariable(:y, nothing),
                            ],
                            PointMass,
                        ),
                    )
                    let __outer_constraints__ = __constraints__
                        let __constraints__ = begin
                                try
                                    GraphPPL.SubModelConstraints(subsubmodel)
                                catch
                                    GraphPPL.SubModelConstraints(:subsubmodel)
                                end
                            end
                            push!(
                                __constraints__,
                                GraphPPL.FunctionalFormConstraint(
                                    [
                                        GraphPPL.IndexedVariable(:x, nothing),
                                        GraphPPL.IndexedVariable(:y, nothing),
                                    ],
                                    PointMass,
                                ),
                            )
                            push!(__outer_constraints__, __constraints__)
                        end
                    end
                    push!(__outer_constraints__, __constraints__)
                end
            end
        end
        @test_expression_generating apply_pipeline(
            input,
            convert_functionalform_constraints,
        ) output
    end

    @testset "convert_message_constraints" begin
        import GraphPPL: convert_message_constraints, apply_pipeline, IndexedVariable

        # Test 1: convert_message_constraints with a single functional form constraint
        input = quote
            μ(GraphPPL.IndexedVariable(:x, nothing))::PointMass
        end
        output = quote
            push!(
                __constraints__,
                GraphPPL.MessageConstraint(
                    GraphPPL.IndexedVariable(:x, nothing),
                    PointMass,
                ),
            )
        end
        @test_expression_generating apply_pipeline(input, convert_message_constraints) output

        # Test 2: convert_message_constraints with a functional form constraint over multiple variables
        input = quote
            μ(
                GraphPPL.IndexedVariable(:x, nothing),
                GraphPPL.IndexedVariable(:y, nothing),
            )::PointMass
        end
        output = quote
            push!(
                __constraints__,
                GraphPPL.MessageConstraint(
                    [
                        GraphPPL.IndexedVariable(:x, nothing),
                        GraphPPL.IndexedVariable(:y, nothing),
                    ],
                    PointMass,
                ),
            )
        end
        @test_expression_generating apply_pipeline(input, convert_message_constraints) output

        # Test 3: convert_message_constraints with a functional form constraint in a nested constraint specification
        input = quote
            μ(
                GraphPPL.IndexedVariable(:x, nothing),
                GraphPPL.IndexedVariable(:y, nothing),
            )::PointMass
            let __outer_constraints__ = __constraints__
                let __constraints__ = begin
                        try
                            GraphPPL.SubModelConstraints(submodel)
                        catch
                            GraphPPL.SubModelConstraints(:submodel)
                        end
                    end
                    μ(
                        GraphPPL.IndexedVariable(:x, nothing),
                        GraphPPL.IndexedVariable(:y, nothing),
                    )::PointMass
                    let __outer_constraints__ = __constraints__
                        let __constraints__ = begin
                                try
                                    GraphPPL.SubModelConstraints(subsubmodel)
                                catch
                                    GraphPPL.SubModelConstraints(:subsubmodel)
                                end
                            end
                            μ(
                                GraphPPL.IndexedVariable(:x, nothing),
                                GraphPPL.IndexedVariable(:y, nothing),
                            )::PointMass
                            push!(__outer_constraints__, __constraints__)
                        end
                    end
                    push!(__outer_constraints__, __constraints__)
                end
            end
        end
        output = quote
            push!(
                __constraints__,
                GraphPPL.MessageConstraint(
                    [
                        GraphPPL.IndexedVariable(:x, nothing),
                        GraphPPL.IndexedVariable(:y, nothing),
                    ],
                    PointMass,
                ),
            )
            let __outer_constraints__ = __constraints__
                let __constraints__ = begin
                        try
                            GraphPPL.SubModelConstraints(submodel)
                        catch
                            GraphPPL.SubModelConstraints(:submodel)
                        end
                    end
                    push!(
                        __constraints__,
                        GraphPPL.MessageConstraint(
                            [
                                GraphPPL.IndexedVariable(:x, nothing),
                                GraphPPL.IndexedVariable(:y, nothing),
                            ],
                            PointMass,
                        ),
                    )
                    let __outer_constraints__ = __constraints__
                        let __constraints__ = begin
                                try
                                    GraphPPL.SubModelConstraints(subsubmodel)
                                catch
                                    GraphPPL.SubModelConstraints(:subsubmodel)
                                end
                            end
                            push!(
                                __constraints__,
                                GraphPPL.MessageConstraint(
                                    [
                                        GraphPPL.IndexedVariable(:x, nothing),
                                        GraphPPL.IndexedVariable(:y, nothing),
                                    ],
                                    PointMass,
                                ),
                            )
                            push!(__outer_constraints__, __constraints__)
                        end
                    end
                    push!(__outer_constraints__, __constraints__)
                end
            end
        end
        @test_expression_generating apply_pipeline(input, convert_message_constraints) output
    end

    @testset "convert_factorization_constraints" begin
        import GraphPPL: convert_factorization_constraints, apply_pipeline, IndexedVariable

        # Test 1: convert_factorization_constraints with a single factorization constraint
        input = quote
            q(GraphPPL.IndexedVariable(:x, nothing), GraphPPL.IndexedVariable(:y, nothing)) = [
                q(GraphPPL.IndexedVariable(:x, nothing)),
                q(GraphPPL.IndexedVariable(:y, nothing)),
            ]
        end
        output = quote
            push!(
                __constraints__,
                GraphPPL.FactorizationConstraint(
                    [
                        GraphPPL.IndexedVariable(:x, nothing),
                        GraphPPL.IndexedVariable(:y, nothing),
                    ],
                    [
                        GraphPPL.FactorizationConstraintEntry([
                            GraphPPL.IndexedVariable(:x, nothing),
                        ]),
                        GraphPPL.FactorizationConstraintEntry([
                            GraphPPL.IndexedVariable(:y, nothing),
                        ]),
                    ],
                ),
            )
        end
        @test_expression_generating apply_pipeline(input, convert_factorization_constraints) output

        # Test 2: convert_factorization_constraints with a factorization constraint that has no multiplication
        input = quote
            q(GraphPPL.IndexedVariable(:x, nothing)) =
                [q(GraphPPL.IndexedVariable(:x, nothing))]
        end
        output = quote
            push!(
                __constraints__,
                GraphPPL.FactorizationConstraint(
                    [GraphPPL.IndexedVariable(:x, nothing)],
                    [
                        GraphPPL.FactorizationConstraintEntry([
                            GraphPPL.IndexedVariable(:x, nothing),
                        ]),
                    ],
                ),
            )
        end
        @test_expression_generating apply_pipeline(input, convert_factorization_constraints) output
    end

    @testset "constraints_macro_interior" begin
        import GraphPPL: constraints_macro_interior

        input = quote
            q(x)::Normal
            for q in second_submodel
                q(w, a, b) = q(a, b)q(w)
            end
        end
        output = quote
            __constraints__ = GraphPPL.Constraints()
            push!(
                __constraints__,
                GraphPPL.FunctionalFormConstraint(
                    GraphPPL.IndexedVariable(:x, nothing),
                    Normal,
                ),
            )
            let __outer_constraints__ = __constraints__
                let __constraints__ = try
                        GraphPPL.SubModelConstraints(second_submodel)
                    catch
                        GraphPPL.SubModelConstraints(:second_submodel)
                    end
                    push!(
                        __constraints__,
                        GraphPPL.FactorizationConstraint(
                            [
                                GraphPPL.IndexedVariable(:w, nothing),
                                GraphPPL.IndexedVariable(:a, nothing),
                                GraphPPL.IndexedVariable(:b, nothing),
                            ],
                            GraphPPL.FactorizationConstraintEntry([
                                GraphPPL.IndexedVariable(:a, nothing),
                                GraphPPL.IndexedVariable(:b, nothing),
                            ]) * GraphPPL.FactorizationConstraintEntry([
                                GraphPPL.IndexedVariable(:w, nothing),
                            ]),
                        ),
                    )
                    push!(__outer_constraints__, __constraints__)
                end
            end
            __constraints__
        end

        @test_expression_generating constraints_macro_interior(input) output
    end
    
    @testset "constraints_macro" begin
        
        import GraphPPL: Constraints
        constraints = @constraints begin
            q(x, y) = q(x)q(y)
            q(x) = q(x[begin]) .. q(x[end])
            q(μ) :: PointMass
            for q  in submodel
                q(u, v, k) = q(u)q(v)q(k)
            end
        end
        @test constraints isa Constraints
    end
end

end
