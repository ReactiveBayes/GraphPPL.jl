@testitem "NodeData constructor" begin
    import GraphPPL: create_model, getcontext, NodeData, FactorNodeProperties, VariableNodeProperties, getproperties

    include("testutils.jl")

    model = create_test_model()
    context = getcontext(model)

    @testset "FactorNodeProperties" begin
        properties = FactorNodeProperties(fform = String)
        nodedata = NodeData(context, properties)

        @test getcontext(nodedata) === context
        @test getproperties(nodedata) === properties

        io = IOBuffer()

        show(io, nodedata)

        output = String(take!(io))

        @test !isempty(output)
        @test contains(output, "String") # fform
    end

    @testset "VariableNodeProperties" begin
        properties = VariableNodeProperties(name = :x, index = 1)
        nodedata = NodeData(context, properties)

        @test getcontext(nodedata) === context
        @test getproperties(nodedata) === properties

        io = IOBuffer()

        show(io, nodedata)

        output = String(take!(io))

        @test !isempty(output)
        @test contains(output, "x") # name
        @test contains(output, "1") # index
    end
end

@testitem "NodeDataExtraKey" begin
    import GraphPPL: NodeDataExtraKey, getkey

    @test NodeDataExtraKey{:a, Int}() isa NodeDataExtraKey
    @test NodeDataExtraKey{:a, Int}() === NodeDataExtraKey{:a, Int}()
    @test NodeDataExtraKey{:a, Int}() !== NodeDataExtraKey{:a, Float64}()
    @test NodeDataExtraKey{:a, Int}() !== NodeDataExtraKey{:b, Int}()
    @test getkey(NodeDataExtraKey{:a, Int}()) === :a
    @test getkey(NodeDataExtraKey{:a, Float64}()) === :a
    @test getkey(NodeDataExtraKey{:b, Float64}()) === :b
end

@testitem "NodeData extra properties" begin
    import GraphPPL:
        create_model,
        getcontext,
        NodeData,
        FactorNodeProperties,
        VariableNodeProperties,
        getproperties,
        setextra!,
        getextra,
        hasextra,
        NodeDataExtraKey

    include("testutils.jl")

    model = create_test_model()
    context = getcontext(model)

    @testset for properties in (FactorNodeProperties(fform = String), VariableNodeProperties(name = :x, index = 1))
        nodedata = NodeData(context, properties)

        @test !hasextra(nodedata, :a)
        @test getextra(nodedata, :a, 2) === 2
        @test !hasextra(nodedata, :a) # the default should not add the extra property, only return
        setextra!(nodedata, :a, 1)
        @test hasextra(nodedata, :a)
        @test getextra(nodedata, :a) === 1
        @test getextra(nodedata, :a, 2) === 1
        @test !hasextra(nodedata, :b)
        @test_throws Exception getextra(nodedata, :b)
        @test getextra(nodedata, :b, 2) === 2

        # In the current implementation it is not possible to update extra properties
        @test_throws Exception setextra!(nodedata, :a, 2)

        @test !hasextra(nodedata, :b)
        setextra!(nodedata, :b, 2)
        @test hasextra(nodedata, :b)
        @test getextra(nodedata, :b) === 2

        constkey_c_float = NodeDataExtraKey{:c, Float64}()

        @test !@inferred(hasextra(nodedata, constkey_c_float))
        @test @inferred(getextra(nodedata, constkey_c_float, 4.0)) === 4.0
        @inferred(setextra!(nodedata, constkey_c_float, 3.0))
        @test @inferred(hasextra(nodedata, constkey_c_float))
        @test @inferred(getextra(nodedata, constkey_c_float)) === 3.0
        @test @inferred(getextra(nodedata, constkey_c_float, 4.0)) === 3.0

        # The default has a different type from the key (4.0 is Float and 4 is Int), thus the error 
        @test_throws MethodError getextra(nodedata, constkey_c_float, 4)

        constkey_d_int = NodeDataExtraKey{:d, Int64}()

        @test !@inferred(hasextra(nodedata, constkey_d_int))
        @inferred(setextra!(nodedata, constkey_d_int, 4))
        @test @inferred(hasextra(nodedata, constkey_d_int))
        @test @inferred(getextra(nodedata, constkey_d_int)) === 4
    end
end

@testitem "NodeCreationOptions" begin
    import GraphPPL: NodeCreationOptions, withopts, withoutopts

    include("testutils.jl")

    @test NodeCreationOptions() == NodeCreationOptions()
    @test keys(NodeCreationOptions()) === ()
    @test NodeCreationOptions(arbitrary_option = 1) == NodeCreationOptions((; arbitrary_option = 1))

    @test haskey(NodeCreationOptions(arbitrary_option = 1), :arbitrary_option)
    @test NodeCreationOptions(arbitrary_option = 1)[:arbitrary_option] === 1

    @test @inferred(haskey(NodeCreationOptions(), :a)) === false
    @test @inferred(haskey(NodeCreationOptions(), :b)) === false
    @test @inferred(haskey(NodeCreationOptions(a = 1, b = 2), :b)) === true
    @test @inferred(haskey(NodeCreationOptions(a = 1, b = 2), :c)) === false
    @test @inferred(NodeCreationOptions(a = 1, b = 2)[:a]) === 1
    @test @inferred(NodeCreationOptions(a = 1, b = 2)[:b]) === 2

    @test_throws ErrorException NodeCreationOptions()[:a]
    @test_throws ErrorException NodeCreationOptions(a = 1, b = 2)[:c]

    @test @inferred(get(NodeCreationOptions(), :a, 2)) === 2
    @test @inferred(get(NodeCreationOptions(), :b, 3)) === 3
    @test @inferred(get(NodeCreationOptions(), :c, 4)) === 4
    @test @inferred(get(NodeCreationOptions(a = 1, b = 2), :a, 2)) === 1
    @test @inferred(get(NodeCreationOptions(a = 1, b = 2), :b, 3)) === 2
    @test @inferred(get(NodeCreationOptions(a = 1, b = 2), :c, 4)) === 4

    @test NodeCreationOptions(a = 1, b = 2)[(:a,)] === NodeCreationOptions(a = 1)
    @test NodeCreationOptions(a = 1, b = 2)[(:b,)] === NodeCreationOptions(b = 2)

    @test keys(NodeCreationOptions(a = 1, b = 2)) == (:a, :b)

    @test @inferred(withopts(NodeCreationOptions(), (a = 1,))) == NodeCreationOptions(a = 1)
    @test @inferred(withopts(NodeCreationOptions(b = 2), (a = 1,))) == NodeCreationOptions(b = 2, a = 1)

    @test @inferred(withoutopts(NodeCreationOptions(), Val((:a,)))) == NodeCreationOptions()
    @test @inferred(withoutopts(NodeCreationOptions(b = 1), Val((:a,)))) == NodeCreationOptions(b = 1)
    @test @inferred(withoutopts(NodeCreationOptions(a = 1), Val((:a,)))) == NodeCreationOptions()
    @test @inferred(withoutopts(NodeCreationOptions(a = 1, b = 2), Val((:c,)))) == NodeCreationOptions(a = 1, b = 2)
end

@testitem "is_constant" begin
    import GraphPPL: create_model, is_constant, variable_nodes, getname, getproperties

    include("testutils.jl")

    using .TestUtils.ModelZoo

    for model_fn in ModelsInTheZooWithoutArguments
        model = create_model(model_fn())
        for label in variable_nodes(model)
            node = model[label]
            props = getproperties(node)
            if occursin("constvar", string(getname(props)))
                @test is_constant(props)
            else
                @test !is_constant(props)
            end
        end
    end
end

@testitem "is_data" begin
    import GraphPPL: is_data, create_model, getcontext, getorcreate!, variable_nodes, NodeCreationOptions, getproperties

    include("testutils.jl")

    m = create_test_model()
    ctx = getcontext(m)
    xref = getorcreate!(m, ctx, NodeCreationOptions(kind = :data), :x, nothing)
    @test is_data(getproperties(m[xref]))

    using .TestUtils.ModelZoo

    # Since the models here are without top arguments they cannot create `data` labels
    for model_fn in ModelsInTheZooWithoutArguments
        model = create_model(model_fn())
        for label in variable_nodes(model)
            @test !is_data(getproperties(model[label]))
        end
    end
end

@testitem "Predefined kinds of variable nodes" begin
    import GraphPPL: VariableKindRandom, VariableKindData, VariableKindConstant
    import GraphPPL: getcontext, getorcreate!, NodeCreationOptions, getproperties

    include("testutils.jl")

    model = create_test_model()
    context = getcontext(model)
    xref = getorcreate!(model, context, NodeCreationOptions(kind = VariableKindRandom), :x, nothing)
    y = getorcreate!(model, context, NodeCreationOptions(kind = VariableKindData), :y, nothing)
    zref = getorcreate!(model, context, NodeCreationOptions(kind = VariableKindConstant), :z, nothing)

    import GraphPPL: is_random, is_data, is_constant, is_kind

    xprops = getproperties(model[xref])
    yprops = getproperties(model[y])
    zprops = getproperties(model[zref])

    @test is_random(xprops) && is_kind(xprops, VariableKindRandom)
    @test is_data(yprops) && is_kind(yprops, VariableKindData)
    @test is_constant(zprops) && is_kind(zprops, VariableKindConstant)
end