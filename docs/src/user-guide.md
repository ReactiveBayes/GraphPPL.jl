# User guide

Probabilistic models incorporate elements of randomness to describe an event or phenomenon by using random variables and probability theory. A probabilistic model can be represented visually by using probabilistic graphical models (PGMs). A factor graph is a type of PGM that is well suited to cast inference tasks in terms of graphical manipulations.

`GraphPPL.jl` is a Julia package presenting a model specification language for probabilistic models and uses the `ReactiveMP.jl` package as a backend for a factor graph creation.

## Model specification

The `GraphPPL.jl` package exports the `@model` macro for model specification. 
This `@model` macro accepts two arguments: model options and the model specification itself in a form of regular Julia function. For example: 

```julia
@model [ option1 = ..., option2 = ... ] function model_name(model_arguments...)
    # model specification here
    return ...
end
```

Model options are optional and may be omitted:

```julia
@model function model_name(model_arguments...)
    # model specification here
    return ...
end
```

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

It is also important to note that any model should return something, such as variables or nodes. If a model doesn't return anything then an error will be raised during runtime. 

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

### Data variables

It is important to have a mechanism to pass data values to the model. You can create data inputs with `datavar()` function. As a first argument it accepts a type specification and optional dimensionality (as additional arguments or as a tuple).

Examples: 

```julia
y = datavar(Float64) # Creates a single data input with `y` as identificator
y = datavar(Float64, n) # Returns a vector of  `y_i` data input objects with length `n`
y = datavar(Float64, n, m) # Returns a matrix of `y_i_j` data input objects with size `(n, m)`
y = datavar(Float64, (n, m)) # It is also possible to use a tuple for dimensionality
```

### Random variables

There are several ways to create random variables. The first one is an explicit call to `randomvar()` function. By default it doesn't accept any argument, creates a single random variable in the model and returns it. It is also possible to pass dimensionality arguments to `randomvar()` function in the same way as for the `datavar()` function.

Examples: 

```julia
x = randomvar() # Returns a single random variable which can be used later in the model
x = randomvar(n) # Returns an vector of random variables with length `n`
x = randomvar(n, m) # Returns a matrix of random variables with size `(n, m)`
x = randomvar((n, m)) # It is also possible to use a tuple for dimensionality
```

The second way to create a random variable is to create a node with the `~` operator. If the random variable has not yet been created before this call, it will be created automatically during the creation of the node. Read more about the `~` operator below.

## Node creation

Factor nodes are used to define a relationship between random variables and/or constants and data inputs. A factor node defines a probability distribution over selected random variables. 

We model a random variable by a probability distribution using the `~` operator. For example, to create a random variable `y` which is modeled by a Normal distribution, where its mean and variance are controlled by the random variables `m` and `v` respectively, we define

```julia
m = randomvar()
v = randomvar()
y ~ NormalMeanVariance(m, v) # Creates a `y` random variable automatically
```

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

### Node creation options

To pass optional arguments to the node creation constructor the user can use the `where { options...  }` options specification syntax.

Example:

```julia
y ~ NormalMeanVariance(y_mean, y_var) where { q = q(y_mean)q(y_var)q(y) } # mean-field factorisation over q
```

A list of all available options is presented below:

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

#### Portal option

To assign a factor node's local portal for all outbound messages the user may use a `portal` option:

```julia
y ~ NormalMeanVariance(m, v) where { portal = LoggerPortal() } # Log all outbound messages with `LoggerPortal` portal
```