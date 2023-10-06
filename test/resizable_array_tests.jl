@testitem "ResizableArray.jl" begin
    # Write your tests here.
    import GraphPPL: ResizableArray, get_recursive_depth

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

        v[2, 1] = 1.0
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

    using GraphPPL
    let v = ResizableArray(GraphPPL.NodeLabel, Val(1))

        for i = 1:10
            v[i] = GraphPPL.NodeLabel(:x, i)
        end
        @test size(v) == (10,)
        tuple(v...) == (
            GraphPPL.NodeLabel(:x, 1),
            GraphPPL.NodeLabel(:x, 2),
            GraphPPL.NodeLabel(:x, 3),
            GraphPPL.NodeLabel(:x, 4),
            GraphPPL.NodeLabel(:x, 5),
            GraphPPL.NodeLabel(:x, 6),
            GraphPPL.NodeLabel(:x, 7),
            GraphPPL.NodeLabel(:x, 8),
            GraphPPL.NodeLabel(:x, 9),
            GraphPPL.NodeLabel(:x, 10),
        )
    end

    let v = ResizableArray(GraphPPL.NodeLabel, Val(2))
        for i = 1:10
            v[i, i] = GraphPPL.NodeLabel(:x, i)
        end
        @test isassigned(v, 1, 1)
        @test !isassigned(v, 2, 1)
        @test vec(v) == [
            GraphPPL.NodeLabel(:x, 1),
            GraphPPL.NodeLabel(:x, 2),
            GraphPPL.NodeLabel(:x, 3),
            GraphPPL.NodeLabel(:x, 4),
            GraphPPL.NodeLabel(:x, 5),
            GraphPPL.NodeLabel(:x, 6),
            GraphPPL.NodeLabel(:x, 7),
            GraphPPL.NodeLabel(:x, 8),
            GraphPPL.NodeLabel(:x, 9),
            GraphPPL.NodeLabel(:x, 10),
        ]
        @test GraphPPL.NodeLabel(:x, 1) ∈ vec(v)
    end

    let v = ResizableArray(GraphPPL.NodeLabel, Val(2))
        v[1, 1] = GraphPPL.NodeLabel(:x, 1)
        v[1, 2] = GraphPPL.NodeLabel(:x, 2)
        v[1, 3] = GraphPPL.NodeLabel(:x, 3)
        v[2, 1] = GraphPPL.NodeLabel(:x, 4)
        v[2, 2] = GraphPPL.NodeLabel(:x, 5)
        v[2, 3] = GraphPPL.NodeLabel(:x, 6)

        broadcast(x -> 1, v)
    end

    data = [i for i = 1:10]
    @test get_recursive_depth(data) == 1
    @test ResizableArray(data) isa ResizableArray{Int,Vector{Int},1}

    data = [[i for i = 1:10] for j = 1:10]
    @test get_recursive_depth(data) == 2
    @test ResizableArray(data) isa ResizableArray{Int,Vector{Vector{Int}},2}

    let v = ResizableArray(GraphPPL.NodeLabel, Val(1))

        for i = 1:10
            v[i] = GraphPPL.NodeLabel(:x, i)
        end
        @test v[2:6] isa ResizableArray{GraphPPL.NodeLabel,Vector{GraphPPL.NodeLabel},1}
        @test v[begin:end] isa
              ResizableArray{GraphPPL.NodeLabel,Vector{GraphPPL.NodeLabel},1}

    end

end