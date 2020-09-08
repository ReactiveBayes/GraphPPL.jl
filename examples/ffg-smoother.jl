using GraphPPL
using ForneyLab
using Distributions


@ffgmodel function smoother(n, prior)
    x_0 ~ GaussianMeanVariance(prior.m, prior.v)

    x = Vector{Variable}(undef, n)
    y = Vector{Variable}(undef, n)

    x_t_min = x_0
    for t = 1:n
        n_t ~ GaussianMeanVariance(0.0, 200.0)
        x[t] = x_t_min + 1.0
        y[t] = x[t] + n_t ∥ [id=:y*t]
        placeholder(y[t], :y*t, index=t)
        x_t_min = x[t]
    end
end

prior = (m=0.0,v=1.0)
g = smoother(10, prior)

ForneyLab.draw(external_viewer=:default)