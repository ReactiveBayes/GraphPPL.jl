# Nested model specification
`GraphPPL` supports nested model specification, allowing hierarchical modeling and model specification. This means that any model that is defined in `GraphPPL` can be used as a submodel in another model. This allows us to write models that are more modular and reusable. This page will go over the syntax for nested model specification in `GraphPPL` and how to use it.

## Markov Blankets
In `GraphPPL`, a model is defined as a collection of random variables and their dependencies. This means that there are internal variables of the model, and variables that communicate with the outside of the model. These boundary variables are called the Markov Blanket of a model, and we have to specify them when we use a model as a submodel. To specify the Markov Blanket of a model, we include their names in the model function definition. For example, we can define the well-known Gaussian-with-Controlled-Variance model as follows:

``` @example nested-models
using GraphPPL

@model function gcv(κ, ω, z, x, y)
    log_σ := κ * z + ω
    σ := exp(log_σ)
    y ~ Normal(x, σ)
end
```
Here, we see that the `κ, ω, z, x` and `y` variables define the boundary of the `gcv` submodel, with `σ` and `log_σ` as internal variables. 
## Invoking submodels
If we want to chain these `gcv` submodels together into a Hierarchical Gaussian Filter, we still use the `~` operator. Here, in the arguments to `gcv`, we specify all-but-one interface. `GraphPPL` will interpolate which interface is missing and assign it to the left-hand-side:

``` @example nested-models
@model function hgf(κ, ω, θ, prior_x, depth)
    for i = 1:depth
        if i == 0
            means[i] ~ gcv(κ = κ, ω = ω, θ = θ, x = prior_x)
        else
            means[i] ~ gcv(κ = κ, ω = ω, θ = θ, x = means[i - 1])
        end
    end
end
```

Note that in our invocations of `gcv`, we haven't specified the `y` argument of the Markov Blanket. This is what is being recognized as the missing interface and `GraphPPL` will assign `means[i]` to `y`.