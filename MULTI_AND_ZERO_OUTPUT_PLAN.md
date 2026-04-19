# Implementation Plan: Multi-Output and Zero-Output Submodel Interfaces

## Overview

Two new features for GraphPPL.jl's nested model specification:

**(a) Multi-output LHS** — Allow multiple return interfaces on the left-hand side of `~`:
```julia
(a, b) ~ my_submodel(c = c_val, d = d_val)
```
This means 2 interfaces are "missing" from the RHS and are assigned to `a` and `b` in declaration order.

**(b) Zero-output (bare call)** — Allow submodel invocation without `~`:
```julia
my_submodel(x = x_val, y = y_val, z = z_val)
```
All interfaces are explicitly provided on the RHS; there is no LHS variable.

---

## Current Architecture (Summary)

The `@model` macro body is transformed through a pipeline of expression-rewriting functions (defined in `src/backends/default.jl`):

1. `check_reserved_variable_names_model`
2. `save_expression_in_tilde` — injects `created_by` option
3. `convert_deterministic_statement` — `:=` → `~` with `is_deterministic`
4. `convert_local_statement` — `local x ~ ...`
5. `convert_to_kwargs_expression` — positional kw-like args → kwargs
6. `add_get_or_create_expression` — ensure LHS var exists in model
7. `convert_anonymous_variables` — nested `f(g(...))` → anonymous + tilde
8. `replace_begin_end` — `begin`/`end` → `FunctionalIndex`
9. `convert_tilde_expression` — final transform to `make_node!` call

### Where the single-output assumption is enforced:

| Location | Constraint |
|---|---|
| `model_macro.jl:~651` — `convert_tilde_expression` | `@capture(lhs, (var_[index__]) \| (var_))` only matches single symbol or indexed symbol |
| `model_macro.jl:~606` — `generate_lhs_proxylabel` | Takes a single `var` symbol |
| `model_macro.jl:~406` — `add_get_or_create_expression` | Calls `@capture(lhs, (var_[index__]) \| (var_))` — single var |
| `graph_engine.jl:~1846` — `prepare_interfaces` | `static(length(rhs_interfaces)) + static(1)` — hardcoded +1 |
| `graph_engine.jl:~1850-1863` — `prepare_interfaces` dispatch | Errors if missing ≠ 1 |
| `graph_engine.jl:~generated make_node!` | `__lhs_interface__::Union{NodeLabel, ProxyLabel, VariableRef}` — single type |
| `model_macro.jl:~780` — `get_make_node_function` | `make_node!` signature expects single `__lhs_interface__` |

### For zero-output (bare function call):
Without `~`, the expression never enters the tilde pipeline at all — it's treated as a regular Julia function call. No pipeline step captures bare `my_submodel(x=..., y=..., z=...)`.

---

## Implementation Plan

### Feature (a): Multi-Output LHS `(a, b) ~ my_submodel(...)`

#### 1. `save_expression_in_tilde` (model_macro.jl ~line 178)
**No change needed.** The `@capture(e, (lhs_ ~ rhs_ ...))` already captures any LHS expression including tuples, since `lhs_` is a generic pattern.

#### 2. `add_get_or_create_expression` (model_macro.jl ~line 400)
**Change:** Add a new branch that detects when `lhs` is a tuple expression. For each element in the tuple, call `generate_get_or_create` separately.

```julia
function add_get_or_create_expression(e::Expr)
    if @capture(e, (lhs_ ~ rhs_ where {options__}))
        if lhs isa Expr && lhs.head == :tuple
            # Multi-output: get_or_create each element
            creates = map(lhs.args) do elem
                @capture(elem, (var_[index__]) | (var_))
                generate_get_or_create(var, index, rhs)
            end
            return quote
                $(creates...)
                $e
            end
        else
            @capture(lhs, (var_[index__]) | (var_))
            return quote
                $(generate_get_or_create(var, index, rhs))
                $e
            end
        end
    end
    return e
end
```

#### 3. `convert_tilde_expression` (model_macro.jl ~line 641)
**Change:** Add a new branch for tuple LHS. Generate multiple `ProxyLabel`s and pack them into a tuple, then call `make_node!` with the tuple.

```julia
function convert_tilde_expression(e::Expr)
    if @capture(e, (lhs_ ~ fform_(args__; kwargs__) where {options__}) | ...)
        args = GraphPPL.proxy_args(combine_args(args, kwargs))
        options = GraphPPL.options_vector_to_named_tuple(options)
        nodesym = gensym(:node)
        varsym = gensym(:var)
        
        if lhs isa Expr && lhs.head == :tuple
            # Multi-output LHS: (a, b) ~ submodel(...)
            proxy_labels = map(lhs.args) do elem
                @capture(elem, (var_[index__]) | (var_)) || error("Invalid tuple element $(elem)")
                generate_lhs_proxylabel(var, index)
            end
            lhs_tuple = Expr(:tuple, proxy_labels...)
            return quote
                begin
                    $nodesym, $varsym = GraphPPL.make_node!(
                        __model__, __context__, GraphPPL.NodeCreationOptions($(options)),
                        $fform, $lhs_tuple, $args
                    )
                    $varsym
                end
            end
        else
            # Existing single-output path
            @capture(lhs, (var_[index__]) | (var_)) || error(...)
            ...
        end
    end
end
```

#### 4. `generate_lhs_proxylabel` — tuple variant (model_macro.jl ~line 606)
**Add:** A new method to generate a tuple of proxy labels. Actually handled inline in step 3 above.

#### 5. `prepare_interfaces` (graph_engine.jl ~line 1845)
**Change:** Add a new dispatch for multi-output. When `lhs_interface` is a `Tuple`, compute `length(rhs) + length(lhs_tuple)` as total interface count, then match multiple missing interfaces to the tuple elements.

```julia
# New: multi-output prepare_interfaces
function prepare_interfaces(model::Model, fform::F, lhs_interfaces::Tuple, rhs_interfaces::NamedTuple) where {F}
    n_total = static(length(rhs_interfaces)) + static(length(lhs_interfaces))
    missing = missing_interfaces(model, fform, n_total, rhs_interfaces)
    return prepare_interfaces_multi(missing, fform, lhs_interfaces, rhs_interfaces)
end

function prepare_interfaces_multi(::StaticInterfaces{I}, fform::F, lhs_interfaces::Tuple, rhs_interfaces::NamedTuple) where {I, F}
    if length(I) != length(lhs_interfaces)
        error("Node '$(fform)' has $(length(I)) missing interfaces but $(length(lhs_interfaces)) were provided on the LHS.")
    end
    # Build NamedTuple: missing interfaces mapped to lhs elements, then rhs
    all_keys = (I..., keys(rhs_interfaces)...)
    all_vals = (lhs_interfaces..., values(rhs_interfaces)...)
    return NamedTuple{all_keys}(all_vals)
end
```

#### 6. `make_node!` generated function (model_macro.jl ~line 760)
**Change:** Add a second `make_node!` method in `get_make_node_function` that accepts a `Tuple` for `__lhs_interface__`. This method calls `prepare_interfaces` with the tuple, then proceeds as normal but returns the tuple of variables.

Also add a dispatch in `graph_engine.jl` for the `Composite` path that routes `Tuple` lhs through to the generated function.

#### 7. `make_node!` dispatch chain (graph_engine.jl ~line 1930+)
**Change:** Add dispatches to route `lhs_interface::Tuple` through the composite node path.

```julia
# Multi-output composite dispatch
make_node!(::True, ::Composite, ::Stochastic, model, ctx, options, fform, 
    lhs_interface::Tuple, rhs_interfaces::NamedTuple) = 
    make_node!(Composite(), model, ctx, options, fform, lhs_interface, rhs_interfaces, 
        static(length(rhs_interfaces) + length(lhs_interface)))
```

---

### Feature (b): Zero-Output Bare Call `my_submodel(x=..., y=..., z=...)`

#### 1. New pipeline step: `convert_bare_submodel_call` (model_macro.jl)
**Add:** A new pipeline function that detects bare function calls with all keyword arguments and converts them to a `~` expression with no LHS.

```julia
function convert_bare_submodel_call(e::Expr)
    if @capture(e, fform_(; kwargs__)) || @capture(e, fform_(args__))
        if kwargs !== nothing || (args !== nothing && is_kwargs_expression(args))
            # Check if fform is a known Composite node — we can't know at macro time,
            # so we generate a runtime check
            return :(GraphPPL.make_node_no_output!(__model__, __context__, 
                GraphPPL.NodeCreationOptions(), $fform, $(keyword_expressions_to_named_tuple(args_or_kwargs))))
        end
    end
    return e
end
```

Actually, a simpler approach: convert the bare call to a tilde expression with a special sentinel LHS, like `nothing ~ submodel(...)`. This requires less invasive changes.

**Better approach:** Add a new pipeline step that runs before `save_expression_in_tilde`. It detects function calls where ALL arguments are keyword arguments AND the function is annotated with `@model`. Since we can't know at macro-expansion time whether a function is `@model`-defined, we use a **runtime check**: wrap the call in `GraphPPL.__maybe_submodel_call(...)` which checks `NodeType` at runtime.

**Simplest approach (chosen):** We define a new pipeline step `convert_zero_output_submodel` that transforms:
```julia
my_submodel(x = val1, y = val2, z = val3)
```
into:
```julia
nothing ~ my_submodel(x = val1, y = val2, z = val3)
```

Then modify the tilde pipeline to handle `nothing` on the LHS by:
- In `add_get_or_create_expression`: skip get_or_create when lhs is `nothing` (literal)
- In `convert_tilde_expression`: when lhs is `:nothing`, pass a sentinel (e.g., `GraphPPL.NothingInterface()`) 
- In `prepare_interfaces`: add a dispatch for `NothingInterface` that asserts 0 missing interfaces
- In `make_node!`: add dispatch for `NothingInterface` LHS that skips the lhs_interface assignment

**Issue:** At macro time, we cannot distinguish `my_submodel(x=1, y=2)` (which should become a submodel call) from `some_function(x=1, y=2)` (which is a regular Julia function call). The pipeline would incorrectly transform all keyword-only function calls.

**Resolution:** We require explicit opt-in syntax. Two options:
1. `@submodel my_submodel(x=1, y=2, z=3)` — a macro annotation
2. `~ my_submodel(x=1, y=2, z=3)` — bare tilde with no LHS

**Option 2 is cleanest** and consistent with the existing `~` operator. The syntax `~ my_submodel(x=1, y=2, z=3)` is unambiguous and easy to detect.

Actually, even simpler: Julia already parses `~ expr` as a unary `~` call: `Expr(:call, :~, expr)`. But `lhs ~ rhs` is `Expr(:call, :~, lhs, rhs)`. So we need to handle the unary case.

Wait — actually in Julia, `x ~ y` is not valid syntax by default. GraphPPL uses MacroTools `@capture` with the `~` pattern inside the `@model` macro which does AST rewriting. Let me reconsider.

Actually, looking at the code more carefully, inside `@model`, the `~` is handled via `@capture(e, lhs_ ~ rhs_)` which matches the infix `~` operator. Julia does parse `a ~ b` as `Expr(:call, :~, a, b)`. And `~ b` would be `Expr(:call, :~, b)`.

So `~ my_submodel(x=1, y=2)` would be parsed as `Expr(:call, :~, :(my_submodel(x=1, y=2)))` — a unary call. This won't match the existing binary `~` patterns, so we can add a new pipeline step or modify `save_expression_in_tilde` and `convert_tilde_expression` to handle it.

**Final Design for Zero-Output:**

Syntax: `~ my_submodel(x = val1, y = val2, z = val3)`

This is parsed as `Expr(:call, :~, :(my_submodel(x=val1, y=val2, z=val3)))`.

1. Add `convert_zero_output_tilde` pipeline step (early, before `save_expression_in_tilde`):
   ```julia
   function convert_zero_output_tilde(e::Expr)
       if e.head == :call && length(e.args) == 2 && e.args[1] == :~
           rhs = e.args[2]
           # Transform: ~ submodel(...) → __nothing__ ~ submodel(...)
           return Expr(:call, :~, :__nothing__, rhs)
       end
       return e
   end
   ```
   
   We use `__nothing__` as a synthetic symbol that will flow through the pipeline.

2. In `add_get_or_create_expression`: detect `__nothing__` and skip variable creation.

3. In `convert_tilde_expression`: detect `__nothing__` and pass `GraphPPL.NothingInterface()` as lhs.

4. Add `NothingInterface` sentinel type in `graph_engine.jl`.

5. In `prepare_interfaces`: new dispatch for `NothingInterface` that expects 0 missing interfaces.

6. In `make_node!` generated function and dispatch: accept `NothingInterface`, skip lhs assignment.

---

## Detailed Change List

### File: `src/graph_engine.jl`

1. **Add `NothingInterface` type** (near other interface types):
   ```julia
   struct NothingInterface end
   ```

2. **Add `prepare_interfaces` dispatch for zero-output** (after existing `prepare_interfaces`):
   ```julia
   function prepare_interfaces(model::Model, fform::F, ::NothingInterface, rhs_interfaces::NamedTuple) where {F}
       missing = missing_interfaces(model, fform, static(length(rhs_interfaces)), rhs_interfaces)
       return prepare_interfaces_zero(missing, fform, rhs_interfaces)
   end
   
   function prepare_interfaces_zero(::StaticInterfaces{I}, fform::F, rhs_interfaces::NamedTuple) where {I, F}
       if length(I) != 0
           error("Zero-output call to '$(fform)' but $(length(I)) interfaces are still missing: $(I)")
       end
       return rhs_interfaces
   end
   ```

3. **Add `prepare_interfaces` dispatch for multi-output** (after existing `prepare_interfaces`):
   ```julia
   function prepare_interfaces(model::Model, fform::F, lhs_interfaces::Tuple, rhs_interfaces::NamedTuple) where {F}
       n_lhs = length(lhs_interfaces)
       missing = missing_interfaces(model, fform, static(length(rhs_interfaces) + n_lhs), rhs_interfaces)
       return prepare_interfaces_multi(missing, fform, lhs_interfaces, rhs_interfaces)
   end
   
   function prepare_interfaces_multi(::StaticInterfaces{I}, fform::F, lhs_interfaces::Tuple, rhs_interfaces::NamedTuple) where {I, F}
       if length(I) != length(lhs_interfaces)
           error("Node '$(fform)': $(length(I)) missing interfaces $(I) but $(length(lhs_interfaces)) provided on LHS.")
       end
       keys_all = (I..., keys(rhs_interfaces)...)
       vals_all = (lhs_interfaces..., values(rhs_interfaces)...)
       return NamedTuple{keys_all}(vals_all)
   end
   ```

4. **Add `make_node!` dispatches for Tuple and NothingInterface LHS** (in the Composite path):
   ```julia
   # Multi-output: Tuple LHS
   make_node!(::True, ::Composite, ::Stochastic, model, ctx, options, fform,
       lhs_interface::Tuple, rhs_interfaces::NamedTuple) =
       make_node!(Composite(), model, ctx, options, fform, lhs_interface, rhs_interfaces,
           static(length(rhs_interfaces) + length(lhs_interface)))
   
   # Zero-output: NothingInterface LHS  
   make_node!(nodetype::Composite, model, ctx, options, fform, lhs_interface::NothingInterface, rhs_interfaces) =
       make_node!(True(), nodetype, Stochastic(), model, ctx, options, fform, lhs_interface, rhs_interfaces)
   
   make_node!(::True, ::Composite, ::Stochastic, model, ctx, options, fform,
       lhs_interface::NothingInterface, rhs_interfaces::NamedTuple) =
       make_node!(Composite(), model, ctx, options, fform, lhs_interface, rhs_interfaces,
           static(length(rhs_interfaces)))
   ```

5. **In `get_make_node_function`:** Add two more generated `make_node!` methods for `Tuple` and `NothingInterface` LHS types.

### File: `src/model_macro.jl`

6. **Add `generate_lhs_proxylabel` for tuples** (near line 606):
   Already handled by generating individual proxy labels and packing into a tuple in `convert_tilde_expression`.

7. **Modify `add_get_or_create_expression`** (line 400): Handle tuple LHS and `__nothing__`.

8. **Modify `convert_tilde_expression`** (line 641): Handle tuple LHS and `__nothing__`.

9. **Add `convert_zero_output_tilde` pipeline function**.

### File: `src/backends/default.jl`

10. **Add `convert_zero_output_tilde` to the pipeline** (before `save_expression_in_tilde`).

### File: `test/graph_construction_tests.jl`

11. **Add tests for multi-output submodel invocation.**
12. **Add tests for zero-output submodel invocation.**

---

## Test Plan

### Multi-Output Tests

```julia
@model function two_output_submodel(a, b, x)
    a ~ Normal(x, 1)
    b ~ Normal(a, 1)
end

@model function main_multi_output(x)
    (a, b) ~ two_output_submodel(x = x)
    y ~ Normal(a + b, 1)
end
```

Verify: 
- Model creates correctly
- Both `a` and `b` are valid variable references
- The submodel's internal structure is correct
- Interface mapping: `a` → first missing, `b` → second missing (in declaration order)

### Zero-Output Tests

```julia
@model function closed_submodel(x, y)
    z ~ Normal(x, 1)
    y ~ Normal(z, 1)
end

@model function main_zero_output(x, y)
    ~ closed_submodel(x = x, y = y)
end
```

Verify:
- Model creates correctly
- All interfaces are provided explicitly
- Error when not all interfaces are specified

### Error Cases
- `(a, b) ~ submodel(...)` when only 1 interface is missing → error
- `~ submodel(x=...)` when 1 interface is still missing → error
- `(a,) ~ submodel(...)` — single-element tuple should work (1 missing)
