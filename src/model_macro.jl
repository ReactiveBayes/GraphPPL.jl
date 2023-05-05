export @model, @test_expression_generating
import MacroTools: postwalk, @capture, walk

macro test_expression_generating(lhs, rhs)
    return esc(quote
        @test prettify($lhs) == prettify($rhs)
    end)
end

__guard_f(f, e::Expr) = f(e)
__guard_f(f, x) = x

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

function warn_datavar_constvar_randomvar(e::Expr)
    if @capture(
        e,
        ((lhs_ = datavar(args__)) | (lhs_ = constvar(args__)) | (lhs_ = randomvar(args__)))
    )
        @warn "datavar, constvar and randomvar syntax are deprecated and will not be supported in the future. Please use the tilde syntax instead."
        return
    end
    return e
end

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

function (w::walk_until_occurrence{E})(f, x) where {E<:Tuple}
    return walk(
        x,
        z -> any(pattern -> @capture(x, $(pattern)), w.patterns) ? z : w(f, z),
        f,
    )
end

function (w::walk_until_occurrence{E})(f, x) where {E<:Expr}
    return walk(x, z -> @capture(x, $(w.patterns)) ? z : w(f, z), f)
end


what_walk(anything) = postwalk


function save_expression_in_tilde(e::Expr)
    if @capture(e, (local lhs_ ~ rhs_ where {options__}) | (local lhs_ ~ rhs_))
        options = options === nothing ? [] : options
        return :(local $lhs ~ $rhs where {$(options...),created_by=$e})
    elseif @capture(e, (local lhs_ .~ rhs_ where {options__}) | (local lhs_ .~ rhs_))
        options = options === nothing ? [] : options
        return :(local $lhs .~ $rhs where {$(options...),created_by=$e})
    elseif @capture(e, (local lhs_ := rhs_ where {options__}) | (local lhs_ := rhs_))
        options = options === nothing ? [] : options
        return :(local $lhs := $rhs where {$(options...),created_by=$e})
    elseif @capture(e, (lhs_ ~ rhs_ where {options__}) | (lhs_ ~ rhs_))
        options = options === nothing ? [] : options
        return :($lhs ~ $rhs where {$(options...),created_by=$e})
    elseif @capture(e, (lhs_ .~ rhs_ where {options__}) | (lhs_ .~ rhs_))
        options = options === nothing ? [] : options
        return :($lhs .~ $rhs where {$(options...),created_by=$e})
    elseif @capture(e, (lhs_ := rhs_ where {options__}) | (lhs_ := rhs_))
        options = options === nothing ? [] : options
        return :($lhs := $rhs where {$(options...),created_by=$e})
    else
        return e
    end
end

what_walk(::typeof(save_expression_in_tilde)) = walk_until_occurrence((
    :(lhs_ ~ rhs_),
    :(local lhs_ ~ rhs_),
    :(lhs_ .~ rhs_),
    :(local lhs_ .~ rhs_),
    :(lhs_ := rhs_),
    :(local lhs_ := rhs_),
))

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

function convert_deterministic_statement(e::Expr)
    if @capture(e, (lhs_ := rhs_ where {options__}))
        return :($lhs ~ $rhs where {$(options...),is_deterministic=true})
    else
        return e
    end
end

function convert_local_statement(e::Expr)
    if @capture(e, (local lhs_ ~ rhs_ where {options__}))
        return quote
            $lhs = GraphPPL.add_variable_node!(
                model,
                context,
                gensym(model, $(QuoteNode(lhs))),
            )
            $lhs ~ $rhs where {$(options...)}
        end
    else
        return e
    end
end

function is_kwargs_expression(e::Expr)
    return e.head == :kw || e.head == :parameters
end


function is_kwargs_expression(e::Vector)
    if length(e) > 0
        return sum([is_kwargs_expression(elem) for elem in e]) == length(e)
    else
        return false
    end
end

is_kwargs_expression(e) = false

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

what_walk(::typeof(convert_to_kwargs_expression)) =
    guarded_walk((x) -> (x isa Expr && x.args[1] == :created_by))

function convert_to_anonymous(e::Expr, created_by)
    if @capture(e, f_(args__))
        sym = gensym(:tmp)
        return quote
            begin
                $sym ~ $f($(args...)) where {anonymous=true,created_by=$created_by}
                $sym
            end
        end
    end
    return e
end

convert_to_anonymous(e, created_by) = e

function convert_function_argument_in_rhs(e::Expr)
    if @capture(e, (lhs_ ~ fform_(nargs__) where {options__}))
        created_by = get_created_by(options)
        for (i, narg) in enumerate(nargs)
            nargs[i] = GraphPPL.not_enter_indexed_walk(narg) do argument
                convert_to_anonymous(argument, created_by)
            end
        end
        return :($lhs ~ $fform($(nargs...)) where {$(options...)})
    end
    return e
end

what_walk(::typeof(convert_function_argument_in_rhs)) =
    walk_until_occurrence(:(lhs_ ~ rhs_ where {options__}))

function add_get_or_create_expression(e::Expr)
    if @capture(e, (lhs_ ~ fform_(args__) where {options__}))
        @capture(lhs, (var_[index__])| (var_))
        return quote
            $(generate_get_or_create(var, lhs, index))
            $e
        end
    end
    return e
end

what_walk(::typeof(add_get_or_create_expression)) =
    guarded_walk((x) -> (x isa Expr && x.args[1] == :created_by))

function generate_get_or_create(s::Symbol, lhs::Symbol, index::Nothing)
    return quote
        $s = !@isdefined($s) ? GraphPPL.getorcreate!(model, context, $(QuoteNode(s)), nothing) :
        (
            GraphPPL.check_variate_compatability($s, $(QuoteNode(lhs))) ? $s :
            GraphPPL.getorcreate!(model, context, $(QuoteNode(s)), nothing)
        )
    end
end


function generate_get_or_create(s::Symbol, lhs::Expr, index::AbstractArray)
    return quote
        $s = !@isdefined($s) ? GraphPPL.getorcreate!(model, context, $(QuoteNode(s)), $(index...)) :
        (
            GraphPPL.check_variate_compatability($s, $(QuoteNode(lhs))) ? $s :
            GraphPPL.getorcreate!(model, context, $(QuoteNode(s)), $(index...))
        )
    end
end

"""
    convert_arithmetic_operations(e::Expr)

Converts all arithmetic operations to a function call. For example, `x * y` is converted to `prod(x, y)`.
"""
function convert_arithmetic_operations(e::Expr)
    if e.head == :call && e.args[1] == :*
        return :(prod($(e.args[2:end]...)))
    elseif e.head == :call && e.args[1] == :/
        return :(div($(e.args[2:end]...)))
    elseif e.head == :call && e.args[1] == :+
        return :(sum($(e.args[2:end]...)))
    elseif e.head == :call && e.args[1] == :-
        return :(sub($(e.args[2:end]...)))
    else
        return e
    end
end

"""
    what_walk(::typeof(convert_arithmetic_operations))

Guarded walk that makes sure that the arithmetic operations are never converted in indexed expressions (e.g. x[i + 1] is not converted to x[sum(i, 1)]. Any expressions in the `where` clause are also not converted.
"""
what_walk(::typeof(convert_arithmetic_operations)) = guarded_walk(
    (x) -> ((x isa Expr && x.head == :ref)) || (x isa Expr && x.head == :where),
)

"""
Placeholder function that is defined for all Composite nodes and is invoked when inferring what interfaces are missing when a node is called
"""
function interfaces end

"""
    missing_interfaces(node_type, val, known_interfaces)

Returns the interfaces that are missing for a node. This is used when inferring the interfaces for a node that is composite.

# Arguments
- `node_type`: The type of the node as a Function object.
- `val`: The value of the amount of interfaces the node is supposed to have. This is a `Val` object.
- `known_interfaces`: The known interfaces for the node.

# Returns
- `missing_interfaces`: A `Vector` of the missing interfaces.
"""
function missing_interfaces(node_type, val::Val, known_interfaces)
    all_interfaces = GraphPPL.interfaces(node_type, val)
    missing_interfaces = Base.setdiff(all_interfaces, keys(known_interfaces))
    return missing_interfaces
end

"""
    prepare_interfaces(lhs, fform, rhs)

Generate the NamedTuple of interfaces for a node. Calls `missing_interfaces` if the node is composite and infers 
    the missing interface from the number of arguments and the known interfaces.

# Arguments
- `lhs`: The left-hand side of the node. This can be either a symbol (e.g. `:x`) or an expression (e.g. `:(x[1])`).
- `fform`: The node type, the object representing the node "function".
- `rhs`: The right-hand side of the node. This can be either a `NamedTuple` (in case of named arguments) or an `AbstractArray` (in case of unnamed arguments).

# Returns
- `NamedTuple`: The NamedTuple of interfaces for the node.
"""
function prepare_interfaces(
    ::GraphPPL.Atomic,
    lhs::Union{Symbol,Expr},
    fform,
    rhs::NamedTuple,
)
    return (rhs..., out = lhs)
end

function prepare_interfaces(
    ::GraphPPL.Composite,
    lhs::Union{Symbol,Expr},
    fform,
    rhs::NamedTuple,
)
    missing_interface = GraphPPL.missing_interfaces(fform, Val(length(rhs) + 1), rhs)[1]
    return NamedTuple{(keys(rhs)..., missing_interface)}((values(rhs)..., lhs))
end

function prepare_interfaces(
    ::GraphPPL.Atomic,
    lhs::Union{Symbol,Expr},
    fform,
    rhs::AbstractArray,
)
    return (in = Expr(:tuple, rhs...), out = lhs)
end

function prepare_interfaces(
    ::GraphPPL.Composite,
    lhs::Union{Symbol,Expr},
    fform,
    rhs::AbstractArray,
)
    error("Composite nodes can only be invoked with keyword arguments.")
end

prepare_interfaces(lhs::Union{Symbol,Expr}, fform, rhs) =
    prepare_interfaces(GraphPPL.NodeType(fform), lhs, fform, rhs)

"""
    convert_interfaces_tuple(field::Symbol, interfaces)

Converts the `interfaces` to a NamedTuple expression with calls to getifcreated.

# Arguments
- `field::Symbol`: The name of the field.
- `interfaces`: The interfaces.

# Returns
- `Expr`: The NamedTuple expression.

# Example
```julia
julia> convert_interfaces_tuple(:interfaces, :y))
:(interfaces = GraphPPL.getifcreated(model, context, y))
```
ß
"""
convert_interfaces_tuple(name::Symbol, interface) =
    :($name = GraphPPL.getifcreated(model, context, $interface))


"""
    generate_make_node_call(fform, interfaces::NamedTuple)

Generates the expression for calling `make_node!` with the given `fform` and `interfaces`.

# Arguments
- `fform::Function`: The function form.
- `interfaces::NamedTuple`: The interfaces.

# Returns
- `Expr`: The expression for calling `make_node!`.
"""
function generate_make_node_call(fform, interfaces::NamedTuple, options)
    options = options_vector_to_dict(options)
    interfaces_tuple = map(iterator(interfaces)) do (name, interface)
        return convert_interfaces_tuple(name, interface)
    end
    if length(interfaces_tuple) == 0
        interfaces_tuple = NamedTuple()
    end
    result = quote
        interfaces_tuple = ($(interfaces_tuple...),)
        GraphPPL.make_node!(
            model,
            context,
            $fform,
            interfaces_tuple;
            options = GraphPPL.prepare_options(options, $(options), debug),
            debug = debug,
        )
    end
    return result
end

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
    keys = [expr.args[1] for expr in keywords]
    values = [expr.args[2] for expr in keywords]
    return (; zip(keys, values)...)
end

"""
    convert_tilde_expression(e::Expr)

Converts a tilde expression to a `make_node!` call.

# Arguments
- `e::Expr`: The expression to convert.

# Returns
- `Expr`: The converted expression.

# Examples

```julia
julia> convert_tilde_expression(:(x ~ Normal(0, 1)))
quote
    interfaces_tuple = (
        in = GraphPPL.getifcreated(model, context, (0, 1)),
        out = GraphPPL.getifcreated(model, context, x),
    )
    GraphPPL.make_node!(model, context, Normal, interfaces_tuple)
end
```
"""
function convert_tilde_expression(e::Expr)
    if @capture(e, lhs_ ~ fform_(args__) where {options__})
        if @capture(e, (f_ ~ x_(fargs__; kwargs__) where {o__}))
            args = GraphPPL.keyword_expressions_to_named_tuple(kwargs)
            if length(fargs) > 0
                args = (in = Tuple(fargs), args...)
            end
        end
        interfaces = GraphPPL.prepare_interfaces(lhs, getfield(Main, fform), args)
        return GraphPPL.generate_make_node_call(fform, interfaces, options)
    elseif @capture(e, lhs_ ~ rhs_ where {options__})
        options = GraphPPL.options_vector_to_dict(options)
        if @capture(lhs, var_[index__])
            return :(
                $lhs = GraphPPL.make_node_from_object!(
                    model,
                    context,
                    $rhs,
                    $(QuoteNode(var)),
                    GraphPPL.prepare_options(options, $(options), debug),
                    debug,
                    $(index...),
                )
            )
        else
            return :(
                $lhs = GraphPPL.make_node_from_object!(
                    model,
                    context,
                    $rhs,
                    $(QuoteNode(lhs)),
                    GraphPPL.prepare_options(options, $(options), debug),
                    debug,
                )
            )
        end
    else
        return e
    end
end

what_walk(::typeof(convert_tilde_expression)) =
    guarded_walk((x) -> (x isa Expr && x.args[1] == :created_by))




extend(ms_args::AbstractArray, new_interface::Symbol) = vcat(ms_args, new_interface)
extend(ms_args::AbstractArray, new_interface::Expr) = vcat(ms_args, new_interface.args)

function extract_interfaces(ms_args::AbstractArray, ms_body::Expr)
    prewalk(ms_body) do (expression)
        if @capture(expression, return)
            return expression
        elseif @capture(expression, return output_interfaces_)
            ms_args = extend(ms_args, output_interfaces)
            return expression
        else
            return expression
        end
    end
    return ms_args
end

function options_vector_to_dict(options::AbstractArray)
    if length(options) == 0
        return nothing
    end
    result = Dict()
    for option in options
        if option.head != :(=)
            error("Invalid option $(option)")
        end
        result[option.args[1]] = option.args[2]
    end
    return result
end

function remove_debug_options(options::Dict)
    options = delete!(options, :created_by)
    if length(options) == 0
        return nothing
    end
    return options
end


prepare_options(parent_options::Nothing, node_options::Nothing, debug::Bool) = nothing

function prepare_options(parent_options::Dict, node_options::Nothing, debug::Bool)
    return parent_options
end

function prepare_options(parent_options::Nothing, node_options::Dict, debug::Bool)
    if !debug
        return remove_debug_options(node_options)
    else
        return node_options
    end
end

function prepare_options(parent_options::Dict, node_options::Dict, debug::Bool)
    result = merge(parent_options, node_options)
    if !debug
        return remove_debug_options(result)
    else
        return result
    end
end

function get_boilerplate_functions(ms_name, ms_args, num_interfaces)
    return quote
        function $ms_name end
        GraphPPL.interfaces(::typeof($ms_name), ::Val{$num_interfaces}) = Tuple($ms_args)
        GraphPPL.NodeType(::typeof($ms_name)) = GraphPPL.Composite()
        function $ms_name()
            model = GraphPPL.create_model()
            context = GraphPPL.context(model)
            arguments = []
            for argument in $ms_args
                argument = GraphPPL.getorcreate!(model, context, argument)
                push!(arguments, argument)
            end
            args = (; zip($ms_args, arguments)...)
            GraphPPL.make_node!(model, context, $ms_name, args; debug = true)
            return model
        end
    end
end


function get_make_node_function(ms_body, ms_args, ms_name)
    # TODO (bvdmitri): prettify
    init_input_arguments = map(ms_args) do arg
        error_msg = "Missing interface $(arg)"
        return quote
            if !haskey(interfaces, $(QuoteNode(arg)))
                error($error_msg)
            end
            $arg = interfaces[$(QuoteNode(arg))]
        end
    end
    make_node_function = quote
        function GraphPPL.make_node!(
            model,
            ::GraphPPL.Composite,
            parent_context,
            ::typeof($ms_name),
            interfaces;
            options = nothing,
            debug = false,
        )
            $(init_input_arguments...)
            context = GraphPPL.Context(parent_context, $ms_name)
            GraphPPL.copy_markov_blanket_to_child_context(context, interfaces)
            node_name = GraphPPL.add_composite_factor_node!(
                model,
                parent_context,
                context,
                $ms_name,
            )
            options =
                options == nothing ? nothing : Dict(parent_context.prefix => options)

            $ms_body
        end
    end
    return make_node_function
end


function model_macro_interior(model_specification)
    @capture(
        model_specification,
        (function ms_name_(ms_args__; ms_kwargs__)
            ms_body_
        end) | (function ms_name_(ms_args__)
            ms_body_
        end)
    ) || error("Model specification language requires full function definition")

    ms_args = extract_interfaces(ms_args, ms_body)
    num_interfaces = Base.length(ms_args)
    boilerplate_functions =
        GraphPPL.get_boilerplate_functions(ms_name, ms_args, num_interfaces)

    ms_body = apply_pipeline(ms_body, warn_datavar_constvar_randomvar)
    ms_body = apply_pipeline(ms_body, save_expression_in_tilde)
    ms_body = apply_pipeline(ms_body, convert_deterministic_statement)
    ms_body = apply_pipeline(ms_body, convert_local_statement)
    ms_body = apply_pipeline(ms_body, convert_to_kwargs_expression)
    ms_body = apply_pipeline(ms_body, convert_arithmetic_operations)
    ms_body = apply_pipeline(ms_body, convert_function_argument_in_rhs)
    ms_body = apply_pipeline(ms_body, add_get_or_create_expression)
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
