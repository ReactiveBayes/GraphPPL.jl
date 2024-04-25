# [Constraint Specification](@id constraints-specification)

`GraphPPL` represents your probabilistic model and as a Bethe Free Energy (BFE), which means that users can define constraints on the variational posterior that influence the inference procedure. The BFE is chosen as the objective function because it is a generalization of many well-known inference algorithms. In this section we will explain how to specify constraints on the variational posterior. There are two major types of constraints we can apply: We can apply factorization constraints to factor nodes, which specify how the variational posterior factorizes around a factor node. We can also apply functional form constraints to variable nodes, which specify the functional form of the variational posterior that a variable takes. We can specify all constraints using the `@constraints` macro.

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
q(x) \sim Normal
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