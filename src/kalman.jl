using GraphPPL
using ForneyLab
using Distributions

@ffgmodel function kalman(n,p)
    x ~ Normal(0,1)
    y ~ Normal(0,1)
    z ~ Normal(x,y)
    # z = x+y
end

kalman(12,2)
