# Migration Guide

This page describes the major changes between GraphPPL `v3` and `v4`. The `v4` introduced many changes to the language and the API. The changes are designed to make the language more consistent and easier to use, but also are tested better and provides extra features for the future releases. These changes are, however, not backward compatible with the previous versions of GraphPPL, such as `v3`. In this guide, we will describe the major changes between the two versions and provide examples to help you migrate your code to the new version.

## The `@model` macro

The `@model` macro is no longer exported from the library and is only provided for interactive purposes (e.g. plotting). 
The downstream package must define their own `@model` macro and use the [`GraphPPL.model_macro_interior`](@ref) function with a [custom backend](@ref custom-backend).

## Model definition

Model definition in version `4` is similar to version `3`. The main difference is the deletion of the `datavar`, `randomvar` and `constvar` syntax.
Previously the random variables and data variables needed to be specified in advance. This is no longer possible but also is unnecessary.
`GraphPPL` is able to infer the type of the variable based on the way in which it is used.
This greatly trims down the amount of code to be written in the model definition.  

The following example is a simple model definition in version `3`:
```julia
@model function SSM(n, x0, A, B, Q, P) 
 	 x = randomvar(n) 
 	 y = datavar(Vector{Float64}, n) 
 	 x_prior ~ MvNormal(μ = mean(x0), Σ = cov(x0)) 
 	 x_prev = x_prior 
 	 for i in 1:n 
 		   x[i] ~ MvNormal(μ = A * x_prev, Σ = Q) 
 		   y[i] ~ MvNormal(μ = B * x[i], Σ = P) 
 		   x_prev = x[i] 
 	 end 
 end 
```

The equivalent model definition in version `4` is as follows:
```julia
 @model function SSM(y, prior_x, A, B, Q, P) 
     x_prev ~ prior_x
     for i in eachindex(y)
        x[i] ~ MvNormal(μ = A * x_prev, Σ = Q) 
        y[i] ~ MvNormal(μ = B * x[i], Σ = P) 
        x_prev = x[i]
    end
end
```

As you can see, variable creation still requires the `~` operator. However, there are a couple of subtle changes compared to the old version of GraphPPL:
- The `randomvar` and `datavar` syntax is no longer needed. `GraphPPL` is able to infer the type of the variable based on the way in which it is used.
- The data `y` is an explicit parameter of the model function.
- The `n` parameter is no longer needed. The size of the variable `x` is inferred from the size of the variable `y`.
- We are no longer required to extract the mean and covariance of our prior distribution using the `MvNormal(μ = mean(x0), Σ = cov(x0))` pattern. Instead, we can pass a prior and call `x_prev ~ prior_x` to assign it to an edge in the factor graph.
- The data `y` is passed as an argument to the model. This is because of the support of nested models in version `4`. In the [Nested models](#nested-models) we elaborate more on this design choice.

### Vectors and arrays

As seen in the example above, we can assign `x[i]` without explicitly defining `x` first. `GraphPPL` is able to infer that `x` is a vector of random variables, and will grow the internal representation of `x` accordingly to accomodate `i` elements. Note that this works recursively, so `z[i, j]` will define a matrix of random variables. GraphPPL does check that the index `[i,j]` is compatible with the shape of the variable `z`.

!!! note
    `eachindex(y)` works only if `y` has a static data associated with it. Read the documentation for [`GraphPPL.create_model`](@ref) for more information.

### Factor aliases

In version `4`, we can define factor aliases to define different implementations of the same factor. For example, in `RxInfer.jl`, there are multiple implentations of the `Normal` distribution. Previously, we would have to explicitly call `NormalMeanVariance` or `NormalMeanPrecision`. In version `4`, we can define factor aliases to default to certain implementations when specific keyword arguments are used on construction. For example: `Normal(μ = 0, σ² = 1)` will default to `NormalMeanVariance` and `Normal(μ = 0, τ = 1)` will default to `NormalMeanPrecision`. This allows users to quickly toggle between different implementations of the same factor, while keeping an implementation agnostic model definition.

!!! note
    This feature works only in the combination with the `~` operator, which creates factor nodes. Therefore it cannot be used to instantiate a distribution object in a regular Julia code.

### Nested models

The major difference between versions `3` and `4` is the support for nested models. In version `4`, models can be nested within each other. This allows for more complex models to be built in a modular way. The following example demonstrates how to nest models in version `4`:

```julia
@model function kalman_filter_step(y, prev_x, new_x, A, B, Q, P)
    new_x ~ MvNormal(μ = A * prev_x, Σ = Q)
    y ~ MvNormal(μ = B * x, Σ = P)
end

@model function state_space_model(y, A, B, Q, P)
    x[1] ~ MvNormal(zeros(2), diagm(ones(2)))
    for i in eachindex(y)
        y[i] ~ kalman_filter_step(prev_x = x[i], new_x = new(x[i + 1]), A=A, B=B, Q=Q, P=P)
    end
end
```

Note that we reuse the `kalman_filter_step` model in the `state_space_model` model. In the argument list of any `GraphPPL` model, we have to specify the Markov Blanket of the model we are defining. This means that all interfaces with the outside world have to be passed as arguments to the model. For the `kalman_filter_step` model, we pass the previous state `prev_x`, the new state `new_x`, the observation `y` as well as the parameters `A`, `B`, `Q` and `P`. This means that, when invoking a submodel in a larger model, we can specify all components of the Markov Blanket. Note that, in the `state_space_model` model, we do not pass `y` as an argument to the `kalman_filter_step` model. `GraphPPL` will infer that `y` is missing from the argument list and assign it to whatever is left of the `~` operator. Note that we also use the `new(x[i + 1])` syntax to create a new variable in the position of `x[i + 1]`. Since `y` is also passed in the argument list of the `state_space_model` model, we could have written this line with the equivalen statement `x[i + 1] ~ kalman_filter_step(prev_x = x[i], y = y[i], A=A, B=B, Q=Q, P=P)`. However, to respect the generative direction of the model and to make the code more readable, we use the `new(x[i + 1])` syntax. Note, however, that the underlaying representation of the models in `GraphPPL` are still undirected.

## Constraint specification

With the introduction of nested models, the specification of variational constraints becomes more difficult. In version `3`, variable names were uniquely defined in the model, which made it easy to specify constraints on variables. In version `4`, nested models can contain variables with the same name as their parents, even though they are distinct random variables. Therefore, we need to specify constraints on submodel level in the constraints macro. This is done with the `for q in _submodel_` syntax. 

For example:
```julia
@constraints begin
    for q in kalman_filter_step
        q(new_x, prev_x, y) = q(new_x, prev_x)q(y)
    end
end
```

This specification reuses the same constraint to all instances of the `kalman_filter_step` submodel. Of course, we'd like to have more flexibility in the constraints we can specify. Therefore, we can also specify constraints on a specific instance of the submodel. For example:
```julia
@constraints begin
    for q in (kalman_filter_step, 1)
        q(new_x, prev_x, y) = q(new_x, prev_x)q(y)
        q(new_x) :: Normal
    end
end
```
This pushes the constraint to the first instance of the `kalman_filter_step` submodel. With this syntax, we can specify constraints on any instance of a submodel. 

The function syntax for constraints is still supported. For example:
```julia
@constraints function ssm_constraints(factorize)
    for q in kalman_filter_step
        if factorize
            q(new_x, prev_x, y) = MeanField()
        else
            q(new_x, prev_x, y) = q(new_x, prev_x)q(y)
        end
    end
end
```

## Meta specification

The meta specification follows exactly the same structure as the constraints specification. Nested models in the `@meta` macro are specified in the same way as in the `@constraints` macro. 

For example:
```julia
@meta begin
    for meta in some_submodel
        GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
    end
    y -> SomeMetaData()
end
```

Additionally, we can pass arbitrary metadata to the inference backend. For example:
```julia
@meta begin
    GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
    x -> (prod_constraint = SomeProdConstraint(), )
end
```       

By passing a `NamedTuple` in the `@model` macro, we can pass arbitrary metadata to the inference backend that we would previously have to specify in the `where` clause of a node. With the added functionality of the `@meta` macro, we can pass metadata to the inference backend in a more structured way, and detach metadata definition from model definition.

## Dispatch

In the new version of `GraphPPL.jl` it is no longer possible to use Julia's multiple dispatch within the `@model` function definition. 
The workaround is to use nested models instead, e.g. users can pass submodels as an extra argument, therefore change the structure of the model based on the input arguments. 

## Positional arguments 

In the new version of `GraphPPL.jl` positional arguments within model construction is no longer supported and all arguments must be named explicitly.
For example:
```julia
@model function beta_bernoulli(y, a, b)
    t ~ Beta(a, b)
    for i in eachindex(y)
        y[i] ~ Bernoulli(t)
    end
end
```

```julia
model = beta_bernoulli(1.0, 2.0) # ambigous and unsupported
```

```julia
model = beta_bernoulli(a = 1.0, b = 2.0) # explicitly defined via keyword arguments
```

The same recipe applies when nesting models within each other, e.g.

```julia
@model function bigger_model(y)
    a ~ Uniform(0.0, 10.0)
    b ~ Uniform(0.0, 10.0)
    y ~ beta_bernoulli(a = a, b = b)
end
```

# Mixture Nodes

The interface of the mixture nodes does no longer require a tuple of inputs. Instead, the inputs can be passed as a vector as well. For example:
```julia
@model function mixture_model(y)
    # specify two models
    m_1 ~ Beta(2.0, 7.0)
    m_2 ~ Beta(7.0, 2.0)

    # specify prior on switch param
    s ~ Bernoulli(0.7) 

    # specify mixture prior Distribution
    θ ~ Mixture(switch = s, inputs = [m_1, m_2])
end
```

# Overview of the removed functionality

- The `datavar`, `randomvar` and `constvar` syntax is removed. `GraphPPL` is able to infer the type of the variable based on the way in which it is used.
- Specifying factorization constraints in the `where` clause of a node is no longer possible. The `where` syntax can still be used to specify metadata for factor nodes, but factorization constraints can only be specified with the `@constraints` macro.
- Dispatch in the `@model` macro is not supported.
- Positional arguments in the `@model` macro are not supporeted.