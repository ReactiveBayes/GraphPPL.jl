module GraphPPL

import ReactiveMP

export @model

import MacroTools: @capture, postwalk, prewalk

"""
    fquote(expr)

This function forces `Expr` or `Symbol` to be quoted.
"""
fquote(expr::Symbol) = Expr(:quote, expr)
fquote(expr::Expr)   = expr

"""
    ensure_type
"""
ensure_type(x::Type) = x
ensure_type(x)       = error("Valid type object was expected but '$x' has been found")

"""
    parse_varexpr(varexpr)

This function parses variable id and returns a tuple of 3 different representations of the same variable 
1. Original expression
2. Short variable identificator (used in variables lookup table)
3. Full variable identificator (used in model as a variable id)
"""
function parse_varexpr(varexpr::Symbol)
    varexpr  = varexpr
    short_id = varexpr
    full_id  = varexpr
    return varexpr, short_id, full_id
end

function parse_varexpr(varexpr::Expr)
    @capture(varexpr, id_[idx__]) || 
        error("Variable identificator can be in form of a single symbol (x ~ ...) or indexing expression (x[i] ~ ...)")
   
    varexpr  = varexpr
    short_id = id
    full_id  = Expr(:call, :Symbol, fquote(id), Expr(:quote, :_), Expr(:quote, Symbol(join(idx, :_))))

    return varexpr, short_id, full_id
end

"""
    normalize_tilde_arguments(args)

This function 'normalizes' every argument of a tilde expression making every inner function call to be a tilde expression as well. 
It forces MSL to create anonymous node for any non-linear variable transformation or deterministic relationships. MSL does not check (and cannot in general) 
if some inner function call leads to a constant expression or not (e.g. `Normal(0.0, sqrt(10.0))`). Backend API should decide whenever to create additional anonymous nodes 
for constant non-linear transformation expressions or not by analyzing input arguments.
"""
function normalize_tilde_arguments(args)
    return map(args) do arg
        if @capture(arg, id_[idx__])
            return arg
        elseif @capture(arg, (f_(v__) where { options__ }) | (f_(v__)))
            nvarexpr  = gensym(:nvar)
            nnodeexpr = gensym(:nnode)
            options  = options !== nothing ? options : []
            v = normalize_tilde_arguments(v)
            return :(($nnodeexpr, $nvarexpr) ~ $f($(v...); $(options...)); $nvarexpr)
        else
            return arg
        end
    end
end

"""
    write_argument_guard(backend, argument)
"""
function write_argument_guard end

"""
    write_randomvar_expression(backend, model, varexpr, arguments)
"""
function write_randomvar_expression end

"""
    write_datavar_expression(backend, model, varexpr, type, arguments)
"""
function write_datavar_expression end

"""
    write_as_variable(backend, model, varexpr)
"""
function write_as_variable end

"""
    write_make_node_expression(backend, model, fform, variables, options, nodeexpr, varexpr)
"""
function write_make_node_expression end

"""
    write_autovar_make_node_expression(backend, model, fform, variables, options, nodeexpr, varexpr, autovarid)
"""
function write_autovar_make_node_expression end

"""
    write_node_options(backend, fform, variables, options)
"""
function write_node_options end

include("backends/reactivemp.jl")

macro model(model_specification)
    @capture(model_specification, function ms_name_(ms_args__) ms_body_ end) || 
        error("Model specification language requires full function definition")
       
    backend = ReactiveMPBackend()

    model = gensym(:model)

    ms_args_ids = map(ms_args) do ms_arg
        if ms_arg isa Symbol
            return ms_arg::Symbol
        elseif ms_arg isa Expr && ms_arg.head === :(::)
            return ms_arg.args[1]::Symbol
        else
            error("Invalid argument specification: $(ms_arg)")
        end
    end

    # Step 0: Check that all inputs are not AbstractVariables
    # It is highly recommended not to create AbstractVariables outside of the model creation macro
    # Doing so can lead to undefined behaviour
    ms_args_checks = map((ms_arg) -> write_argument_guard(backend, ms_arg), ms_args_ids)

    # Step 1: Probabilistic arguments normalisation
    ms_body = postwalk(ms_body) do expression
        if @capture(expression, (varexpr_ ~ fform_(arguments__) where { options__ }) | (varexpr_ ~ fform_(arguments__)))
            options = options === nothing ? [] : options
            varexpr =  @capture(varexpr, (nodeid_, varid_)) ? varexpr : :(($(gensym(:nnode)), $varexpr))
            return :($varexpr ~ $(fform)($((normalize_tilde_arguments(arguments))...); $(options...)))
        else
            return expression
        end
    end

    varids = Set{Symbol}(ms_args_ids)
       
    # Step 2: Main pass
    ms_body = postwalk(ms_body) do expression
        # Step 2.1 Convert datavar calls
        if @capture(expression, varexpr_ = datavar(arguments__)) 
            @assert varexpr ∉ varids "Invalid model specification: $varexpr is duplicated"
            @assert length(arguments) >= 1 "datavar() call requires type specification as a first argument"
            
            push!(varids, varexpr)

            type = :(GraphPPL.ensure_type($(arguments[1])))
            tail = arguments[2:end]

            return write_datavar_expression(backend, model, varexpr, type, tail)
        # Step 2.2 Convert randomvar calls
        elseif @capture(expression, varexpr_ = randomvar(arguments__))
            @assert varexpr ∉ varids "Invalid model specification: $varexpr is duplicated"
            push!(varids, varexpr)

            return write_randomvar_expression(backend, model, varexpr, arguments)
        # Step 2.2 Convert tilde expressions
        elseif @capture(expression, (nodeexpr_, varexpr_) ~ fform_(arguments__; kwarguments__))
            # println(expression)
            varexpr, short_id, full_id = parse_varexpr(varexpr)

            variables = map((argexpr) -> write_as_variable(backend, model, argexpr), arguments)
            options   = write_node_options(backend, fform, [ varexpr, arguments... ], kwarguments)
            
            if short_id ∈ varids
                return write_make_node_expression(backend, model, fform, variables, options, nodeexpr, varexpr)
            else
                push!(varids, short_id)
                return write_autovar_make_node_expression(backend, model, fform, variables, options, nodeexpr, varexpr, full_id)
            end
        else
            return expression
        end
    end

    # Step 3: Final pass
    ms_body = postwalk(ms_body) do expression
        @capture(expression, return ret_) ? quote activate!($model); return $model, ($ret) end : expression
    end
        
    res = quote
        function $ms_name($(ms_args...))
            $(ms_args_checks...)
            $model = Model()
            $ms_body
            error("'return' statement is missing")
        end     
    end
        
    return esc(res)
end

end # module
