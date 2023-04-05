export @new_model, @test_expression_generating
import MacroTools: postwalk, @capture



macro test_expression_generating(lhs, rhs)
    return esc(quote
        @test prettify($lhs) == prettify($rhs)
    end)
end


function interfaces end

function missing_interfaces(node_type, val::Val, known_interfaces)
    all_interfaces = GraphPPL.interfaces(node_type, val)
    missing_interfaces = Base.setdiff(all_interfaces, keys(known_interfaces))
    return missing_interfaces
end

function generate_get_or_create_expression(variables::Union{AbstractArray,NamedTuple})
    expressions = map(variables) do name
        GraphPPL.generate_get_or_create_expression(name)
    end
    return quote
        $(expressions...)
    end
end

function generate_get_or_create_expression(variables::Expr)
    expressions = map(variables.args) do name
        GraphPPL.generate_get_or_create_expression(name)
    end
    return quote
        $(expressions...)
    end
end

function generate_get_or_create_expression(name::Symbol)
    return quote
        $name =
            (@isdefined($name)) ? $name :
            GraphPPL.getorcreate!(model, context, $(QuoteNode(name)))
    end
end

function convert_tilde_expression(lhs::Symbol, fform, rhs::AbstractArray)
    interfaces = (in = Expr(:tuple, rhs...), out = lhs)
    return generate_make_node_call(fform, interfaces)
end

function convert_tilde_expression(lhs::Symbol, fform, rhs::NamedTuple, val::Val)
    missing_interface = GraphPPL.missing_interfaces(getfield(Main, fform), val, rhs)[1]
    interfaces = NamedTuple{(keys(rhs)..., missing_interface)}((values(rhs)..., lhs))
    return GraphPPL.generate_make_node_call(fform, interfaces)
end

convert_interfaces_tuple(name::Symbol, interface) = :($name = $interface)

function convert_interfaces_tuple(field::Symbol, interfaces::NamedTuple)
    values = map(iterator(interfaces)) do (name, interface)
        return convert_interfaces_tuple(name, interface)
    end
    return :($field = ($(values...),)) #($(values...),) syntax is used here, which creates a NamedTuple (hence the ,) out of (the Vector of Expr objects) values
end

function generate_make_node_call(fform, interfaces::NamedTuple)
    getorcreate_expressions = map(interfaces) do interface
        return GraphPPL.generate_get_or_create_expression(interface)
    end
    interfaces_tuple = map(iterator(interfaces)) do (name, interface)
        return convert_interfaces_tuple(name, interface)
    end
    if length(interfaces_tuple) == 0
        interfaces_tuple = NamedTuple()
    end
    result = quote
        $(getorcreate_expressions...)
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

function is_kwargs_expression(e::Symbol)
    return false
end

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
            GraphPPL.make_node!(model, $ms_name, args)
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

    ms_body = postwalk(ms_body) do expression
        if @capture(expression, (lhs_ := rhs_))
            return :($lhs ~ $rhs)
        else
            return expression
        end
    end

    ms_body = postwalk(ms_body) do expression
        if @capture(expression, (local lhs_ ~ rhs_))
            return quote
                $lhs = GraphPPL.add_variable_node!(model, context, gensym($(QuoteNode(lhs))))
                $lhs ~ $rhs
            end
            return :($lhs ~ $rhs)
        else
            return expression
        end
    end

    ms_body = postwalk(ms_body) do expression
        if @capture(expression, (lhs_ ~ fform_(args__)))
            if is_kwargs_expression(args)
                return :($lhs ~ $fform(; $(args...)))
            else
                return expression
            end
        else
            return expression
        end
    end


    ms_body = postwalk(ms_body) do expression
        if @capture(expression, (lhs_ ~ fform_(; args__)))
            args = GraphPPL.keyword_expressions_to_named_tuple(args)
            return GraphPPL.convert_tilde_expression(
                lhs,
                fform,
                args,
                Val(length(args) + 1),
            )
        elseif @capture(expression, (lhs_ ~ fform_(args__)))
            return GraphPPL.convert_tilde_expression(lhs, fform, args)
        else
            return expression
        end
    end

    result = quote

        $boilerplate_functions

        function GraphPPL.make_node!(
            model,
            ::GraphPPL.Composite,
            parent_context,
            ::typeof($ms_name),
            interfaces,
        )
            context = GraphPPL.Context(parent_context, $ms_name)
            GraphPPL.copy_markov_blanket_to_child_context(context, interfaces)
            $ms_body
            node_id = GraphPPL.gensym(model, $ms_name)
            GraphPPL.add_composite_factor_node!(model, context, parent_context, $ms_name)
        end
        nothing
    end
    return esc(result)


end