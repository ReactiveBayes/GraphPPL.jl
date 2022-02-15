module UtilsTests

using Test
using GraphPPL

@testset "isexpr tests" begin
    import GraphPPL: isexpr

    @test isexpr(:(f(1))) === true
    @test isexpr(:(f(1))) === true
    @test isexpr(:(if true 1 else 2 end)) === true
    @test isexpr(:hello) === false
    @test isexpr(123) === false
end

@testset "ishead tests" begin
    import GraphPPL: ishead

    @test ishead(:(f(1)), :call) === true
    @test ishead(:(f(1)), :if) === false
    @test ishead(:(begin end), :if) === false
    @test ishead(:(if true 1 else 2 end), :if) === true
    @test ishead(:(begin end), :block) === true
end

@testset "isblock tests" begin 
    import GraphPPL: isblock

    @test isblock(:(f(1))) === false
    @test isblock(:(if true 1 else 2 end)) === false
    @test isblock(:(begin end)) === true
end


@testset "iscall tests" begin 
    import GraphPPL: iscall

    @test iscall(:(f(1))) === true
    @test iscall(:(f(1)), :f) === true
    @test iscall(:(f(1)), :g) === false
    @test iscall(:(if true 1 else 2 end)) === false
    @test iscall(:(begin end)) === false

end

end