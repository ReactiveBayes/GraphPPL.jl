export @model
import MacroTools: postwalk, @capture, walk
using NamedTupleTools
using Static

__guard_f(f, e::Expr) = f(e)
__guard_f(f, x) = x

struct guarded_walk
    guard::Function
end

function (w::guarded_walk)(f, x)
    return w.guard(x) ? x : walk(x, x -> w(f, x), f)
end

struct walk_until_occurrence{E}
    patterns::E
end

not_enter_indexed_walk = guarded_walk((x) -> (x isa Expr && x.head == :ref))

function (w::walk_until_occurrence{E})(f, x) where {E <: Tuple}
    return walk(x, z -> any(pattern -> @capture(x, $(pattern)), w.patterns) ? z : w(f, z), f)
end

function (w::walk_until_occurrence{E})(f, x) where {E <: Expr}
    return walk(x, z -> @capture(x, $(w.patterns)) ? z : w(f, z), f)
end

find_where_block = walk_until_occurrence(:(lhs ~ rhs_ where {options__}))

what_walk(anything) = postwalk

"""
    apply_pipeline(e::Expr, pipeline)

Apply a pipeline function to an expression.

The `apply_pipeline` function takes an expression `e` and a `pipeline` function and applies the function in the pipeline to `e` when walking over it. The walk utilized can be specified by implementing `what_walk` for a pipeline funciton.

# Arguments
- `e::Expr`: An expression to apply the pipeline to.
- `pipeline`: A function to apply to the expressions in `e`.

# Returns
The result of applying the pipeline function to `e`.
"""
function apply_pipeline(e::Expr, pipeline)
    walk = what_walk(pipeline)
    return walk(x -> __guard_f(pipeline, x), e)
end

"""
    check_reserved_variable_names_model(expr::Expr)

Check if any of the variable names in the given expression are reserved in the model macro. Reserved variable names are:
- `__parent_options__`
- `__debug__`
- `__model__`
- `__context__`
- `__parent_context__`
- `__lhs_interface__`
- `__rhs_interfaces__`
- `__interfaces__`

# Arguments
- `expr::Expr`: The expression to check for reserved variable names.

# Examples
```jldoctest
julia> check_reserved_variable_names_model(:(__parent_options__ ~ Normal(μ, σ))
ERROR: Variable name in __parent_options__ ~ Normal(μ, σ) cannot be used as it is a reserved variable name in the model macro.
````
"""
function check_reserved_variable_names_model(e::Expr)
    if any(
        reserved_name -> MacroTools.inexpr(e, reserved_name),
        [
            :(__parent_options__),
            :(__debug__),
            :(__model__),
            :(__context__),
            :(__parent_context__),
            :(__lhs_interface__),
            :(__rhs_interfaces__),
            :(__interfaces__),
            :(__n_interfaces__)
        ]
    )
        error("Variable name in $(prettify(e)) cannot be used as it is a reserved variable name in the model macro.")
    end
    return e
end

function check_incomplete_factorization_constraint(e::Expr)
    if @capture(e, q(args__))
        error("Incomplete factorization constraint is not supported in the model macro.")
    end
    return e
end

what_walk(::typeof(check_incomplete_factorization_constraint)) = walk_until_occurrence((:(lhs_ = rhs_), :(lhs_::rhs_)))

"""
    warn_datavar_constvar_randomvar(expr::Expr)

Warn the user that the datavar, constvar and randomvar syntax is deprecated and will not be supported in the future.
"""
function warn_datavar_constvar_randomvar(e::Expr)
    if @capture(e, ((lhs_ = datavar(args__)) | (lhs_ = constvar(args__)) | (lhs_ = randomvar(args__))))
        @warn "datavar, constvar and randomvar syntax are deprecated and will not be supported in the future. Please use the tilde syntax instead."
        return nothing
    end
    return e
end

"""
    save_expression_in_tilde(expr::Expr)

Save the expression found in the tilde syntax in the `created_by` field of the expression. This function also ensures that the `where` clause is always present in the tilde syntax.
"""
function save_expression_in_tilde(e::Expr)
    if @capture(e, (local lhs_ ~ rhs_ where {options__}) | (local lhs_ ~ rhs_))
        options = options === nothing ? [] : options
        return :(local $lhs ~ $rhs where {$(options...), created_by = $(QuoteNode(prettify(e)))})
    elseif @capture(e, (local lhs_ .~ rhs_ where {options__}) | (local lhs_ .~ rhs_))
        options = options === nothing ? [] : options
        return :(local $lhs .~ $rhs where {$(options...), created_by = $(QuoteNode(prettify(e)))})
    elseif @capture(e, (local lhs_ := rhs_ where {options__}) | (local lhs_ := rhs_))
        options = options === nothing ? [] : options
        return :(local $lhs := $rhs where {$(options...), created_by = $(QuoteNode(prettify(e)))})
    elseif @capture(e, (lhs_ ~ rhs_ where {options__}) | (lhs_ ~ rhs_))
        options = options === nothing ? [] : options
    return :($lhs ~ $rhs where {$(options...), created_by = $(QuoteNode(prettify(e)))})
    elseif @capture(e, (lhs_ .~ rhs_ where {options__}) | (lhs_ .~ rhs_))
        options = options === nothing ? [] : options
        return :($lhs .~ $rhs where {$(options...), created_by = $(QuoteNode(prettify(e)))})
    elseif @capture(e, (lhs_ := rhs_ where {options__}) | (lhs_ := rhs_))
        options = options === nothing ? [] : options
        return :($lhs := $rhs where {$(options...), created_by = $(QuoteNode(prettify(e)))})
    else
        return e
    end
end

# For save_expression_in_tilde, we have to walk until we find the tilde syntax once, since we otherwise find tilde syntax twice in the following setting:
# local x ~ Normal(0, 1)
what_walk(::typeof(save_expression_in_tilde)) =
    walk_until_occurrence((:(lhs_ ~ rhs_), :(local lhs_ ~ rhs_), :(lhs_ .~ rhs_), :(local lhs_ .~ rhs_), :(lhs_ := rhs_), :(local lhs_ := rhs_)))

"""
    get_created_by(options::AbstractArray)

Retrieve the `created_by` option from the given options. Expects the options to be retrieved using the `MacroTools.@capture` macro.
"""
function get_created_by(options::AbstractArray)
    for option in options
        if @capture(option, (name_ = expr_))
            if name == :created_by
                return expr
            end
        end
    end
    error("Contains no `created_by` option.")
end

"""
    convert_deterministic_statement(expr::Expr)

Convert a deterministic statement to a tilde statement with the `is_deterministic` option set to `true`.
"""
function convert_deterministic_statement(e::Expr)
    if @capture(e, (lhs_ := rhs_ where {options__}))
        return :($lhs ~ $rhs where {$(options...), is_deterministic = true})
    else
        return e
    end
end

# Ensures that we don't change the `created_by` option as well. This could happen if we have a where clause in the original node definition and it therefore also occcurs in the `created_by` clause
what_walk(::typeof(convert_deterministic_statement)) = walk_until_occurrence(:(lhs_ := rhs_ where {options__}))

"""
    convert_local_statement(expr::Expr)

Converts a statement with the `local` keyword to the creation of an additional variable and the inclusion of thie variable in the subsequent tilde expression.
"""
function convert_local_statement(e::Expr)
    if @capture(e, (local lhs_ ~ rhs_ where {options__}))
        return quote
            $lhs = GraphPPL.add_variable_node!(__model__, __context__, gensym(__model__, $(QuoteNode(lhs))))
            $lhs ~ $rhs where {$(options...)}
        end
    elseif @capture(e, (local lhs_ .~ rhs_ where {options__}))
        return :($lhs .~ $rhs where {$(options...)})
    else
        return e
    end
end

"""
    is_kwargs_expression(e::Expr)

Returns `true` if the given expression `e` is a keyword argument expression, i.e., if its head is either `:kw` or `:parameters`.
"""
function is_kwargs_expression(e::Expr)
    return e.head == :kw || e.head == :parameters
end

"""
    is_kwargs_expression(e::Vector)

Return `true` if all elements in the given vector `e` are keyword argument expressions, i.e., if their heads are either `:kw` or `:parameters`.
"""

function is_kwargs_expression(e::Vector)
    if length(e) > 0
        return sum([is_kwargs_expression(elem) for elem in e]) == length(e)
    else
        return false
    end
end

is_kwargs_expression(e) = false

"""
    convert_to_kwargs_expression(expr::Expr)

Convert an expression to a keyword argument expression. This function is used in the conversion of tilde and dot-tilde expressions to ensure that the arguments are passed as keyword arguments.
"""
function convert_to_kwargs_expression(e::Expr)
    # Logic for ~ operator
    if @capture(e, (lhs_ ~ f_(; kwargs__) where {options__}))
        return e
    elseif @capture(e, (lhs_ ~ f_(args__) where {options__}))
        if GraphPPL.is_kwargs_expression(args)
            return :($lhs ~ $f(; $(args...)) where {$(options...)})
        else
            return e
        end
        # Logic for .~ operator
    elseif @capture(e, (lhs_ .~ f_(; kwargs__) where {options__}))
        return e
    elseif @capture(e, (lhs_ .~ f_(args__) where {options__}))
        if GraphPPL.is_kwargs_expression(args)
            return :($lhs .~ $f(; $(args...)) where {$(options...)})
        else
            return e
        end
        # Logic for := operator
    elseif @capture(e, (lhs_ := f_(; kwargs__) where {options__}))
        return e
    elseif @capture(e, (lhs_ := f_(args__) where {options__}))
        if GraphPPL.is_kwargs_expression(args)
            return :($lhs := $f(; $(args...)) where {$(options...)})
        else
            return e
        end
    else
        return e
    end
end

# This is necessary to ensure that we don't change the `created_by` option as well. 
what_walk(::typeof(convert_to_kwargs_expression)) = guarded_walk((x) -> (x isa Expr && x.args[1] == :created_by))

"""
    convert_to_anonymous(e::Expr, created_by)

Convert an expression to an anonymous variable. This function is used to convert function calls in the arguments of node creations to anonymous variables in the graph.
"""
function convert_to_anonymous(e::Expr, created_by)
    if @capture(e, f_(args__))
        sym = MacroTools.gensym_ids(gensym(:anon))
        return quote
            begin
                $sym = GraphPPL.create_anonymous_variable!(__model__, __context__)
                $sym ~ $f($(args...)) where {anonymous = true, created_by = $created_by}
            end
        end
    end
    return e
end

convert_to_anonymous(e, created_by) = e

"""
    convert_anonymous_variables(e::Expr)

Convert a function argument in the right-hand side of an expression to an anonymous variable. This function is used to convert function calls in the arguments of node creations to anonymous variables in the graph.

# Example
    
    ```jldoctest
    julia> convert_anonymous_variables(:(x ~ Normal(μ, sqrt(σ2)) where {created_by=:(Normal(μ, sqrt(σ2)))}))
    :(x ~ (Normal(μ, anon_1 ~ (sqrt(σ2) where {anonymous = true, created_by = $(Expr(:quote, :(Normal(μ, sqrt(σ2)))))})) where (created_by = $(Expr(:quote, :(Normal(μ, sqrt(σ2))))))))
    ```
"""
function convert_anonymous_variables(e::Expr)
    if @capture(e, (lhs_ ~ fform_(nargs__) where {options__}) | (lhs_ .~ fform_(nargs__) where {options__}))
        created_by = get_created_by(options)
        for (i, narg) in enumerate(nargs)
            nargs[i] = GraphPPL.not_enter_indexed_walk(narg) do argument
                convert_to_anonymous(argument, created_by)
            end
        end
        if @capture(e, (lhs_ ~ fform_(args__) where {options__}))
            return :($lhs ~ $fform($(nargs...)) where {$(options...)})
        elseif @capture(e, (lhs_ .~ fform_(args__) where {options__}))
            return :($lhs .~ $fform($(nargs...)) where {$(options...)})
        end
    end
    return e
end

# This is necessary to ensure that we don't change the `created_by` option as well.
what_walk(::typeof(convert_anonymous_variables)) = walk_until_occurrence((:(lhs_ ~ rhs_ where {options__}), :(lhs_ .~ rhs_ where {options__})))

"""
    add_get_or_create_expression(e::Expr)

Add code to get or create a variable in the graph. The code generated by this function ensures that the left-hand-side is always defined in the local scope and can be used in `make_node!` afterwards.

# Arguments
- `e::Expr`: The expression to modify.

# Returns
A `quote` block with the modified expression.
"""
function add_get_or_create_expression(e::Expr)
    if @capture(e, (lhs_ ~ rhs_ where {options__}))
        @capture(lhs, (var_[index__]) | (var_))
        return quote
            $(generate_get_or_create(var, lhs, index))
            $e
        end
    end
    return e
end

what_walk(::typeof(add_get_or_create_expression)) = guarded_walk((x) -> (x isa Expr && x.args[1] == :created_by))

"""
    generate_get_or_create(s::Symbol, lhs::Symbol, index::Nothing)

Generates code to get or create a variable in the graph. This function is used to generate code for variables that are not indexed.

# Arguments
- `s::Symbol`: The symbol representing the variable.
- `lhs::Symbol`: The symbol representing the left-hand side of the expression.
- `index::Nothing`: The index of the variable. This argument is always `nothing`.

# Returns
A `quote` block with the code to get or create the variable in the graph.
"""
function generate_get_or_create(s::Symbol, lhs::Symbol, index::Nothing)
    return quote
        $s = if !@isdefined($s)
            GraphPPL.getorcreate!(__model__, __context__, $(QuoteNode(s)), nothing)
        else
            (GraphPPL.check_variate_compatability($s, nothing) ? $s : GraphPPL.getorcreate!(__model__, __context__, $(QuoteNode(s)), nothing))
        end
    end
end

"""
    generate_get_or_create(s::Symbol, lhs::Expr, index::AbstractArray)

Generates code to get or create a variable in the graph. This function is used to generate code for variables that are indexed.

# Arguments
- `s::Symbol`: The symbol representing the variable.
- `lhs::Expr`: The expression representing the left-hand side of the assignment.
- `index::AbstractArray`: The index of the variable.

# Returns
A `quote` block with the code to get or create the variable in the graph.
"""
function generate_get_or_create(s::Symbol, lhs::Expr, index::AbstractArray)
    return quote
        $s = if !@isdefined($s)
            GraphPPL.getorcreate!(__model__, __context__, $(QuoteNode(s)), $(index...))
        else
            (GraphPPL.check_variate_compatability($s, $(index...)) ? $s : GraphPPL.getorcreate!(__model__, __context__, $(QuoteNode(s)), $(index...)))
        end
    end
end

function replace_begin_end(e::Symbol)
    if e == :begin
        return :(GraphPPL.FunctionalIndex{:begin}(firstindex))
    elseif e == :end
        return :(GraphPPL.FunctionalIndex{:end}(lastindex))
    end
    return e
end

__guard_f(f::typeof(replace_begin_end), x::Symbol) = f(x)
__guard_f(f::typeof(replace_begin_end), x::Expr) = x

"""
    keyword_expressions_to_named_tuple(keywords::Vector)

Converts a vector of keyword expressions to a named tuple.

# Arguments
- `keywords::Vector`: The vector of keyword expressions.

# Returns
- `NamedTuple`: The named tuple.

# Examples

```julia
julia> keyword_expressions_to_named_tuple([:($(Expr(:kw, :in1, :y))), :($(Expr(:kw, :in2, :z)))])
(in1 = y, in2 = z)
```
"""
function keyword_expressions_to_named_tuple(keywords::Vector)
    result = [Expr(:(=), arg.args[1], arg.args[2]) for arg in keywords]
    return Expr(:tuple, result...)
end

"""
Converts an expression into its proxied equivalent. Used to pass variables in sub-models and create a chain of proxied labels.

```jldoctest
julia> x = GraphPPL.NodeLabel(:x, 1)
x_1
julia> GraphPPL.proxy_args(:(y = x))
:(y = GraphPPL.proxylabel(:x, nothing, x))
```
"""
function proxy_args end

function proxy_args(arg)
    if @capture(arg, lhs_ = rhs_)
        return proxy_args(lhs, rhs)
    elseif @capture(arg, [args__])
        return Expr(:vect, map(proxy_args, args)...)
    elseif @capture(arg, (args__,))
        return Expr(:tuple, map(proxy_args, args)...)
    elseif @capture(arg, GraphPPL.MixedArguments(first_, second_))
        return :(GraphPPL.MixedArguments($(proxy_args(first)), $(proxy_args(second))))
    end
    return arg
end

function proxy_args(lhs, rhs)
    @assert isa(lhs, Symbol) "Cannot wrap a ProxyLabel of `$lhs = $rhs` expression. The LHS must be a Symbol."
    if isa(rhs, Symbol)
        return :($lhs = GraphPPL.proxylabel($(QuoteNode(rhs)), nothing, $rhs))
    elseif @capture(rhs, rlabel_[index__])
        return :($lhs = GraphPPL.proxylabel($(QuoteNode(rlabel)), $(Expr(:tuple, index...)), $rlabel))
    end
    return :($lhs = $rhs)
end

"""
    combine_args(args::Vector, kwargs::Nothing)

Combines a vector of arguments into a single expression.

# Arguments
- `args::Vector`: The vector of arguments.
- `kwargs::Nothing`: The keyword arguments. This argument is always `nothing`.

# Returns
An `Expr` with the combined arguments.
"""
combine_args(args::Vector, kwargs::Nothing) = Expr(:vect, args...)

"""
    combine_args(args::Vector, kwargs::Vector)

Combines a vector of arguments and a vector of keyword arguments into a single expression.

# Arguments
- `args::Vector`: The vector of arguments.
- `kwargs::Vector`: The vector of keyword arguments.

# Returns
An `Expr` with the combined arguments and keyword arguments.
"""
combine_args(args::Vector, kwargs::Vector) =
    length(args) == 0 ? keyword_expressions_to_named_tuple(kwargs) : :(GraphPPL.MixedArguments($(Expr(:vect, args...)), $(keyword_expressions_to_named_tuple(kwargs))))

"""
    combine_args(args::Nothing, kwargs::Nothing)

Returns `nothing`.

# Arguments
- `args::Nothing`: The arguments. This argument is always `nothing`.
- `kwargs::Nothing`: The keyword arguments. This argument is always `nothing`.
"""
combine_args(args::Nothing, kwargs::Nothing) = nothing

function combine_broadcast_args(args::Vector, kwargs::Nothing)
    invars = MacroTools.gensym_ids.(gensym.(args))
    return invars, Expr(:vect, invars...)
end

function combine_broadcast_args(args::Vector, kwargs::Vector)
    kwargs_keys = [arg.args[1] for arg in kwargs]
    kwargs_values = [arg.args[2] for arg in kwargs]
    invars_kwargs = MacroTools.gensym_ids.(gensym.(kwargs_values))
    kwargs_tuple = Expr(:tuple, [Expr(:(=), key, val) for (key, val) in zip(kwargs_keys, invars_kwargs)]...)
    if length(args) == 0
        return invars_kwargs, kwargs_tuple
    else
        invars_args = MacroTools.gensym_ids.(gensym.(args))
        return vcat(invars_args, invars_kwargs), :(GraphPPL.MixedArguments($(Expr(:vect, invars_args...)), $kwargs_tuple))
    end
end

combine_broadcast_args(args::Nothing, kwargs::Nothing) = nothing

generate_lhs_proxylabel(var, index::Nothing) = quote
    GraphPPL.proxylabel($(QuoteNode(var)), nothing, $var)
end
generate_lhs_proxylabel(var, index::AbstractArray) = quote
    GraphPPL.proxylabel($(QuoteNode(var)), $(Expr(:tuple, index...)), $var)
end

"""
    convert_tilde_expression(e::Expr)

Converts a tilde expression to a `make_node!` call. Converts broadcasted tile expressions to `make_node!` calls with nothing as the lhs to indicate that a variable should be created on every broadcasted pass.

# Arguments
- `e::Expr`: The expression to convert.

# Returns
- `Expr`: The converted expression.

# Examples

```julia
julia> convert_tilde_expression(:(x ~ Normal(0, 1) where {created_by = (x~Normal(0,1))}))
quote
    GraphPPL.make_node!(__model__, __context__, Normal, x, [0, 1]; options = $(Dict{Any,Any}(:created_by => :(x ~ Normal(0, 1)))), debug = debug)
end
```
"""
function convert_tilde_expression(e::Expr)
    if @capture(e, (lhs_ ~ fform_(args__; kwargs__) where {options__}) | (lhs_ ~ fform_(args__) where {options__}) | (lhs_ ~ fform_ where {options__}))
        args = GraphPPL.proxy_args(combine_args(args, kwargs))
        options = GraphPPL.options_vector_to_named_tuple(options)
        @capture(lhs, (var_[index__]) | (var_)) || error("Invalid left-hand side $(lhs). Must be in a `var` or `var[index]` form.")
        return quote
            $lhs = GraphPPL.make_node!(
                __model__,
                __context__,
                GraphPPL.NodeCreationOptions($(options)),
                $fform,
                $(generate_lhs_proxylabel(var, index)),
                $args
            )
        end
    elseif @capture(e, (lhs_ .~ fform_(args__; kwargs__) where {options__}) | (lhs_ .~ fform_(args__) where {options__}))
        (broadcasted_names, parsed_args) = combine_broadcast_args(args, kwargs)
        options = GraphPPL.options_vector_to_named_tuple(options)
        broadcastable_variables = kwargs === nothing ? args : vcat(args, [kwarg.args[2] for kwarg in kwargs])
        @capture(lhs, (var_[index__]) | (var_)) || error("Invalid left-hand side $(lhs). Must be in a `var` or `var[index]` form.")
        return quote
            $lhs = broadcast($(broadcastable_variables...)) do $(broadcasted_names...)
                return GraphPPL.make_node!(
                    __model__,
                    __context__,
                    GraphPPL.NodeCreationOptions($(options)),
                    $fform,
                    GraphPPL.Broadcasted($(QuoteNode(var))),
                    $parsed_args
                )
            end
            $lhs = GraphPPL.ResizableArray($lhs)
            __context__[$(QuoteNode(lhs))] = $lhs
        end
    else
        return e
    end
end

what_walk(::typeof(convert_tilde_expression)) = guarded_walk((x) -> (x isa Expr && x.args[1] == :created_by))

"""
    options_vector_to_named_tuple(options::AbstractArray)

Converts the array found by pattern matching on the where clause in a tilde expression into a named tuple.

# Arguments
- `options::AbstractArray`: An array of options.

# Returns
- `result`: A named tuple of options.
"""
function options_vector_to_named_tuple(options::AbstractArray)
    parameters = Expr(:parameters)
    parameters.args = map(options) do option 
        @capture(option, lhs_ = rhs_) || error("Invalid option $(option). Must be in a `lhs = rhs` form.")
        return Expr(:kw, lhs, rhs)
    end
    return Expr(:tuple, parameters)
end

"""
    get_boilerplate_functions(ms_name, ms_args, num_interfaces)

Returns a quote block containing boilerplate functions for a model macro.

# Arguments
- `ms_name`: The name of the model macro.
- `ms_args`: The arguments of the model macro.
- `num_interfaces`: The number of interfaces of the model macro.

# Returns
- `quote`: A quote block containing the boilerplate functions for the model macro.
"""
function get_boilerplate_functions(ms_name, ms_args, num_interfaces)
    error_msg = "$(ms_name) Composite node cannot be invoked with"
    ms_args = map(arg -> preprocess_interface_expression(arg), ms_args)
    return quote
        function $ms_name end
        GraphPPL.interfaces(::typeof($ms_name), val) = error($error_msg * " $val keywords")
        GraphPPL.interfaces(::typeof($ms_name), ::GraphPPL.StaticInt{$num_interfaces}) = GraphPPL.StaticInterfaces(Tuple($ms_args))
        GraphPPL.NodeType(::typeof($ms_name)) = GraphPPL.Composite()
        GraphPPL.NodeBehaviour(::typeof($ms_name)) = GraphPPL.Stochastic()
    end
end

preprocess_interface_expression(arg::Symbol; warn = true) = arg
function preprocess_interface_expression(arg::Expr; warn = true)
    if arg.head == :(::)
        if warn
            @warn "Type annotation found in interface $(prettify(arg)). While this will check that $(arg.args[1]) is an $(arg.args[2]), dynamic creation of submodels using multiple dispatch is not supported."
        end
        return arg.args[1]
    else
        error("Encountered expression in interface $(prettify(arg))")
    end
end

function get_make_node_function(ms_body, ms_args, ms_name)
    # TODO (bvdmitri): prettify
    init_input_arguments = map(ms_args) do arg
        arg_name = preprocess_interface_expression(arg; warn = false)
        error_msg = "Missing interface $(arg)"
        return quote
            if !haskey(__interfaces__, $(QuoteNode(arg_name)))
                error($error_msg)
            end
            $arg = __interfaces__[$(QuoteNode(arg_name))]
        end
    end
    make_node_function = quote
        function GraphPPL.make_node!(
            ::GraphPPL.Composite,
            __model__::GraphPPL.Model,
            __parent_context__::GraphPPL.Context,
            __options__::GraphPPL.NodeCreationOptions,
            ::typeof($ms_name),
            __lhs_interface__::GraphPPL.ProxyLabel,
            __rhs_interfaces__::NamedTuple,
            __n_interfaces__::GraphPPL.StaticInt{$(length(ms_args))}
        )
            __interfaces__ = GraphPPL.prepare_interfaces($ms_name, __lhs_interface__, __rhs_interfaces__)
            __context__ = GraphPPL.Context(__parent_context__, $ms_name)
            GraphPPL.copy_markov_blanket_to_child_context(__context__, __interfaces__)
            GraphPPL.add_composite_factor_node!(__model__, __parent_context__, __context__, $ms_name)
            GraphPPL.add_terminated_submodel!(__model__, __context__, __options__, $ms_name, __interfaces__, __n_interfaces__)
            return GraphPPL.unroll(__lhs_interface__)
        end

        function GraphPPL.add_terminated_submodel!(
            __model__::GraphPPL.Model,
            __context__::GraphPPL.Context,
            __options__::GraphPPL.NodeCreationOptions,
            ::typeof($ms_name),
            __interfaces__::NamedTuple,
            ::GraphPPL.StaticInt{$(length(ms_args))}
        )
            $(init_input_arguments...)
            $ms_body
        end
    end
    return make_node_function
end

function model_macro_interior(model_specification)
    @capture(model_specification, (function ms_name_(ms_args__; ms_kwargs__)
        ms_body_
    end) | (function ms_name_(ms_args__)
        ms_body_
    end)) || error("Model specification language requires full function definition")

    num_interfaces = Base.length(ms_args)
    if !isnothing(ms_kwargs) && length(ms_kwargs) > 0
        warn("Model specification language does not support keyword arguments. Ignoring $(length(ms_kwargs)) keyword arguments.")
    end
    boilerplate_functions = GraphPPL.get_boilerplate_functions(ms_name, ms_args, num_interfaces)

    ms_body = apply_pipeline(ms_body, check_reserved_variable_names_model)
    ms_body = apply_pipeline(ms_body, warn_datavar_constvar_randomvar)
    ms_body = apply_pipeline(ms_body, save_expression_in_tilde)
    ms_body = apply_pipeline(ms_body, convert_deterministic_statement)
    ms_body = apply_pipeline(ms_body, convert_local_statement)
    ms_body = apply_pipeline(ms_body, convert_to_kwargs_expression)
    ms_body = apply_pipeline(ms_body, add_get_or_create_expression)
    ms_body = apply_pipeline(ms_body, convert_anonymous_variables)
    ms_body = apply_pipeline(ms_body, replace_begin_end)
    ms_body = apply_pipeline(ms_body, convert_tilde_expression)
    make_node_function = get_make_node_function(ms_body, ms_args, ms_name)
    result = quote
        $boilerplate_functions
        $make_node_function
        nothing
    end
    return result
end

macro model(model_specification)
    return esc(GraphPPL.model_macro_interior(model_specification))
end
