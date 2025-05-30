using GraphPPL
using Test
using Aqua
using JET
using TestItemRunner

@testset "GraphPPL.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(GraphPPL; ambiguities = (broken = true,))
    end

    # @testset "Code linting (JET.jl)" begin
    #     JET.test_package(GraphPPL; target_defined_modules = true)
    # end

    TestItemRunner.@run_package_tests()
end