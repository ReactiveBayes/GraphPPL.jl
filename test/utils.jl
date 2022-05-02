module UtilsTests

using Test
using GraphPPL

@testset "issymbol tests" begin
    import GraphPPL: issymbol

    @test issymbol(:(f(1))) === false
    @test issymbol(:(f(1))) === false
    @test issymbol(:(if true 1 else 2 end)) === false
    @test issymbol(:hello) === true
    @test issymbol(:a) === true
    @test issymbol(123) === false
end

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

@testset "ensure_type tests" begin 
    import GraphPPL: ensure_type

    @test ensure_type(Int) === true
    @test ensure_type(1) === false
    @test ensure_type(Float64) === true
    @test ensure_type(1.0) === false
end

end
