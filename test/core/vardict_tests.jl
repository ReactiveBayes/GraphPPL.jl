@testitem "VarDict" setup = [TestUtils] begin
    using Distributions
    import GraphPPL:
        Context, VarDict, create_model, getorcreate!, datalabel, NodeCreationOptions, getcontext, is_random, is_data, getproperties

    ctx = Context()
    vardict = VarDict(ctx)
    @test isa(vardict, VarDict)

    TestUtils.@model function submodel(y, x_prev, x_next)
        γ ~ Gamma(1, 1)
        x_next ~ Normal(x_prev, γ)
        y ~ Normal(x_next, 1)
    end

    TestUtils.@model function state_space_model_with_new(y)
        x[1] ~ Normal(0, 1)
        y[1] ~ Normal(x[1], 1)
        for i in 2:length(y)
            y[i] ~ submodel(x_next = new(x[i]), x_prev = x[i - 1])
        end
    end

    ydata = ones(10)
    model = create_model(state_space_model_with_new()) do model, ctx
        y = datalabel(model, ctx, NodeCreationOptions(kind = :data), :y, ydata)
        return (y = y,)
    end

    context = getcontext(model)
    vardict = VarDict(context)

    @test haskey(vardict, :y)
    @test haskey(vardict, :x)
    for i in 1:(length(ydata) - 1)
        @test haskey(vardict, (submodel, i))
        @test haskey(vardict[submodel, i], :γ)
    end

    @test vardict[:y] === context[:y]
    @test vardict[:x] === context[:x]
    @test vardict[submodel, 1] == VarDict(context[submodel, 1])

    result = map(identity, vardict)
    @test haskey(result, :y)
    @test haskey(result, :x)
    for i in 1:(length(ydata) - 1)
        @test haskey(result, (submodel, i))
        @test haskey(result[submodel, i], :γ)
    end

    result = map(vardict) do variable
        return length(variable)
    end
    @test haskey(result, :y)
    @test haskey(result, :x)
    @test result[:y] === length(ydata)
    @test result[:x] === length(ydata)
    for i in 1:(length(ydata) - 1)
        @test result[(submodel, i)][:γ] === 1
        @test result[GraphPPL.FactorID(submodel, i)][:γ] === 1
        @test result[submodel, i][:γ] === 1
    end

    # Filter only random variables
    result = filter(vardict) do label
        if label isa GraphPPL.ResizableArray
            all(is_random.(getproperties.(model[label])))
        else
            return is_random(getproperties(model[label]))
        end
    end
    @test !haskey(result, :y)
    @test haskey(result, :x)
    for i in 1:(length(ydata) - 1)
        @test haskey(result, (submodel, i))
        @test haskey(result[submodel, i], :γ)
    end

    # Filter only data variables
    result = filter(vardict) do label
        if label isa GraphPPL.ResizableArray
            all(is_data.(getproperties.(model[label])))
        else
            return is_data(getproperties(model[label]))
        end
    end
    @test haskey(result, :y)
    @test !haskey(result, :x)
    for i in 1:(length(ydata) - 1)
        @test haskey(result, (submodel, i))
        @test !haskey(result[submodel, i], :γ)
    end
end
