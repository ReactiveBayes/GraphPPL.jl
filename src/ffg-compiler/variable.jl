function rewrite_expression(definition::Expr)
    
    dump(definition)
    expr = if is_tilde(definition)
        rewrite_tilde_expression(definition)
    elseif is_assign(definition)
        rewrite_assign_expression(definition)
    else
        definition
    end

    return expr
end

# Parse RV definition expression

# FORM 1: @RV x ~ Probdist(...)
is_tilde(expr::Expr) = expr.head === :call && expr.args[1] === :(~)
is_tilde(expr)       = false

function rewrite_tilde_expression(def)
    if def.args[3].args[1] == :(∥)
        options = get_options(def.args[3].args[3])
        node = def.args[3].args[2]
    else
        options = Dict{Symbol,Any}()
        node = def.args[3]
    end

    target = def.args[2]

    var_id = extract_variable_id(target, options)
    
    node.args[1] = node.args[1]*:Node

    if isa(node.args[2], Expr) && (node.args[2].head == :parameters)
        node.args = vcat(node.args[1:2], [target], node.args[3:end])
    else
        node.args = vcat([node.args[1]; target], node.args[2:end])
    end
    
    # Build total expression
    return quote
        begin
            # Use existing Variable if it exists, otherwise create a new one
            $(target) = try
                $(target)
            catch _
                Variable(id = $(var_id))
            end

            # Create new variable if:
            #   - the existing object is not a Variable
            #   - the existing object is a Variable from another FactorGraph
            if (!isa($(target), Variable)
                || !haskey(currentGraph().variables, $(target).id)
                || currentGraph().variables[$(target).id] !== $(target))

                $(target) = Variable(id = $(var_id))
            end

            $(node)
            $(target)
        end
    end
end

# FORM 2: @RV x = a + b
is_assign(expr::Expr) = expr.head === :(=)
is_assign(expr)       = false

function rewrite_assign_expression(def)
    if def.args[2].args[1] == :(∥)
        options = get_options(def.args[2].args[3])
    else
        options = Dict{Symbol,Any}()
    end

    target = def.args[1]

    var_id = extract_variable_id(target, options)

    # Form 2 always creates a new Variable
    # Build complete expression
    var_id_sym = gensym()
    return quote
        begin
            $(target) = $(def.args[2].args[2])
            $(var_id_sym) = $(var_id)
            if $(var_id_sym) != :auto
                # update id of newly created Variable
                currentGraph().variables[$(var_id_sym)] = $(target)
                delete!(currentGraph().variables, $(target).id)
                $(target).id = $(var_id_sym)
            end
            $(target)
        end
    end
end

function get_options(options_expr::Expr)
    options = Dict{Symbol,Any}()
    
    options_expr.head == :vect || return :(error("Incorrect options specification: options argument must be a vector expression"))
    
    for arg in options_expr.args
        arg isa Expr && arg.head == :(=) || return :(error("Incorrect options specification: options item must be an assignment expression"))
        options[arg.args[1]] = arg.args[2]
    end

    return options
end

# If variable expression is a symbol
# RV x ...
function extract_variable_id(expr::Symbol, options)
    if haskey(options, :id)
        return check_id_available(options[:id])
    else
        return guard_variable_id(:($(string(expr))))
    end
end

# If variable expression is an indexing expression
# RV x[i] ...
function extract_variable_id(expr::Expr, options)
    if haskey(options, :id)
        return check_id_available(options[:id])
    else
        argstr = map(arg -> :(string($arg)), @view expr.args[2:end])
        return guard_variable_id(:($(string(expr.args[1]) * "_") * $(reduce((current, item) -> :($current * "_" * $item), argstr))))
    end
end

# Fallback
function extract_variable_id(expr, options)
    return :(ForneyLab.generateId(Variable))
end


function check_id_available(expr)
    return :(!haskey(currentGraph().variables, $(expr)) ? $(expr) : error("Specified id is already assigned to another Variable"))
end

# Ensure that variable has a unique id in a current factor graph, generate a new one otherwise
function guard_variable_id(expr)
    idsymbol = :(Symbol($(expr)))
    return :(!haskey(currentGraph().variables, $idsymbol) ? $idsymbol : ForneyLab.generateId(Variable))
end