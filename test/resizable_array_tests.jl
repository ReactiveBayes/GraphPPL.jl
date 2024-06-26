@testitem "ResizableArray.jl" begin
    # Write your tests here.
    import GraphPPL: ResizableArray, get_recursive_depth

    @test ResizableArray(Float64) isa ResizableArray{Float64}
    @test ResizableArray(Float64, Val(1)) isa ResizableArray{Float64, Vector{Float64}, 1}
    @test ResizableArray(Float64, Val(2)) isa ResizableArray{Float64, Vector{Vector{Float64}}, 2}

    @test occursin("[]", repr(ResizableArray(Float64)))

    @test size(ResizableArray(Float64)) === (0,)

    for i in 1:10
        @test size(ResizableArray(Float64, Val(i))) === ntuple(_ -> 0, i)
    end

    let v = ResizableArray(Float64)
        @test @inferred(setindex!(v, 1.0, 1)) === v
        @test @inferred(setindex!(v, 2.0, 2)) === v

        @test @inferred(getindex(v, 1)) === 1.0
        @test @inferred(getindex(v, 2)) === 2.0
    end

    let v = ResizableArray(Float64, Val(2))
        @test @inferred(setindex!(v, 1.0, 1, 1)) === v
        @test @inferred(setindex!(v, 2.0, 2, 2)) === v

        @test @inferred(getindex(v, 1, 1)) === 1.0
        @test @inferred(getindex(v, 2, 2)) === 2.0
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

        for i in 1:10
            @test_throws MethodError v[i] = i
        end
    end

    using GraphPPL
    let v = ResizableArray(GraphPPL.NodeLabel, Val(1))
        for i in 1:10
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
            GraphPPL.NodeLabel(:x, 10)
        )
    end

    let v = ResizableArray(GraphPPL.NodeLabel, Val(2))
        for i in 1:10
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
            GraphPPL.NodeLabel(:x, 10)
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

        v = broadcast(x -> 1, v)

        @test v[1, 1] == 1
        @test v[1, 2] == 1
        @test v[1, 3] == 1
        @test v[2, 1] == 1
        @test v[2, 2] == 1
        @test v[2, 3] == 1
    end

    data = [i for i in 1:10]
    @test get_recursive_depth(data) == 1
    @test ResizableArray(data) isa ResizableArray{Int, Vector{Int}, 1}

    data = [[i for i in 1:10] for j in 1:10]
    @test get_recursive_depth(data) == 2
    @test ResizableArray(data) isa ResizableArray{Int, Vector{Vector{Int}}, 2}

    let v = ResizableArray(GraphPPL.NodeLabel, Val(1))
        for i in 1:10
            v[i] = GraphPPL.NodeLabel(:x, i)
        end
        @test v[2:6] isa ResizableArray{GraphPPL.NodeLabel, Vector{GraphPPL.NodeLabel}, 1}
        @test v[begin:end] isa ResizableArray{GraphPPL.NodeLabel, Vector{GraphPPL.NodeLabel}, 1}
    end
end

@testitem "isassigned" begin
    import GraphPPL: ResizableArray

    @testset begin
        s = ResizableArray(Ref, Val(1))

        # In the beginning everything is not assigned
        for i in 1:100
            @test !@inferred(isassigned(s, i))
        end

        # Assign some random indices 
        rindex = rand(1:100, 10)

        for i in rindex
            s[i] = Ref(1)
        end

        for i in 1:100
            if i ∉ rindex
                @test !@inferred(isassigned(s, i))
            else
                @test @inferred(isassigned(s, i))
            end
        end
    end

    @testset begin
        for N in 1:5
            s = ResizableArray(Ref, Val(N))

            for j in 1:N
                @test !@inferred(isassigned(s, ones(Int, j)...))
            end

            s[ones(Int, N)...] = Ref(1)

            @test @inferred(isassigned(s, ones(Int, N)...))

            s[10ones(Int, N)...] = Ref(1)

            @test @inferred(isassigned(s, 10ones(Int, N)...))

            for k in 2:9
                @test !@inferred(isassigned(s, k * ones(Int, N)...))
            end
        end
    end

    @testset begin
        for N in 1:5, M in 1:5
            s = ResizableArray(Ref, Val(N))
            indices = CartesianIndex(ones(Int, N)...):CartesianIndex(M * ones(Int, N)...)

            for index in indices
                @test !@inferred(isassigned(s, index.I...))
                s[index.I...] = Ref(1)
                @test @inferred(isassigned(s, index.I...))
            end
        end
    end
end

@testitem "map" begin
    import GraphPPL: ResizableArray

    s = ResizableArray(Int, Val(2))
    for i in 1:10
        for j in 1:10
            s[i, j] = i + j
        end
    end
    result = map(elem -> elem + 1, s)
    for i in 1:10
        for j in 1:10
            @test result[i, j] == s[i, j] + 1
        end
    end
end

@testitem "__length" begin
    import GraphPPL: ResizableArray, __length

    s = ResizableArray(Ref, Val(3))
    @test __length(s) == 0
    s[1, 1, 1] = Ref(1)
    @test __length(s) == 1
    s[1, 1, 2] = Ref(1)
    @test __length(s) == 2
    s[1, 2, 2] = Ref(1)
    @test __length(s) == 3
    s[2, 1, 1] = Ref(1)
    @test __length(s) == 4
end

@testitem "__flattened_index" begin
    import GraphPPL: ResizableArray, flattened_index

    s = ResizableArray(Ref, Val(3))

    s[2, 1, 1] = Ref(1)
    @test flattened_index(s, (2, 1, 1)) == 1
    s[1, 1, 1] = Ref(1)
    @test flattened_index(s, (2, 1, 1)) == 2
    s[1, 1, 2] = Ref(1)
    @test flattened_index(s, (2, 1, 1)) == 3
    s[1, 2, 2] = Ref(1)
    @test flattened_index(s, (2, 1, 1)) == 4
    s[2, 1, 2] = Ref(1)
    @test flattened_index(s, (2, 1, 1)) == 4
end

@testitem "iterate" begin
    import GraphPPL: ResizableArray

    @testset "dense ResizableArray x3" begin
        f_1(i, j, k) = i * j + k
        f_2(i, j, k) = i + j - k
        f_3(i, j, k) = i * j * k

        for f in (f_1, f_2, f_3)
            s = ResizableArray(Ref, Val(3))
            m = Array{Int}(undef, 3, 3, 3)

            for i in 1:3, j in 1:3, k in 1:3
                s[i, j, k] = Ref(f(i, j, k))
                m[i, j, k] = f(i, j, k)
            end

            mvec = vec(m)
            indc = vec(collect(Iterators.product(1:3, 1:3, 1:3)))

            for (index, elem) in zip(indc, s)
                i, j, k = index
                @test elem[] === m[i, j, k]
                @test elem[] === f(i, j, k)
            end

            for (i, elem) in enumerate(s)
                @test elem[] === mvec[i]
            end

            for (eₛ, eₘ) in zip(s, m)
                @test eₛ[] === eₘ
            end

            @test all(iszero, map((left, right) -> left[] - right, s, m))
        end
    end

    # `Sparse` resizable arrays cannot be easily iterated over
    # But we can iterate through the `vec` of the array
    @testset "sparse ResizableArray" begin
        s = ResizableArray(Ref, Val(3))

        s[2, 1, 1] = Ref(1)
        s[1, 1, 1] = Ref(1)
        s[1, 1, 2] = Ref(1)
        s[1, 2, 2] = Ref(1)
        s[2, 1, 2] = Ref(1)

        for elem in vec(s)
            @test elem[] === 1
        end
    end
end
