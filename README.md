# GraphPPL

GraphPPL.jl is a probabilistic programming language focused on probabilistic graphical models. 

# Inference Backend

GraphPPL.jl does not export any Bayesian inference backend. It provides a simple DSL parser and model generation helpers. To run inference on 
generated models user needs to have a Bayesian inference backend with GraphPPL.jl support (e.g. [ReactiveMP.jl](https://github.com/biaslab/ReactiveMP.jl)). 

# Examples

## Coin flip

```julia
@model function coin_model() 
    a = datavar(Float64)
    b = datavar(Float64)
    y = datavar(Float64)
    
    θ ~ Beta(a, b)
    y ~ Bernoulli(θ)
    
    return y, a, b, θ
end
```

## State Space Model

```julia
@model function ssm(n, θ, x0, Q::ConstVariable, P::ConstVariable)
    
    x = randomvar(n)
    y = datavar(Vector{Float64}, n)
    
    x_prior ~ MvNormalMeanCovariance(mean(x0), cov(x0))
    
    x_prev = x_prior
    
    A = constvar([ cos(θ) -sin(θ); sin(θ) cos(θ) ])
    
    for i in 1:n
        x[i] ~ MvNormalMeanCovariance(A * x_prev, Q)
        y[i] ~ MvNormalMeanCovariance(x[i], P)
        
        x_prev = x[i]
    end
    
    return x, y
end
```

## Hidden Markov Model

```julia
@model [ default_factorisation = MeanField() ] function transition_model(n)
    
    A ~ MatrixDirichlet(ones(3, 3)) 
    B ~ MatrixDirichlet([ 10.0 1.0 1.0; 1.0 10.0 1.0; 1.0 1.0 10.0 ])
    
    s_0 ~ Categorical(fill(1.0 / 3.0, 3))
    
    s = randomvar(n)
    x = datavar(Vector{Float64}, n)
    
    s_prev = s_0
    
    for t in 1:n
        s[t] ~ Transition(s_prev, A) where { q = q(out, in)q(a) }
        x[t] ~ Transition(s[t], B)
        s_prev = s[t]
    end
    
    return s, x, A, B
end
```

## Gaussian Mixture Model

```julia
@model [ default_factorisation = MeanField() ] function gaussian_mixture_model(n)
    
    s ~ Beta(1.0, 1.0)
    
    m1 ~ NormalMeanVariance(-2.0, 1e3)
    w1 ~ GammaShapeRate(0.01, 0.01)
    
    m2 ~ NormalMeanVariance(2.0, 1e3)
    w2 ~ GammaShapeRate(0.01, 0.01)
    
    z = randomvar(n)
    y = datavar(Float64, n)
    
    for i in 1:n
        z[i] ~ Bernoulli(s)
        y[i] ~ NormalMixture(z[i], (m1, m2), (w1, w2))
    end
    
    return s, m1, w1, m2, w2, z, y
end
```