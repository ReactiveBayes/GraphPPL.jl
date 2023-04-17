export @new_model, @test_expression_generating
import MacroTools: postwalk, @capture, walk

__guard_f(f, e::Expr) = f(e)
__guard_f(f, x) = x
  

macro test_expression_generating(lhs, rhs)
    return esc(quote
        @test prettify($lhs) == prettify($rhs)
    end)
end

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

function (w::walk_until_occurrence{E})(f, x) where { E <: Tuple }
    return walk(x, z -> any(pattern -> @capture(x, $(pattern)), w.patterns) ? z : w(f, z), f)
end

function (w::walk_until_occurrence{E})(f, x) where { E <: Expr }
    return walk(x, z -> @capture(x, $(w.patterns)) ? z : w(f, z), f)
end


what_walk(::Function) = postwalk
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

what_walk(::typeof(save_expression_in_tilde)) = walk_until_occurrence((:(lhs_ ~ rhs_), :(local lhs_ ~ rhs_), :(lhs_ .~ rhs_), :(local lhs_ .~ rhs_), :(lhs_ := rhs_), :(local lhs_ := rhs_)))

function get_created_by(options::AbstractArray)
    for option in options
        if @capture(option, (name_ = expr_))
            if name == :created_by
                return expr
            end
        end
    end
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
            $lhs = GraphPPL.add_variable_node!(model, context, gensym($(QuoteNode(lhs))))
            $lhs ~ $rhs where {$(options...)}
        end
    else
        return e
    end
end

function convert_to_kwargs_expression(e::Expr)
    if @capture(e, (lhs_ ~ f_(args__) where {options__}))
        if is_kwargs_expression(args)
            return :($lhs ~ $f(; $(args...)) where {$(options...)})
        else
            return e
        end
    elseif @capture(e, (lhs_ .~ f_(args__) where {options__}))
        if is_kwargs_expression(args)
            return :($lhs .~ $f(; $(args...)) where {$(options...)})
        else
            return e
        end
    elseif @capture(e, (lhs_ := f_(args__) where {options__}))
        if is_kwargs_expression(args)
            return :($lhs := $f(; $(args...)) where {$(options...)})
        else
            return e
        end
    else
        return e
    end
end

function convert_indexed_statement(e::Expr)
    if @capture(e, (lhs_ ~ rhs_ where {options__}))
        if @capture(lhs, var_[index__])
            return quote
                $var =
                    @isdefined($var) ? $var :
                    GraphPPL.getorcreate!(model, context, $(QuoteNode(var)), $(index...))
                $e
            end
        end
    end
    return e
end

function convert_to_anonymous(e::Expr, created_by)
    if @capture(e, f_(args__))
        sym = gensym(:tmp)
        return quote
            begin
                $sym ~ $f($(args...)) where {anonymous=true, created_by=$created_by}
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
            nargs[i] = postwalk(narg) do argument
                convert_to_anonymous(argument, created_by)
            end
        end
        return :($lhs ~ $fform($(nargs...)) where {$(options...)})
    end
    return e
end

what_walk(::typeof(convert_function_argument_in_rhs)) = walk_until_occurrence(:(lhs_ ~ rhs_ where {options__}))

function add_get_or_create_expression(e::Expr)
    if @capture(e, (lhs_ ~ rhs_ where {options__}))
        if @capture(lhs, var_[index__])
            return quote
                $(generate_get_or_create(var, index))
                $e
            end
        else
            return quote
                $(generate_get_or_create(lhs))
                $e
            end
        end
    end
    return e
end

function generate_get_or_create(s::Symbol)
    return :(
        $s = @isdefined($s) ? $s : GraphPPL.getorcreate!(model, context, $(QuoteNode(s)))
    )
end


function generate_get_or_create(s::Symbol, index::Union{Tuple, AbstractArray, Int})
    return :(GraphPPL.getorcreate!(model, context, $(QuoteNode(s)), $(index...)))
end

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

what_walk(::typeof(convert_arithmetic_operations)) =
    guarded_walk((x) -> (x isa Expr && x.head == :ref))

function interfaces end

function missing_interfaces(node_type, val::Val, known_interfaces)
    all_interfaces = GraphPPL.interfaces(node_type, val)
    missing_interfaces = Base.setdiff(all_interfaces, keys(known_interfaces))
    return missing_interfaces
end

function __convert_tilde_expression(lhs, fform, rhs::AbstractArray)
    interfaces = (in = Expr(:tuple, rhs...), out = lhs)
    return GraphPPL.generate_make_node_call(fform, interfaces)
end

function __convert_tilde_expression(lhs, fform, rhs::NamedTuple, val::Val)
    missing_interface = GraphPPL.missing_interfaces(getfield(Main, fform), val, rhs)[1]
    interfaces = NamedTuple{(keys(rhs)..., missing_interface)}((values(rhs)..., lhs))
    return GraphPPL.generate_make_node_call(fform, interfaces)
end

function convert_tilde_expression(e::Expr)
    if @capture(e, (lhs_ ~ fform_(; args__) where {options__}))
        args = GraphPPL.keyword_expressions_to_named_tuple(args)
        return GraphPPL.__convert_tilde_expression(lhs, fform, args, Val(length(args) + 1))
    elseif @capture(e, (lhs_ ~ fform_(args__) where {options__}))
        return GraphPPL.__convert_tilde_expression(lhs, fform, args)
    else
        return e
    end
end


convert_interfaces_tuple(name::Symbol, interface) =
    :($name = GraphPPL.getifcreated(model, context, $interface))

function convert_interfaces_tuple(field::Symbol, interfaces::NamedTuple)
    values = map(iterator(interfaces)) do (name, interface)
        return convert_interfaces_tuple(name, interface)
    end
    return :($field = ($(values...),)) #($(values...),) syntax is used here, which creates a NamedTuple (hence the ,) out of (the Vector of Expr objects) values
end

function generate_make_node_call(fform, interfaces::NamedTuple)
    interfaces_tuple = map(iterator(interfaces)) do (name, interface)
        return convert_interfaces_tuple(name, interface)
    end
    if length(interfaces_tuple) == 0
        interfaces_tuple = NamedTuple()
    end
    result = quote
        interfaces_tuple = ($(interfaces_tuple...),)
        GraphPPL.make_node!(model, context, $fform, interfaces_tuple)
    end
    return result
end

function keyword_expressions_to_named_tuple(keywords::Vector)
    keys = [expr.args[1] for expr in keywords]
    values = [expr.args[2] for expr in keywords]
    return (; zip(keys, values)...)
end

function is_kwargs_expression(e::Expr)
    return e.head == :kw
end

function is_kwargs_expression(e::Vector)
    if length(e) > 0
        return sum([is_kwargs_expression(elem) for elem in e]) == length(e)
    else
        return false
    end
end

is_kwargs_expression(e) = false


function get_boilerplate_functions(ms_name, ms_args, num_interfaces)
    return quote
        function $ms_name end
        GraphPPL.interfaces(::typeof($ms_name), ::Val{$num_interfaces}) = Tuple($ms_args)
        GraphPPL.NodeType(::typeof($ms_name)) = GraphPPL.Composite()
        function $ms_name()
            model = GraphPPL.create_model()
            arguments = []
            for argument in $ms_args
                argument = GraphPPL.getorcreate!(model, argument)
                push!(arguments, argument)
            end
            args = (; zip($ms_args, arguments)...)
            GraphPPL.make_node!(model, GraphPPL.context(model), $ms_name, args)
            return model
        end
    end
end

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



macro new_model(model_specification)
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
    ms_body = apply_pipeline(ms_body, convert_indexed_statement)
    ms_body = apply_pipeline(ms_body, convert_function_argument_in_rhs)
    ms_body = apply_pipeline(ms_body, add_get_or_create_expression)
    ms_body = apply_pipeline(ms_body, convert_tilde_expression)

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
            interfaces,
        )
            $(init_input_arguments...)
            context = GraphPPL.Context(parent_context, $ms_name)
            GraphPPL.copy_markov_blanket_to_child_context(context, interfaces)
            $ms_body
            node_id = GraphPPL.gensym(model, $ms_name)
            GraphPPL.add_composite_factor_node!(model, context, parent_context, $ms_name)
        end
    end

    result = quote

        $boilerplate_functions
        $make_node_function

        nothing
    end
    return esc(result)


end
