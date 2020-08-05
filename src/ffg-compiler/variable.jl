function rewrite_expression(definition::Expr)
    
    # Parse RV definition expression
    # It can take three forms:
    # FORM 1: x ~ Probdist(...)
    # FORM 2: x = a + b
    # FORM 3: x

    expr = if rv_isa_form1(definition)
        rv_form1(definition, definition.args[2], definition.args[3])
    elseif rv_isa_form2(definition)
        rv_form2(definition, definition.args[1], definition.args[2])
    else
        definition
    end
    return expr
end

# Parse RV definition expression

# FORM 1: @RV x ~ Probdist(...)
rv_isa_form1(expr::Expr) = expr.head === :call && expr.args[1] === :(~)
rv_isa_form1(expr)       = false

function rv_form1(def, target, node)
    var_id = extract_variable_id(target, Dict())
    
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
rv_isa_form2(expr::Expr) = expr.head === :(=)
rv_isa_form2(expr)       = false

function rv_form2(def, target, node)
    var_id = extract_variable_id(target, Dict())

    # Form 2 always creates a new Variable
    # Build complete expression
    var_id_sym = gensym()
    return quote
        begin
            $(def)
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