using Test

@testset "ResizableArray.jl" begin
    # Write your tests here.
    import GraphPPL: ResizableArray

    @test ResizableArray(Float64) isa ResizableArray{Float64}
    @test ResizableArray(Float64, Val(1)) isa ResizableArray{Float64,Vector{Float64},1}
    @test ResizableArray(Float64, Val(2)) isa
          ResizableArray{Float64,Vector{Vector{Float64}},2}

    @test occursin("[]", repr(ResizableArray(Float64)))

    @test size(ResizableArray(Float64)) === (0,)

    for i = 1:10
        @test size(ResizableArray(Float64, Val(i))) === ntuple(_ -> 0, i)
    end

    let v = ResizableArray(Float64)
        @test size(v) === (0,)

        v[3] = 1.0

        @test size(v) === (3,)

        v[2] = 1.0

        @test size(v) === (3,)

        v[10] = 1.0

        @test size(v) === (10,)

        @test_throws Exception (v[10, 2] = 1.0)
    end

    let v = ResizableArray(Float64, Val(2))
        @test size(v) === (0, 0)

        v[3, 2] = 1.0

        @test size(v) === (3, 2)

        v[2, 2] = 1.0

        @test size(v) === (3, 2)

        v[10, 1] = 1.0

        @test size(v) === (10, 2)

        v[10, 10] = 1.0

        @test size(v) === (10, 10)

        @test_throws Exception (v[10] = 1.0)
    end


    let v = ResizableArray(Float64, Val(3))
        @test size(v) === (0, 0, 0)

        v[3, 2, 5] = 1.0

        @test size(v) === (3, 2, 5)

        v[2, 2, 4] = 1.0

        @test size(v) === (3, 2, 5)

        v[10, 1, 5] = 1.0

        @test size(v) === (10, 2, 5)

        v[10, 10, 10] = 1.0

        @test size(v) === (10, 10, 10)
        v[10, 10, 10]

        @test_throws Exception (v[1] = 1.0)
        @test_throws Exception (v[1, 1] = 1.0)
        @test_throws Exception (v[1, 1, 1, 1] = 1.0)
    end

    let v = ResizableArray(Float64, Val(2))
        v[1, 1] = 1.0
        v[1, 2] = 2.0
        v[1, 3] = 3.0
        v[1, 4] = 4.0
        v[2, 1] = 5.0
        v[2, 2] = 6.0
        v[2, 3] = 7.0
        @test size(v) === (2, 4)
    end


    let v = ResizableArray(Float64, Val(3))
        @test size(v) === (0, 0, 0)

        v[3, 2, 5] = 1.0

        @test v[3, 2, 5] == 1.0
        @test_throws BoundsError v[3, 2, 6]
        @test_throws BoundsError v[1, 1, 1]
        @test v[3, 2] isa Vector{Float64}
        @test_throws BoundsError v[1, 3]

        @test_throws ArgumentError v["a"]
        @test_throws ArgumentError v[3, 2, "a"]

    end

    let v = ResizableArray(Float64, Val(1))
        @test size(v) === (0,)

        for i = 1:10
            @test_throws MethodError v[i] = i
        end
    end
end
