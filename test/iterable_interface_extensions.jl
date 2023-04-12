module test_iterable_interface_extensions

using Test
using GraphPPL
using LinearAlgebra

@testset "iterable_interface_extensions.jl" begin
    import GraphPPL: is_iterable, Iterable, NotIterable

    @test is_iterable([1, 2, 3]) === Iterable()
    @test is_iterable(Matrix(I, 3, 3)) === Iterable()
    @test is_iterable(1) === NotIterable()
    @test is_iterable(("a",)) === Iterable()

    @test is_iterable((a = "b",)) === Iterable()
end

end
