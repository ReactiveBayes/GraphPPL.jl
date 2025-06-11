@testitem "SmallDict #1" begin
    import GraphPPL: SmallDict
    using GraphPPL.Dictionaries

    dict = SmallDict{String, Int}()

    set!(dict, "one", 1)

    @test dict["one"] == 1
    @test haskey(dict, "one")
    @test !haskey(dict, "two")

    set!(dict, "two", 2)

    @test dict["two"] == 2
    @test haskey(dict, "two")
    @test !haskey(dict, "three")

    @test @allocated(dict["one"]) == 0
    @test @allocated(dict["two"]) == 0
    @test @allocated(haskey(dict, "one")) == 0
    @test @allocated(haskey(dict, "two")) == 0
    @test @allocated(set!(dict, "one", 1)) == 0
    @test @allocated(set!(dict, "two", 2)) == 0
end

@testitem "SmallDict #2" begin
    import GraphPPL: SmallDict
    using GraphPPL.Dictionaries

    dict = SmallDict{Symbol, Int}()

    set!(dict, :one, 1)

    @test dict[:one] == 1
    @test haskey(dict, :one)
    @test !haskey(dict, :two)

    set!(dict, :two, 2)

    @test dict[:two] == 2
    @test haskey(dict, :two)
    @test !haskey(dict, :three)

    @test @allocated(dict[:one]) == 0
    @test @allocated(dict[:two]) == 0
    @test @allocated(haskey(dict, :one)) == 0
    @test @allocated(haskey(dict, :two)) == 0
    @test @allocated(haskey(dict, :three)) == 0
    @test @allocated(set!(dict, :one, 1)) == 0
    @test @allocated(set!(dict, :two, 2)) == 0
end

@testitem "SmallDict #3" begin
    import GraphPPL: SmallDict
    using GraphPPL.Dictionaries

    dict = SmallDict{Symbol, Int}()

    set!(dict, :one, 1)

    @test get(() -> 0, dict, :one) == 1
    @test get(() -> 0, dict, :two) == 0

    fn = () -> 0

    @test get(fn, dict, :one) == 1
    @test get(fn, dict, :two) == 0

    @test @allocated(get(fn, dict, :one)) == 0
    @test @allocated(get(fn, dict, :two)) == 0
    @test @allocated(get(fn, dict, :three)) == 0
end

@testitem "SmallDict #4" begin
    import GraphPPL: SmallDict
    using GraphPPL.Dictionaries

    dict = SmallDict{Symbol, Int}()

    dict[:one] = 1

    @test dict[:one] == 1
end