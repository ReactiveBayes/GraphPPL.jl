using GraphPPL
using ForneyLab
using Distributions

@ffgmodel function random_walk(n)

    xt = Vector{Variable}(undef,10)
    
    xt[1] ~ Normal(0,0)

    for t=2:n
        xt[t] ~ Normal(xt[t-1],2)
    end
     
end

g = random_walk(10)

ForneyLab.draw(external_viewer=:default)