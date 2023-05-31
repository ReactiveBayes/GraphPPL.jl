export @model
import MacroTools: postwalk, @capture, walk



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

function check_reserved_variable_names(e::Expr)
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
        ],
    )
        error("Variable name in $(prettify(e)) is reserved.")
    end
    return e
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

function save_expression_in_tilde(e::Expr)
    if @capture(e, (local lhs_ ~ rhs_ where {options__}) | (local lhs_ ~ rhs_))
        options = options === nothing ? [] : options
        return :(local $lhs ~ $rhs where {$(options...),created_by=$(prettify(e))})
    elseif @capture(e, (local lhs_ .~ rhs_ where {options__}) | (local lhs_ .~ rhs_))
        options = options === nothing ? [] : options
        return :(local $lhs .~ $rhs where {$(options...),created_by=$(prettify(e))})
    elseif @capture(e, (local lhs_ := rhs_ where {options__}) | (local lhs_ := rhs_))
        options = options === nothing ? [] : options
        return :(local $lhs := $rhs where {$(options...),created_by=$(prettify(e))})
    elseif @capture(e, (lhs_ ~ rhs_ where {options__}) | (lhs_ ~ rhs_))
        options = options === nothing ? [] : options
        return :($lhs ~ $rhs where {$(options...),created_by=$(prettify(e))})
    elseif @capture(e, (lhs_ .~ rhs_ where {options__}) | (lhs_ .~ rhs_))
        options = options === nothing ? [] : options
        return :($lhs .~ $rhs where {$(options...),created_by=$(prettify(e))})
    elseif @capture(e, (lhs_ := rhs_ where {options__}) | (lhs_ := rhs_))
        options = options === nothing ? [] : options
        return :($lhs := $rhs where {$(options...),created_by=$(prettify(e))})
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

what_walk(::typeof(convert_deterministic_statement)) =
    walk_until_occurrence(:(lhs_ := rhs_ where {options__}))

function convert_local_statement(e::Expr)
    if @capture(e, (local lhs_ ~ rhs_ where {options__}))
        return quote
            $lhs = GraphPPL.add_variable_node!(
                __model__,
                __context__,
                gensym(__model__, $(QuoteNode(lhs))),
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
        sym = MacroTools.gensym_ids(gensym(:tmp))
        return quote
            begin
                $sym ~ $f($(args...)) where {anonymous=true,created_by=$created_by}
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
    if @capture(e, (lhs_ ~ rhs_ where {options__}))
        @capture(lhs, (var_[index__]) | (var_))
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
        $s =
            !@isdefined($s) ?
            GraphPPL.getorcreate!(__model__, __context__, $(QuoteNode(s)), nothing) :
            (
                GraphPPL.check_variate_compatability($s, nothing) ? $s :
                GraphPPL.getorcreate!(__model__, __context__, $(QuoteNode(s)), nothing)
            )
    end
end


function generate_get_or_create(s::Symbol, lhs::Expr, index::AbstractArray)
    return quote
        $s =
            !@isdefined($s) ?
            GraphPPL.getorcreate!(__model__, __context__, $(QuoteNode(s)), $(index...)) :
            (
                GraphPPL.check_variate_compatability($s, $(index...)) ? $s :
                GraphPPL.getorcreate!(__model__, __context__, $(QuoteNode(s)), $(index...))
            )
    end
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
    result = [Expr(:(=), arg.args[1], arg.args[2]) for arg in keywords]
    return Expr(:tuple, result...)
end

combine_args(args::Vector, kwargs::Nothing) =
    length(args) == 0 ? :nothing : Expr(:vect, args...)
combine_args(args::Vector, kwargs::Vector) =
    length(args) == 0 ? keyword_expressions_to_named_tuple(kwargs) :
    :(GraphPPL.MixedArguments(
        $(Expr(:vect, args...)),
        $(keyword_expressions_to_named_tuple(kwargs)),
    ))
combine_args(args::Nothing, kwargs::Nothing) = nothing



"""
    convert_tilde_expression(e::Expr)

Converts a tilde expression to a `make_node!` call.

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
    if @capture(
        e,
        (lhs_ ~ fform_(args__; kwargs__) where {options__}) |
        (lhs_ ~ fform_(args__) where {options__}) |
        (lhs_ ~ fform_ where {options__})
    )
        args = combine_args(args, kwargs)
        options = GraphPPL.options_vector_to_dict(options)
        return quote
            $lhs = GraphPPL.make_node!(
                __model__,
                __context__,
                $fform,
                $lhs,
                $args;
                __parent_options__ = GraphPPL.prepare_options(
                    __parent_options__,
                    $(options),
                    __debug__,
                ),
                __debug__ = __debug__,
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
    result = Dict{Any, Any}()
    for option in options
        if option.head != :(=)
            error("Invalid option $(option)")
        end
        result[option.args[1]] = option.args[2]
    end
    return result
end

function remove_debug_options!(options::Dict)
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
        return remove_debug_options!(deepcopy(node_options))
    else
        return node_options
    end
end

function prepare_options(parent_options::Dict, node_options::Dict, debug::Bool)
    result = merge(parent_options, node_options)
    if !debug
        return remove_debug_options!(deepcopy(result))
    else
        return result
    end
end

function get_boilerplate_functions(ms_name, ms_args, num_interfaces)
    error_msg = "$(ms_name) Composite node cannot be invoked with"
    return quote
        function $ms_name end
        GraphPPL.interfaces(::typeof($ms_name), val) = error($error_msg * " $val keywords")
        GraphPPL.interfaces(::typeof($ms_name), ::Val{$num_interfaces}) = Tuple($ms_args)
        GraphPPL.NodeType(::typeof($ms_name)) = GraphPPL.Composite()
        GraphPPL.NodeBehaviour(::typeof($ms_name)) = GraphPPL.Stochastic()
    end
end


function get_make_node_function(ms_body, ms_args, ms_name)
    # TODO (bvdmitri): prettify
    init_input_arguments = map(ms_args) do arg
        error_msg = "Missing interface $(arg)"
        return quote
            if !haskey(__interfaces__, $(QuoteNode(arg)))
                error($error_msg)
            end
            $arg = __interfaces__[$(QuoteNode(arg))]
        end
    end
    make_node_function = quote
        function GraphPPL.make_node!(
            ::GraphPPL.Composite,
            __model__::GraphPPL.Model,
            __parent_context__::GraphPPL.Context,
            ::typeof($ms_name),
            __lhs_interface__::GraphPPL.NodeLabel,
            __rhs_interfaces__::NamedTuple,
            ::Val{$(length(ms_args))};
            __parent_options__ = nothing,
            __debug__ = false,
        )
            __interfaces__ = GraphPPL.prepare_interfaces(
                $ms_name,
                __lhs_interface__,
                __rhs_interfaces__,
            )
            $(init_input_arguments...)
            __context__ = GraphPPL.Context(__parent_context__, $ms_name)
            GraphPPL.copy_markov_blanket_to_child_context(__context__, __interfaces__)
            GraphPPL.add_composite_factor_node!(
                __model__,
                __parent_context__,
                __context__,
                $ms_name,
            )
            __parent_options__ =
                __parent_options__ == nothing ? nothing :
                Dict{Any, Any}("parent_options" => __parent_options__)

            $ms_body
            return __lhs_interface__
        end
    end
    return make_node_function
end


function model_macro_interior(__model___specification)
    @capture(
        __model___specification,
        (function ms_name_(ms_args__; ms_kwargs__)
            ms_body_
        end) | (function ms_name_(ms_args__)
            ms_body_
        end)
    ) || error("__model__ specification language requires full function definition")

    ms_args = extract_interfaces(ms_args, ms_body)
    num_interfaces = Base.length(ms_args)
    boilerplate_functions =
        GraphPPL.get_boilerplate_functions(ms_name, ms_args, num_interfaces)

    ms_body = apply_pipeline(ms_body, check_reserved_variable_names)
    ms_body = apply_pipeline(ms_body, warn_datavar_constvar_randomvar)
    ms_body = apply_pipeline(ms_body, save_expression_in_tilde)
    ms_body = apply_pipeline(ms_body, convert_deterministic_statement)
    ms_body = apply_pipeline(ms_body, convert_local_statement)
    ms_body = apply_pipeline(ms_body, convert_to_kwargs_expression)
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
