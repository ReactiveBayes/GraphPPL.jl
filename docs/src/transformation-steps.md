# Getting started

GraphPPL.jl is a Julia package with model specification language for probabilistic models. Currently only ReactiveMP.jl backend is supported.

# Basics

## Model definition

To define a model use `@model` macro. `@model` macro accepts a function definition and optional model parameters (as a first argument).

Examples: 

```julia
@model function kalman_filter(noise_mean, noise_var)
    # model specification here
end
```

or 

```julia
@model [ model extra options here... ] function kalman_filter(noise_mean, noise_var)
    # model specification here
end
```

Later `kalman_filter()` function can be used as a regular function.
It is important to note that any model should return something, e.g. variables, nodes. If model doesn't return anything an error will be raised in runtime.

!!! note
    It is not allowed to pass short function definition (e.g. `@model foo() = ...`) to a `@model` macro.
    
## Variable creation

### Constants

Any constant will be automatically converted to a constant variable in the graph model in runtime.

### Data variables

It is important to have a mechanism to pass data values to the model. User can create data variables via `datavar()` function. As a first argument it accepts a type specification and optional dimensionality (as varargs or as a tuple).

Examples: 

```julia
y = datavar(Float64)
y = datavar(Float64, n_observations) # Returns an array of `DataVariable` objects
y = datavar(Float64, 100, 100) # Returns a matrix of `DataVariable` objects and so on
y = datavar(Float64, (100, 100)) # It is possible to use a tuple for dims
```

!!! note
    Current implementation accepts only deterministic primitive types for data variables, like floats or matrices and etc. While in principle it is possible to pass distribution (e.g. `datavar(Normal{Float64})`) as data, it is not advisable. Doing so may lead to wrong inference results.

### Random variables

There are several way to create random variables. The first one is explicit call to `randomvar` function. By default it doesn't accept any argument, creates a single random variable in the model and returns it. It is also possible to pass dimensionality arguments to `randomvar` function in the same way as for `datavar`.

Examples: 

```julia
x = randomvar() # Returns a single random variable which can be used later in the model
x = randomvar(n_observations) # Returns an array of `RandomvVariable` objects
x = randomvar(100, 100) # Returns a matrix of `DataVariable` objects and so on
x = randomvar((100, 100)) # It is possible to use a tuple for dims
```

The second way to create random variable is to use `~` operator. Random variables are created automatically during node creation (if they were not created before).
Read more about `~` operator below.

Example

```julia
noise ~ NormalMeanVariance(noise_mean, noise_var) # Creates a `noise` random variable which can be used later in the model 
```

### Node creation

To create a node user can use `~` operator. 

It automatically resolves any inner function calls into anonymous extra nodes in case of non-linear transformation. But it is important to note that inference backend can (and will) optimize inner non-linear deterministic function calls in case if all arguments are constant or data variables.

```julia
noise ~ NormalMeanVariance(mean, inv(precision)) # Will create a non-linear node in case if `precision` is a random variable. Won't create an additional non-linear node in case if `precision` is a constant or data variable.
```

It is possible to use any complex expression with in `~` operator arguments list. The only one exception is `ref` expressions (e.g `x[i]`). All reference expressions within `~` operator arguments list left untouched during model parsing.

```julia
y ~ NormalMeanVariance(x[i - 1], variance) # While in principle `i - 1` is an inner function call model parser will leave it untouched and won't create any anonymous nodes for `ref` expressions.

y ~ NormalMeanVariance(A * x[i - 1], variance) # This example will create a `*` anonymous node (in case if x[i - 1] is a random variable) and leave `x[i - 1]` untoched.
```

Extra anonymous nodes are not always created

[WIP SECTION THIS IS NOT IMPLEMENTED]

It is possible to return a node reference from `~` operator. Use the following syntax

```julia
node, y ~ NormalMeanVariance(mean, var)
```

Having a node reference can be useful in case if user wants to return it from a model and use it later to specify initial joint marginals.

### Node creation options

To pass an optional arguments to node creation constructor user can use `where { options...  }` options specificator syntax.

Example:

```julia
y ~ NormalMeanVariance(y_mean, y_var) where { q = q(y_mean)q(y_var)q(y) } # mean-field factorisation over q
```

A list of all available options is presented below:

#### Factorisation constraint option

User can specify factorisation constraint over `q` for variational inference.
General syntax for factorisation constraint over `q` is the following:
```julia
variable ~ Node(node_arguments...) where { q = Constraint }
```

where `Constraint` can be the following

1. `MeanField()`

Automatically specifies a mean-field factorisation

Example:

```
y ~ NormalMeanVariance(y_mean, y_var) where { q = MeanField() }
```

2. `FullFactorisation()`

Automatically specifies a full factorisation

Example:

```
y ~ NormalMeanVariance(y_mean, y_var) where { q = FullFactorisation() }
```

3. `q(μ)q(v)q(out)` or `q(μ) * q(v) * q(out)`

User can specify any factorisation he wants via multiplication of `q(interface_names...)` factors. As interface names user can use interface names of an actual node (read node's documentation), its aliases (if available) or actual random variable names present in `~` operator expression.

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

# Transformation steps

## Step 1

