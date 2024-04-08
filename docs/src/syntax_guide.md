# [Syntax Guide](@id syntax-guide)

## The `@model` macro

The `@model` macro accepts a description of a probabilistic program and defines a function that creates (upon materialization) a corresponding factor graph.
The single argument of the macro is a Julia function. 

```@example model_macro
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function model_definition_example()
    y ~ Beta(1.0, 1.0)
end
model_definition_example() #hide
```

The model function can accept arguments

```@example model_macro
@model function model_definition_example(a, b)
    y ~ Beta(a, b)
end
model_definition_example(a = 1, b = 2) #hide
```

Note that all argument are converted to keyword arguments and positional arguments are not supported.
As a consequence, the models defined with the `@model` macro can't use multiple dispatch.

```@example model_macro
model_definition_example(a = 1.0, b = 1.0)
```

## The `~` operator

The `~` operator is at the heart of the `GraphPPL` syntax. It is used to define and specify the distribution of a random variable. In general, we can write `x ~ dist(args...)` to specify that the random variable `x` is distributed according to the distribution `dist` with parameters `args...`. On the left hand side of the `~` operator we have a single random variable that doesn't necessarily have to be defined yet. On the right hand side we have any factor function that takes some arguments. The arguments to the factor function should be defined, either as constants or as other random variables. The expression on the right hand side of the `~` operator can be a complex expression. For example, we can write `x ~ Bernoulli(Beta(sum(ones(10)), 1))` as an overly complicated way to define a `Bernoulli` random variable with a `Beta(10, 1)` prior.

Variables created with the `~` operator can be used in subsequent statements. The following example reimplements our overly complicated `Bernoulli` random variable by explicitly defining the `p` parameter:

```@example ~_operator
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function tilde_operator_example(x)
    p ~ Beta(10, 1)
    x ~ Bernoulli(p)
end
```

## The `:=` operator
Mathematically, the `~` operator is used to define a stochastic relationship: `x ~ dist(args...)` means that `x` is distributed according to `dist(args...)`. It is therefore mathematically incorrect to use the `~` operator to denote a deterministic relationship. For example: `x ~ 1 + 1` does not make sense. However, deterministic relations are often useful in probabilistic modeling. However, the operation we want to perform is significantly different from an ordinary `=` assignment, since we do want to make a factor node for this deterministic relationship and include it in the factor graph. For these reasons, we introduce the `:=` operator. The `:=` operator is an alias to the `~` operator, that can be used in the same way as the `~` operator, but it is used to denote deterministic relationships. Note that the `:=` operator is merely syntactic sugar and is meant to give context to readers as to which relationships are deterministic and which are stochastic. The following example demonstrates the use of the `:=` operator:

```@example :=_operator
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function colon_equal_operator_example(x)
    p ~ Normal(0, 1)
    x := p + p
end
```
## Broadcasting with the `~` operator
The `~` operator supports broadcasting. This means that we can define multiple random variables at once. For example, we can write `x .~ Normal(μ, σ)` with `μ` and `σ` being vectors of random variables to define multiple random variables at once and store them in the vector `x`. The following example demonstrates the use of broadcasting with the `~` operator:

```@example broadcasting
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function broadcasting_example()
    local p
    for i in 1:10
        p[i] ~ Beta(1, 1)
    end
    y .~ Bernoulli(p)
end
```
In this example, we define 10 random variables `p` with a `Beta(1, 1)` prior and then define a vector of random variables `y` with a `Bernoulli` distribution with the entries of `p` as parameters.

## Difference between random variables and parameters
GraphPPL makes an explicit distinction between random variables and parameters, even though they can both enter the model in the same way. Random variables are explicitly present in your factor graph and are not known on model construction (This definition seems backwards since "Random variables" are never truly known, but in case of, for example, data entering your model, we have that we represent the data as a random variable in the factor graph, and even though we would know the value of the data during inference, we don't know the value yet during model construction). Parameters, on the other hand, are known during model construction and are not present in the factor graph. As an example, we can define the following model:

```@example random_variables_parameters
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function recursive_model(depth, y)
    if depth == 0
        y ~ Normal(0, 1)
    else
        x ~ Normal(0, 1)
        y ~ recursive_model(depth = depth - 1)
    end
end
```

Here, we use `depth` as a parameter: It defines the control flow of the model construction, and defines the amount of `recursive_model` submodels we create. `y` is a random variable: It is present in the factor graph and is not known during model construction. Therefore, we can never use statements like `if y > 0` in the model definition, since `y` is not known during model construction. Conversely, we cannot infer a distribution over `depth`, since it is a parameter and not a random variable.

## `local` keyword
As is customary in Julia, a `for` loop opens a local scope. This means that variables defined inside the `for` loop are not accessible outside of the loop. This can be problematic when defining random variables inside a loop. In similar fashion to Julia, we can define a variable with the `local` keyword and make it accessible outside of the loop, while setting priors inside the loop. The following example demonstrates the use of the `local` keyword:

```@example local_keyword
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function local_keyword_example()
    local p
    for i in 1:10
        p[i] ~ Beta(1, 1)
    end
    y .~ Bernoulli(p)
end
```

## The `new` function
GraphPPL explicitly handles the `~` operator with a single random variable on the left hand side, and predefined random variables as arguments on the right hand side. However, sometimes we want to simultaneously create multiple random variables from the same submodel. One of the situations in which this occurs is in state-space models, where we want to create a datapoint as well as the state of the system at the next timestep as new random variables when invoking a time-slice of the model as a submodel. For this purpose, we introduce the `new` function. The `new` function can wrap random variables on the right hand side of the `~` operator to indicate to `GraphPPL` that the random variable should be created anew. The following example demonstrates the use of the `new` function:

```@example new_function
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function time_slice_ssm(y, x_prev, x_new)
    y ~ Normal(x_prev, 1)
    x_new ~ Normal(x_prev, 1)
end

@model function ssm(y)
    x[1] ~ Normal(0, 1)
    for i in eachindex(y)
        y[i] ~ time_slice_ssm(x_prev = x[i], x_new = new(x[i + 1]))
    end
end
```

!!! note
    The `new` function is a syntax construct that can be used only within the `~` expression and does not exist in run-time. `GraphPPL` cannot define this function as it is a reserved keyword in Julia.

## The `where { meta = ... }` block

Factor nodes can have arbitrary metadata attached to them with the `where { meta = ... }` block after the `~` operator. 
For this functionality to work the [`GraphPPL.MetaPlugin`](@ref) must be enabled.
This metadata can be queried by inference packages to modify the inference procedure.
For example:
```@example where_syntax
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function some_model(a, b)
    x ~ Beta(a, b) where { meta = "Hello, world!" }
end

model = GraphPPL.create_model(
    GraphPPL.with_plugins(
        some_model(a = 1, b = 2),
        GraphPPL.PluginsCollection(GraphPPL.MetaPlugin())
    )
)

ctx   = GraphPPL.getcontext(model)
node  = model[ctx[Beta, 1]]

@test GraphPPL.getextra(node, :meta) == "Hello, world!" #hide
GraphPPL.getextra(node, :meta)
```

Other plugins can hook into the `where { ... }` block with the [`GraphPPL.preprocess_plugin`](@ref).

## Tracking the `created_by` field

Factor nodes in the models can optionaly save the expressions with which they were created. For this functionality to 
work the [`GraphPPL.NodeCreatedByPlugin`](@ref) plugin must be enabled.
For example: 

```@example created_by_syntax
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function some_model(a, b)
    x ~ Beta(a, b)
    y ~ Beta(x, 1)
end

model = GraphPPL.create_model(
    GraphPPL.with_plugins(
        some_model(a = 1, b = 2),
        GraphPPL.PluginsCollection(GraphPPL.NodeCreatedByPlugin())
    )
)
ctx    = GraphPPL.getcontext(model)
node_1 = model[ctx[Beta, 1]]
node_2 = model[ctx[Beta, 2]]

nothing #hide
```

```@example created_by_syntax
@test repr(GraphPPL.getextra(node_1, :created_by)) == "x ~ Beta(a, b)" #hide
GraphPPL.getextra(node_1, :created_by)
```

```@example created_by_syntax
@test repr(GraphPPL.getextra(node_2, :created_by)) == "y ~ Beta(x, 1)" #hide
GraphPPL.getextra(node_2, :created_by)
```

More information about [`GraphPPL.NodeCreatedByPlugin`](@ref) can be found [here](@ref plugins-node-created-by).

## The `return` statement

Model can have the return statement inside of them for early stopping. 
The return statement plays no role in [nested models specification](@ref nested-models), however.
The inference packages can also query the return statement of a specific model if needed from its [`GraphPPL.Context`](@ref).

```@example return_syntax
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function some_model(a, b)
    x ~ Beta(a, b)
    return "Hello, world!"
end

model = GraphPPL.create_model(some_model(a = 1, b = 2))
ctx   = GraphPPL.getcontext(model)
@test GraphPPL.returnval(ctx) == "Hello, world!" #hide
GraphPPL.returnval(ctx)
```

## Nested models
`GraphPPL` supports any previously defined model to be used as a submodel in another model. We have dedicated a separate page in the documentation on this topic, which can be found [here](nested_models.md).

## Scopes
While `GraphPPL` aims to be as close to Julia as possible, there are some differences in the way scopes are handled. In Julia, a `for` loop opens a new scope, meaning that variables defined inside the loop are not accessible outside of the loop. While this is also true in `GraphPPL` and variables can be defined with the `local` keyword to make them accessible outside of the loop, creating a variable with the same name in two different for-loops will reference the same variable. This is different from Julia, where the two variables would be distinct. The following example demonstrates this behaviour:

```@example scopes
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function scope_example()
    for i in 1:10
        x[i] ~ Normal(0, 1)
    end
    for i in 1:10
        x[i] ~ Normal(0, 1)
    end
end
```
Instead of creating 20 random variables, this model will create 10 random variables and then reuse them in the second loop. This is because of the way `GraphPPL` handles variable creation. If you want to create 20 distinct random variables, you should use different names for the variables in the two loops.

## Arrays in GraphPPL
As you can see in the previous examples, arrays in `GraphPPL` behave slightly differently than in Julia. In `GraphPPL`, we can define any `x[i]` as the left hand side of the `~` operator, without prespecifying `x` or its size. This trick involves a custom implementation of arrays in `GraphPPL` that dynamically grows as needed. This means that custom list comprehension statements in `GraphPPL` could give some unexpected behaviour. These examples are mostly pathological and should in general be avoided. However, if you do need custom list constructions, please wrap the result in `GraphPPL.ResizableArray` to ensure that factor nodes and submodels accept the array as a valid input. Note that variational constraints might throw exceptions if you try to specify a variational factorization constraint over custom created arrays of random variables.

```@example array_syntax
using GraphPPL, Distributions, Test #hide
import GraphPPL: @model #hide

@model function array_example()
    x1 ~ Normal(0, 1)
    x2 ~ Normal(0, 1)
    x3 ~ Normal(0, 1)
    x = GraphPPL.ResizableArray([x1, x2, x3])
    y ~ some_submodel(in = x)
end
```