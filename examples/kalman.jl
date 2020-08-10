using GraphPPL
using ForneyLab
using Distributions

@ffgmodel function kalman(n,p)
    # x ~ GaussianMeanVariance(0,1) ∥ [id=:test]
    # y ~ Normal(0,1)
    # z ~ Normal(x,y)
    # a = x+y
    xt = Vector{Variable}(undef,10)
    
    for t=1:10
        xt[t] ~ Normal(1,2)
    end
    
    # b ← a*z ∥ [id=:test2]
end

g = kalman(12,2)

ForneyLab.draw(external_viewer=:default)