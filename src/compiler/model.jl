export @model

using MacroTools:postwalk, rmlines

function generate_model(model_expr::Expr)
    stripped = postwalk(rmlines, model_expr)
    @assert stripped.head == :block
    @assert stripped.args[1].head == Symbol("=")

    program = stripped.args[1]
    
    model_signature = program.args[1]
    model_name, argument_names = analyze_signature(model_signature)
    
    model_definition = program.args[2]
    model_expr = build_model(model_definition)
    
    return quote
        function $model_name($(argument_names...))
            $model_expr
        end
    end
end

function build_model(model_definition::Expr)
    for (i, expr) in enumerate(model_definition.args)
        model_definition.args[i] = rewrite_expression(expr)
    end
    return model_definition
end

function rewrite_expression(expr)
    if expr.head == :call && expr.args[1] == :~
        return rewrite_tilde_expression(expr)
    else
        error("Unsupported expression")
    end
end

function rewrite_tilde_expression(expr)
    lhs = expr.args[2]
    rhs = expr.args[3]

    var_id = gensym(lhs)
    dist = Symbol(rhs.args[1])
    arguments = rhs.args[2:end]
    
    return quote 
        $lhs = Variable($var_id) 
        Node($dist, Set{Variable}([$lhs, $(arguments...)]))
    end
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

klmn = quote 
    kalman(n,y) = begin
        x ~ Normal(0,1)
        y ~ Normal(0,1)
        z ~ Normal(x,y)
    end
end

a = postwalk(rmlines, generate_model(klmn))