# [Constraint Specification](@id constraints-specification)

Variational inference on factor graphs requires specifying the structure of the approximate posterior distribution `q`, namely how it factorizes and what functional forms individual marginals take. These choices determine the variational family over which an objective function, such as the Bethe Free Energy (BFE), is optimized, and in `GraphPPL` they are called **constraints** and are specified using the `@constraints` macro.

For more background on the Bethe Free Energy and its connection to message passing on factor graphs, see:
- [Yedidia et al. (2005)](https://ieeexplore.ieee.org/iel5/18/31406/01459044.pdf) on belief propagation and regional approximations to the variational free energy;
- [Dauwels (2007)](https://ieeexplore.ieee.org/iel5/4497218/4557062/04557602.pdf) on variational message passing on Forney-style factor graphs;
- [Senoz et al. (2021)](https://doi.org/10.3390/e23070807) on constraint manipulation and message passing on factor graphs.

There are two types of constraints:
- **Factorization constraints** define how the variational posterior factorizes around factor nodes (e.g. ``q(x, y, z) = q(x, y)q(z)``).
- **Functional form constraints** specify the distributional family for a variable's posterior (e.g. ``q(x) \sim \mathrm{Normal}``).

## The constraints macro

The constraints macro accepts a high-level constraint specification and converts this to a structure that can be interpreted by `GraphPPL` models. For example, suppose we have the following toy model, that defines a Gaussian distribution over `x` with mean `y` and variance `z`:

```@example constraints
using GraphPPL
using Distributions
import GraphPPL: @model

@model function toy_model(x, y, z)
    x ~ Normal(y, z)
end
```
Suppose we want to apply the following constraints over the variational posterior `q`:
```math
q(x, y, z) = q(x, y)q(z) \\
q(x) \sim \mathrm{Normal}
```
We can write this in the constraints macro using the following code:
```@example constraints
@constraints begin
    q(x, y, z) = q(x, y)q(z)
    q(x) :: Normal
end
```
We can reference variables in the constraints macro with their corresponding name in the model specification. Naturally, this raises the question on how we can specify constraints over variables in submodels, as these variables are not available in the scope of the model specification. To this extent, we can nest our constraints in the same way in which we have nested our models, and use the `for q in submodel` block to specify constraints over submodels. For example, suppose we have the following model:
```@example constraints
@model function toy_model(x, y, z)
    x ~ Normal(y, z)
    y ~ Normal(0, 1)
end

@model function outer_toy_model(a, b, c)
    a ~ toy_model(y = b, z = c)
end
```
We can specify constraints over the `toy_model` submodel using the following code:
```@example constraints
@constraints begin
    for q in toy_model
        q(x, y, z) = q(x, y)q(z)
        q(x) :: Normal
    end
end
```
The submodel constraint specification applies to all submodels with the same name. However, as a user you might want to specify constraints over a specific submodel. To this extent, we can use the `for q in (submodel, index)` syntax. This will only apply the constraints to the submodel with the corresponding index. For example, suppose we have the following model:
```@example constraints
@model function toy_model(x, y, z)
    x ~ Normal(y, z)
    y ~ Normal(0, 1)
end

@model function outer_toy_model(a, b, c)
    a ~ toy_model(y = b, z = c)
    a ~ toy_model(y = b, z = c)
end
```
We can specify constraints over the first `toy_model` submodel using the following code:
```@example constraints
@constraints begin
    for q in (toy_model, 1)
        q(x, y, z) = q(x, y)q(z)
        q(x) :: Normal
    end
end
```

## Constraints over vector variables

When a model contains vector (or array) latent variables, we can specify factorization constraints over individual elements using the `begin` and `end` indexing syntax. For example, consider a random walk model where latent states `x` are coupled through sequential dependencies:
```@example constraints
@model function random_walk_model(y, n)
    local x
    x[1] ~ NormalMeanVariance(0.0, 1.0)
    for i in 2:n
        x[i] ~ Normal(x[i - 1], 1.0)
    end
    for i in 1:n
        y[i] ~ Normal(x[i], 1.0)
    end
end
```
Since the latent states `x` are coupled through the random walk prior, they are not conditionally independent. To enforce a mean-field factorization over the elements of `x`, we can write:
```@example constraints
@constraints begin
    q(x) = q(x[begin])..q(x[end])
end
```
This specifies that the joint posterior over `x` factorizes into independent marginals for each element: ``q(\mathbf{x}) = \prod_i q(x_i)``.
The `..` operator creates a factorization range from the first to the last element of the vector.

Alternatively, `MeanField()` can be used as a shorthand to factorize all variables into independent marginals:
```@example constraints
@constraints begin
    q(x) = MeanField()
end
```

!!! note
    For a full example using vector variable constraints in practice, see the [Gamma Mixture](https://reactivebayes.github.io/RxInfer.jl/stable/examples/gamma_mixture/) example in the RxInfer documentation.

## Stacked functional form constraints
In the constraints macro, we can specify multiple functional form constraints over the same variable. For example, suppose we have the following model:
```@example constraints
@constraints begin 
    q(x) :: Normal :: Beta
end
```
In this constraint the posterior over `x` will first be constrained to be a normal distribution, and then the result with be constrained to be a beta distribution.
This might be useful to create a chain of constraints that are applied in order. The resulting constraint is a tuple of constraints.

!!! note 
    The inference backend must support stacked constraints for this feature to work. Some combinations of stacked constraints might not be supported or theoretically sound.

## Default constraints
While we can specify constraints over all instances of a submodel at a specific layer of the hierarchy, we're not guaranteed to have all instances of a submodel at a specific layer of the hierarchy. To this extent, we can specify default constraints that apply to all instances of a specific submodel. For example, we can define the following model, where we have a `recursive_model` instance at every layer of the hierarchy:
```@example constraints
@model function recursive_model(n, x, y)
    z ~ Gamma(1, 1)
    if n > 0
        y ~ Normal(recursive_model(n = n - 1, x = x), z)
    else
        y ~ Normal(0, z)
    end
end
```
We can specify default constraints over the `recursive_model` submodel using the following code:
```@example constraints
GraphPPL.default_constraints(::typeof(recursive_model)) = @constraints begin
    q(x, y, z) = q(x)q(y)q(z)
end
```
When a model of type `recursive_model` is now created, the default constraints will be applied to all instances of the `recursive_model` submodel. Note that default constraints are overwritten by constraints passed to the top-level model, if they concern the same instance of a submodel.

## Prespecified constraints
`GraphPPL` provides a set of prespecified constraints that can be used to specify constraints over the variational posterior. These constraint sets are aliases for their corresponding equivalent constriant sets, and can be used for convenience. The following prespecified constraints are available:

```@docs
GraphPPL.MeanField
GraphPPL.BetheFactorization
```

This means that we can write the following:
```@example constraints
@constraints begin
    q(x, y, z) = MeanField() # Equivalent to q(x, y, z) = q(x)q(y)q(z)
    q(a, b, c) = BetheFactorization() # Equivalent to q(a, b, c) = q(a, b, c), can be used to overwrite default constraints.
end
```

## Plugin's internals

```@docs
GraphPPL.@constraints
GraphPPL.VariationalConstraintsPlugin
GraphPPL.Constraints
GraphPPL.SpecificSubModelConstraints
GraphPPL.GeneralSubModelConstraints
GraphPPL.FactorizationConstraint
GraphPPL.FactorizationConstraintEntry

GraphPPL.MarginalFormConstraint
GraphPPL.MessageFormConstraint

GraphPPL.materialize_constraints!
GraphPPL.factorization_split

GraphPPL.SplittedRange
GraphPPL.CombinedRange
```