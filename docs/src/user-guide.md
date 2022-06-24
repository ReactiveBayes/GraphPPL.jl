# User guide

Probabilistic models incorporate elements of randomness to describe an event or phenomenon by using random variables and probability theory. A probabilistic model can be represented visually by using probabilistic graphical models (PGMs). A factor graph is a type of PGM that is well suited to cast inference tasks in terms of graphical manipulations.

`GraphPPL.jl` is a Julia package presenting a model specification language for probabilistic models. 

!!! note
    `GraphPPL.jl` does not work without extra "backend" package. Currently the only one available "backend" package is `ReactiveMP.jl`.

## [Model specification](@id user-guide-model-specification)

The `GraphPPL.jl` package exports the `@model` macro for model specification. This `@model` macro accepts two arguments: model options and the model specification itself in a form of regular Julia function. For example: 

```julia
@model [ option1 = ..., option2 = ... ] function model_name(model_arguments...; model_keyword_arguments...)
    # model specification here
    return ...
end
```

Model options, `model_arguments` and `model_keyword_arguments` are optional and may be omitted:

```julia
@model function model_name()
    # model specification here
    return ...
end
```

!!! note
    `options`, `constraints` and `meta` keyword arguments are reserved and cannot be used in `model_keyword_arguments`.

The `@model` macro returns a regular Julia function (in this example `model_name()`) which can be executed as usual. It returns a reference to a model object itself and a tuple of a user specified return variables, e.g:

```julia
@model function my_model(model_arguments...)
    # model specification here
    # ...
    return x, y
end
```

```julia
model, (x, y) = my_model(model_arguments...)
```

It is not necessary to return anything from the model, in that case `GraphPPL.jl` will automatically inject `return nothing` to the end of the model function.

## A full example before diving in

Before presenting the details of the model specification syntax, an example of a probabilistic model is given.
Here is an example of a simple state space model with latent random variables `x` and noisy observations `y`:

```julia
@model [ options... ] function state_space_model(n_observations, noise_variance)

    x = randomvar(n_observations)
    y = datavar(Float64, n_observations)

    x[1] ~ NormalMeanVariance(0.0, 100.0)

    for i in 2:n_observations
       x[i] ~ x[i - 1] + 1.0
       y[i] ~ NormalMeanVariance(x[i], noise_var)
    end

    return x, y
end
```
    
## Graph variables creation

### Constants

Any runtime constant passed to a model as a model argument will be automatically converted to a fixed constant in the graph model at runtime. Sometimes it might be useful to create constants by hand (e.g. to avoid copying large matrices across the model and to avoid extensive memory allocations).

You can create a constant within a model specification macro with `constvar()` function. For example:

```julia
c = constvar(1.0)

for i in 2:n
    x[i] ~ x[i - 1] + c # Reuse the same reference to a constant 1.0
end
```

Additionally you can specify an extra `::ConstVariable` type for some of the model arguments. In this case macro automatically converts them to a single constant using `constvar()` function. E.g.:

```julia
@model function model_name(nsamples::Int, c::ConstVariable)
    # ...
    # no need to call for a constvar() here
    for i in 2:n
        x[i] ~ x[i - 1] + c # Reuse the same reference to a constant `c`
    end
    # ...
    return ...
end
```

!!! note
    `::ConstVariable` annotation does not play role in Julia's multiple dispatch. `GraphPPL.jl` removes this annotation and replaces it with `::Any`.

### Data variables

It is important to have a mechanism to pass data values to the model. You can create data inputs with `datavar()` function. As a first argument it accepts a type specification and optional dimensionality (as additional arguments or as a tuple).

Examples: 

```julia
y = datavar(Float64) # Creates a single data input with `y` as identificator
y = datavar(Float64, n) # Returns a vector of  `y_i` data input objects with length `n`
y = datavar(Float64, n, m) # Returns a matrix of `y_i_j` data input objects with size `(n, m)`
y = datavar(Float64, (n, m)) # It is also possible to use a tuple for dimensionality
```

`datavar()` call supports `where { options... }` block for extra options specification. Read `ReactiveMP.jl` documentation to know more about possible creation options.

### Random variables

There are several ways to create random variables. The first one is an explicit call to `randomvar()` function. By default it doesn't accept any argument, creates a single random variable in the model and returns it. It is also possible to pass dimensionality arguments to `randomvar()` function in the same way as for the `datavar()` function.

Examples: 

```julia
x = randomvar() # Returns a single random variable which can be used later in the model
x = randomvar(n) # Returns an vector of random variables with length `n`
x = randomvar(n, m) # Returns a matrix of random variables with size `(n, m)`
x = randomvar((n, m)) # It is also possible to use a tuple for dimensionality
```

In the same way as `datavar()` function, `randomvar()` options supports `where { options... }` block for exxtra options. Read `ReactiveMP.jl` documentation to know more about possible creation options.

The second way to create a random variable is to create a node with the `~` operator. If the random variable has not yet been created before this call, it will be created automatically during the creation of the node. Read more about the `~` operator below.

## Node creation

Factor nodes are used to define a relationship between random variables and/or constants and data inputs. A factor node defines a probability distribution over selected random variables. 

We model a random variable by a probability distribution using the `~` operator. For example, to create a random variable `y` which is modeled by a Normal distribution, where its mean and variance are controlled by the random variables `m` and `v` respectively, we define

```julia
m = randomvar()
v = randomvar()
y ~ NormalMeanVariance(m, v) # Creates a `y` random variable automatically
```

```julia
a = randomvar()
b = randomvar()
c ~ a + b
```

!!! note
    The `GraphPPL.jl` package uses the `~` operator for modelling both stochastic and deterministic relationships between random variables.


The `@model` macro automatically resolves any inner function calls into anonymous extra nodes in case this inner function call is a non-linear transformations. But it is important to note that the inference backend will try to optimize inner non-linear deterministic function calls in the case where all arguments are constants or data inputs. For example:

```julia
noise ~ NormalMeanVariance(mean, inv(precision)) # Will create a non-linear node in case if `precision` is a random variable. Won't create an additional non-linear node in case if `precision` is a constant or data input.
```

It is possible to use any functional expression within the `~` operator arguments list. The only one exception is the `ref` expression (e.g `x[i]`). All reference expressions within the `~` operator arguments list are left untouched during model parsing. This means that the model parser will not create unnecessary nodes when only simple indexing is involved.

```julia
y ~ NormalMeanVariance(x[i - 1], variance) # While in principle `i - 1` is an inner function call (`-(i, 1)`) model parser will leave it untouched and won't create any anonymous nodes for `ref` expressions.

y ~ NormalMeanVariance(A * x[i - 1], variance) # This example will create a `*` anonymous node (in case if x[i - 1] is a random variable) and leave `x[i - 1]` untouched.
```

It is also possible to return a node reference from the `~` operator. Use the following syntax:

```julia
node, y ~ NormalMeanVariance(mean, var)
```

Having a node reference can be useful in case the user wants to return it from a model and to use it later on to specify initial joint marginal distributions.

### Broadcasting syntax 

!!! note 
    Broadcasting syntax requires at least v2.1.0 of `GraphPPL.jl` 

GraphPPL support broadcasting for `~` operator in the exact same way as Julia itself. A user is free to write an expression of the following form:

```julia
y = datavar(Float64, n)
y .~ NormalMeanVariance(0.0, 1.0) # <- i.i.d observations
```

More complex expression are also allowed:

```julia
m ~ NormalMeanPrecision(0.0, 0.0001)
t ~ Gamma(1.0, 1.0)

y = randomvar(Float64, n)
y .~ NormalMeanPrecision(m, t)
```

```julia
A = constvar(...)
x = randomvar(n)
y = datavar(Vector{Float64}, n)

w         ~ Wishart(3, diageye(2))
x[1]      ~ MvNormalMeanPrecision(zeros(2), diageye(2))
x[2:end] .~ A .* x[1:end-1] # <- State-space model with transition matrix A
y        .~ MvNormalMeanPrecision(x, w) # <- Observations with unknown precision matrix
```

Note, however, that all variables that take part in the broadcasting operation must be defined before either with `randomvar` or `datavar`. The exception here is constants that are automatically converted to their `constvar` equivalent. If you want to prevent broadcasting for some constant (e.g. if you want to add a vector to a multivariate Gaussian distribution) use explicit `constvar` call:

```julia
# Suppose `x` is a 2-dimensional Gaussian distribution
z .~ x .+ constvar([ 1, 1 ])
# Which is equivalent to 
for i in 1:n
   z[i] ~ x[i] + constvar([ 1, 1 ])
end
```

Without explicit `constvar` Julia's broadcasting machinery would instead attempt to unroll for loop in the following way:

```julia
# Without explicit `constvar`
z .~ x .+ [ 1, 1 ]
# Which is equivalent to 
array = [1, 1]
for i in 1:n
   z[i] ~ x[i] + array[i] # This is wrong if `x[i]` is supposed to be a multivariate Gaussian 
end
```

Read more about how broadcasting machinery works in Julia in [the official documentation](https://docs.julialang.org/en/v1/manual/arrays/#Broadcasting).

### Node creation options

To pass optional arguments to the node creation constructor the user can use the `where { options...  }` options specification syntax.

Example:

```julia
y ~ NormalMeanVariance(y_mean, y_var) where { q = q(y_mean)q(y_var)q(y) } # mean-field factorisation over q
```

A list of some of the available options specific to `ReactiveMP.jl` is presented below. For the full list we refer the reader to the `ReactiveMP.jl` documentation.

#### Factorisation constraint option

Users can specify a factorisation constraint over the approximate posterior `q` for variational inference.
The general syntax for factorisation constraints over `q` is the following:
```julia
variable ~ Node(node_arguments...) where { q = RecognitionFactorisationConstraint }
```

where `RecognitionFactorisationConstraint` can be the following

1. `MeanField()`

Automatically specifies a mean-field factorisation

Example:

```julia
y ~ NormalMeanVariance(y_mean, y_var) where { q = MeanField() }
```

2. `FullFactorisation()`

Automatically specifies a full factorisation

Example:

```julia
y ~ NormalMeanVariance(y_mean, y_var) where { q = FullFactorisation() }
```

3. `q(μ)q(v)q(out)` or `q(μ) * q(v) * q(out)`

A user can specify any factorisation he wants as the multiplication of `q(interface_names...)` factors. As interface names the user can use the interface names of an actual node (read node's documentation), its aliases (if available) or actual random variable names present in the `~` operator expression.

Examples: 

```julia
# Using interface names of a `NormalMeanVariance` node for factorisation constraint. 
# Call `?NormalMeanVariance` to know more about interface names for some node
y ~ NormalMeanVariance(y_mean, y_var) where { q = q(μ)q(v)q(out) }
y ~ NormalMeanVariance(y_mean, y_var) where { q = q(μ, v)q(out) }

# Using interface names aliases of a `NormalMeanVariance` node for factorisation constraint. 
# Call `?NormalMeanVariance` to know more about interface names aliases for some node
# In general aliases correspond to the function names for distribution parameters
y ~ NormalMeanVariance(y_mean, y_var) where { q = q(mean)q(var)q(out) }
y ~ NormalMeanVariance(y_mean, y_var) where { q = q(mean, var)q(out) }

# Using random variables names from `~` operator expression
y ~ NormalMeanVariance(y_mean, y_var) where { q = q(y_mean)q(y_var)q(y) }
y ~ NormalMeanVariance(y_mean, y_var) where { q = q(y_mean, y_var)q(y) }

# All methods can be combined easily
y ~ NormalMeanVariance(y_mean, y_var) where { q = q(μ)q(y_var)q(out) }
y ~ NormalMeanVariance(y_mean, y_var) where { q = q(y_mean, v)q(y) }
```

#### Metadata option

Is is possible to pass any extra metadata to a factor node with the `meta` option. Metadata can be later accessed in message computation rules:

```julia
z ~ f(x, y) where { meta = ... }
```

For more information about possible node creation options we refer the reader to the `ReactiveMP.jl` documentation.

## [Constraints specification](@id user-guide-constraints-specification)

`GraphPPL.jl` exports `@constraints` macro for the extra constraints specification that can be used during the inference step in `ReactiveMP.jl` package.

### General syntax 

`@constraints` macro accepts both regular julia functions and just simple blocks. In the first case it returns a function that return constraints and in the second case it returns constraints directly.

```julia
myconstraints = @constraints begin 
    q(x) :: PointMass
    q(x, y) = q(x)q(y)
end
```

or 

```julia
@constraints function make_constraints(flag)
    q(x) :: PointMass
    if flag
        q(x, y) = q(x)q(y)
    end
end

myconstraints = make_constraints(true)
```

### Marginal and messages form constraints

To specify marginal or messages form constraints `@constraints` macro uses `::` operator (in the similar way as Julia uses it for type specification)

The following constraint

```julia
@constraints begin 
    q(x) :: PointMass
end
```

indicates that the resulting marginal of the variable (or array of variables) named `x` must be approximated with a `PointMass` object. To set messages form constraint `@constraints` macro uses `μ(...)` instead of `q(...)`:

```julia
@constraints begin 
    q(x) :: PointMass
    μ(x) :: SampleList 
    # it is possible to assign different form constraints on the same variable 
    # both for the marginal and for the messages 
end
```

`@constraints` macro understands "stacked" form constraints. For example the following form constraint

```julia
@constraints begin 
    q(x) :: SampleList(1000, LeftProposal()) :: PointMass
end
```

indicates that the resulting posterior first maybe approximated with a `SampleList` and in addition the result of this approximation should be approximated as a `PointMass`. 
For more information about form constraints we refer the reader to the `ReactiveMP.jl` documentation.


### Factorisation constraints on posterior distribution `q()`

`@model` macro specifies generative model `p(s, y)` where `s` is a set of random variables and `y` is a set of obseervations. In a nutshell the goal of probabilistic programming is to find `p(s|y)`. `p(s|y)` during the inference procedure can be approximated with another `q(s)` using e.g. KL divergency. By default there are no extra factorisation constraints on `q(s)` and the result is `q(s) = p(s|y)`. However, inference may be not tractable for every model without extra factorisation constraints. To circumvent this, `GraphPPL.jl` and `ReactiveMP.jl` accepts optional factorisation constraints specification syntax:

For example:

```julia
@constraints begin 
    q(x, y) = q(x)q(y)
end
```

specifies a so-called mean-field assumption on variables `x` and `y` in the model. Futhermore, if `x` is an array of variables in our model we may induce extra mean-field assumption on `x` in the following way.

```julia
@constraints begin 
    q(x, y) = q(x)q(y)
    q(x) = q(x[begin])..q(x[end])
end
```

These constraints specifies a mean-field assumption between variables `x` and `y` (either single variable or collection of variables) and additionally specifies mean-field assumption on variables `x_i`.

!!! note 
    `@constraints` macro does not support matrix-based collections of variables. E.g. it is not possible to write `q(x[begin, begin])..q(x[end, end])`

It is possible to write more complex factorisation constraints, for example:

```julia
@constraints begin 
    q(x, y) = q(x[begin], y[begin])..q(x[end], y[end])
end
```

Specifies a mean-field assumption between collection of variables named `x` and `y` only for variables with different indices. Another example is

```julia
@constraints function make_constraints(k)
    q(x) = q(x[begin:k])q(x[k+1:end])
end
```

In this example we specify a mean-field assumption between a set of variables `x[begin:k]` and `x[k+1:end]`. 

To create a model with extra constraints user may use optional `constraints` keyword argument for the model function:

```julia
@model function my_model(arguments...)
   ...
end

constraints = @constraints begin 
    ...
end

model, (x, y) = model_name(arguments..., constraints = constraints)
```

For more information about factorisation constraints we refer the reader to the `ReactiveMP.jl` documentation.

## [Meta specification](@id user-guide-meta-specification)

Some nodes in `ReactiveMP.jl` accept optional meta structure that may be used to change or customise the inference procedure. As an example `GCV` node accepts the approxximation method that will be used to approximate non-conjugate relationships between variables in this node. `GraphPPL.jl` exports `@meta` macro to specify node-specific meta information. For example:

```julia
meta = @meta begin 
    GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(20))
end
```

indicates, that for every `GCV` node in the model that has `x`, `k` and `w` as connected variables the `GCVMetadata(GaussHermiteCubature(20))` meta object should be used.

`@meta` accepts function expression in the same way as `@constraints` macro, e.g:


```julia
@meta make_meta(n)
    GCV(x, k, w) -> GCVMetadata(GaussHermiteCubature(n))
end

meta = make_meta(20)
```

To create a model with extra meta options user may use optional `meta` keyword argument for the model function:

```julia
@model function my_model(arguments...)
   ...
end

meta = @meta begin 
    ...
end

model, (x, y) = model_name(arguments..., meta = meta)
```

For more information about the meta specification we refer the reader to the `ReactiveMP.jl` documentation.
