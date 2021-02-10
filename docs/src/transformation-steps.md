# Transformation steps

## Step 1: Normalizarion of `~` operator node arguments

Any expression of the form 

```julia
lhs ~ Node(..., f(...), ...)
``` 

is translated to

```julia
lhs ~ Node(..., var"#anonymous" ~ f(...), ...)
```

The only one exception is reference expression of the form `x[f(i)]` which are left untouched.

This step is recursive from top to bottom.

This step forces model to create an anonymous node for any inner function call within `~` operator expression. In some cases backend can (and will) optimize this inner anonymous nodes into just function calls. E.g. following example won't create any additional nodes in the model 

```julia
precision = 1.0

noise ~ NormalMeanVariance(noise_mean, 1.0 / precision) # Since 1.0 and precision are constants inference backend can just apply `/` function to them `/(1.0, precision)`.
```

## Step 2: Main pass

### `datavar()` transformation

Any expression of the form 

```
datavar(args...)
```

is translated to 

```
datavar(var"#model", ensure_type(args[1]), args[2:end]...)
```

where `var"#model"` references to an anonymous model variable, `ensure_type` function ensures that the first argument is a valid type object, rest of the arguments are left untouched.

This step is recursive from top to bottom.

### `randomvar()` transformation

Any expression of the form 

```
randomvar(args...)
```

is translated to 

```
randomvar(var"#model", args...)
```

where `var"#model"` references to an anonymous model variable, arguments are left untouched.

This step is recursive from top to bottom.

### `constvar()` transformation

Any expression of the form 

```
constvar(args...)
```

is translated to 

```
constvar(var"#model", args...)
```

where `var"#model"` references to an anonymous model variable, arguments are left untouched.

This step is recursive from top to bottom.

### `~` operator transformation

WIP