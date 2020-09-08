export @reactivemodel

using MacroTools: postwalk, rmlines, prettify

macro reactivemodel(ex::Expr)
    return esc(postwalk(rmlines, generate_model(ex)))
end


# function kalman_filter_graph()
#     model = Model(DefaultMessageGate())    
    
#     x_prior = add!(model, datavar(:x_prior, Normal{Float64}))
#     add_1   = add!(model, constvar(:add_1, 1.0))    
#     noise   = add!(model, constvar(:noise, Normal(0.0, sqrt(200.0))))    
    
#     x = add!(model, randomvar(:x))
#     y = add!(model, datavar(:y, Float64))    
    
#     x_prev_add = add!(model, make_node(+, x_prior, add_1, x))
#     add_x_and_noise = add!(model, make_node(+, x, noise, y))
    
#     activate!(model, x_prev_add)
#     activate!(model, add_x_and_noise)    
    
#     return x_prior, x, y
# end

function generate_model(model_expr::Expr)
    program = postwalk(rmlines, model_expr)
    @assert program.head == :function
    
    model_signature = program.args[1]
    model_name, argument_names = analyze_signature(model_signature)
    
    model_definition = program.args[2]
    model_expr = build_model(model_definition)
    
    result = quote
        function $model_name($(argument_names...))
            model = Model(DefaultMessageGate())
            $model_expr
            return g
        end
    end

    result = postwalk(rmlines, result)
    
    return result
end

function build_model(model_definition::Expr)
    for (i, expr) in enumerate(model_definition.args)
        model_definition.args[i] = rewrite_expression(expr)
    end
    
    return model_definition
end

function analyze_signature(args_expr)
    @assert args_expr.head == :call
    model_name = args_expr.args[1]
    
    if length(args_expr.args) > 1
        argument_names = args_expr.args[2:end]
    else
        argument_names = []
    end
    
    return model_name, argument_names
end


