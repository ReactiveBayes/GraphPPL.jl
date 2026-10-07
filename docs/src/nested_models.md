# [Nested model specification](@id nested-models)
`GraphPPL` supports nested model specification, allowing hierarchical modeling and model specification. This means that any model that is defined in `GraphPPL` can be used as a submodel in another model. This allows us to write models that are more modular and reusable. This page will go over the syntax for nested model specification in `GraphPPL` and how to use it.

## Markov Blankets
In `GraphPPL`, a model is defined as a collection of random variables and their dependencies. This means that there are internal variables of the model, and variables that communicate with the outside of the model. These boundary variables are called the Markov Blanket of a model, and we have to specify them when we use a model as a submodel. To specify the Markov Blanket of a model, we include their names in the model function definition. For example, we can define the well-known Gaussian-with-Controlled-Variance model as follows:

``` @example nested-models
using GraphPPL
import GraphPPL: @model

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
@model function hgf(κ, ω, z, prior_x, depth)
    for i = 1:depth
        if i == 1
            means[i] ~ gcv(κ = κ, ω = ω, z = z, x = prior_x)
        else
            means[i] ~ gcv(κ = κ, ω = ω, z = z, x = means[i - 1])
        end
    end
end
```

Note that in our invocations of `gcv`, we haven't specified the `y` argument of the Markov Blanket. This is what is being recognized as the missing interface and `GraphPPL` will assign `means[i]` to `y`.

## Multi-output submodels

When a submodel produces multiple outputs — multiple interfaces left unspecified on the RHS — you can bind them all on the LHS using a tuple. There are two syntaxes:

**Positional:** list outer variables in the same order as the unspecified interfaces appear in the submodel definition.

``` @example nested-models
@model function linear_gaussian(x, y, z)
    x ~ Normal(z, 1)
    y ~ Normal(x, 1)
end

@model function outer_positional(c)
    (a, b) ~ linear_gaussian(z = c)   # a → interface x, b → interface y (by position)
end
```

**Named (kwarg-style):** explicitly map each outer variable to its interface name using `name = var` pairs. This is order-independent and recommended when submodel argument order may change.

``` @example nested-models
@model function outer_named(my_z)
    (y = my_y, x = my_x) ~ linear_gaussian(z = my_z)   # binds by name, regardless of order
    obs ~ Normal(my_x, my_y)
end
```

Both syntaxes work with indexed variables in loops:

``` @example nested-models
@model function chain(z, n)
    for i in 1:n
        (x = xs[i], y = ys[i]) ~ linear_gaussian(z = z)
    end
end
```

!!! note
    If the same interface name appears on both LHS and RHS, `GraphPPL` raises an error at model-creation time. Similarly, providing a name on the LHS that does not match any of the submodel's interface names is caught with a descriptive error.