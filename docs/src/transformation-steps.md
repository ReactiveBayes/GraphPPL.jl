# Model specification transformation steps for the ReactiveMP.jl backend

## Step 1: Normalizarion of `~` operator node arguments

Any expression of the form 

```julia
lhs ~ Node(..., f(...), ...)
``` 

is translated to

```julia
lhs ~ Node(..., var"#anonymous" ~ f(...), ...)
```

The only one exception is reference expression of the form `x[f(i)]` which are left untouched. This step forces model to create an anonymous node for any inner function call within `~` operator expression. In some cases ReactiveMP.jl backend can (and will) optimize this inner anonymous nodes into just function calls. E.g. following example won't create any additional nodes in the model 

```julia
precision = 1.0

noise ~ NormalMeanVariance(noise_mean, 1.0 / precision) # Since 1.0 and precision are constants inference backend can just apply `/` function to them `/(1.0, precision)`.
```

## Step 2: Main pass

### `datavar()` transformation

Any expression of the form 

```julia
y = datavar(args...) # empty options here
# or 
y = datavar(args...) where { options... }
```

is translated to 

```
ensure_type(args[1]) || error(...)
y = datavar(var"#model", options, :y, args[1], args[2:end]...)
```

where `var"#model"` references to an hidden model variable, `ensure_type` function ensures that the first argument is a valid type object, rest of the arguments are left untouched. 

The list of possible options:
- `subject`: specifies a subject that will be used to pass data variable related information, see more info in `Rocket.jl` documentation.
- `allow_missing`: boolea flag that controls is is possible to pass `missing` data or not

### `randomvar()` transformation

Any expression of the form 

```julia
x = randomvar(args...) # empty options here
# or
x = randomvar(args...) where { options... }
```

is translated to 

```
x = randomvar(var"#model", options, :x, args...)
```

where `var"#model"` references to an anonymous model variable, arguments are left untouched. 

The list of possible options (see ReactiveMP.jl documentation for more info about these options):
- `pipeline`
- `prod_constraint`
- `prod_strategy`
- `marginal_form_constraint`
- `marginal_form_check_strategy`
- `messages_form_constraint`
- `messages_form_check_strategy`

### `constvar()` transformation

Any expression of the form 

```julia
c = constvar(args...) # constvar's do not support any extra options flags
```

is translated to 

```
c = constvar(var"#model", :c, args...)
```

where `var"#model"` references to an anonymous model variable, arguments are left untouched.

## Step 3: Tilde pass

### 3.0 Node reference pass

All expression of the form 

```julia
variable ~ Node(args...)
```

are translated to 

```julia
node, variable ~ Node(args...)
```

### 3.1 Node options pass

All expressions of the form 

```julia
node, variable ~ Node(args...) where { options... }
```

are translated to 

```julia
node, variable ~ Node(args...; options...)
```

### 3.2 Functional relations pass

All expression of the form

```julia
node, variable ~ Node(args...; options...)
```

represent a valid functional dependency between `variable` and `args...`. There are 2 options for further modification of this expression: 

1. If `variable` has been created before with the help of `datavar()` or `randomvar()` functions the previous expression is translated to:

```julia
node = make_node(var"#model", options, variable, args...) 
```

2. If `variable` has not been created before the expression is translated to:

```julia
node = make_node(var"#model", options, AutoVar(:variable), args...)
```

that internally creates a new variable in the model.

## Step 4: Final pass

During the final pass `GraphPPL.jl` inject before any `return ...` call (and also at the very end) the `activate!` call to the `var#"model"`