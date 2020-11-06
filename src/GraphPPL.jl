module GraphPPL

import ReactiveMP

export @model

import MacroTools: @capture, postwalk

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
    write_autovar_make_node_expression(::ReactiveMPBackend, model, fform, variables, options, nodeexpr, varexpr, autovarid)
"""
function write_autovar_make_node_expression end

include("backends/reactivemp.jl")

function normalize_tilde_arguments(args)
    return postwalk(args) do arg
        if @capture(arg, f_(g__))
            nvarid = gensym()
            return quote $nvarid ~ $f($(g...)); $nvarid end
        else
            return arg
        end
    end
end

function is_factorisation_option(option)
    return option isa Expr && option.head === :(=) && option.args[1] === :q
end

function factorisation_replace_var_name(varnames, arg::Expr)
    index = findfirst(==(arg), varnames)
    return index === nothing ? error("Invalid factorisation argument: $arg") : index
end

function factorisation_replace_var_name(varnames, arg::Symbol)
    index = findfirst(==(arg), varnames)
    return index === nothing ? arg : index
end

function factorisation_name_to_index(form, name)
    return ReactiveMP.interface_get_index(Val{ form }, Val{ ReactiveMP.interface_get_name(Val{ form }, Val{ name }) })
end

function write_factorisation_options(form, args, foption)
    if @capture(foption, q = *(factors__))
        factorisation = sort(map(factors) do factor
            @capture(factor, q(names__)) || error("Invalid factorisation constraint: $factor")
            return sort(map((n) -> factorisation_name_to_index(form, n), map((n) -> factorisation_replace_var_name(args, n), names)))
        end, by = first)
        allunique(Iterators.flatten(factorisation)) || error("Invalid factorisation constraint: $foption. Arguments are not unique")
        return Expr(:(=), :factorisation, Expr(:tuple, map(f -> Expr(:tuple, f...), factorisation)...))
    elseif @capture(foption, q = q(names__))
        factorisation = sort(map((n) -> factorisation_name_to_index(form, n), map((n) -> factorisation_replace_var_name(args, n), names)))
        allunique(Iterators.flatten(factorisation)) || error("Invalid factorisation constraint: $foption. Arguments are not unique")
        return Expr(:(=), :factorisation, Expr(:tuple, Expr(:tuple, factorisation...)))
    elseif @capture(foption, q = T_())
        return :(factorisation = $(T)())
    else
        error("Invalid factorisation constraint: $foption")
    end
end

function parse_node_options(form, args, kwargs)
    return map(kwargs) do kwarg

        # Factorisation constraint option
        if is_factorisation_option(kwarg)
            return write_factorisation_options(form, args, kwarg)
        end

        return kwarg
    end
end

macro model(model_specification)
    @capture(model_specification, function ms_name_(ms_args__) ms_body_ end) || 
        error("Model specification language requires full function definition")
       
    backend = ReactiveMPBackend()

    model = gensym(:model)

    # Step 1: Probabilistic arguments normalisation
    ms_body = postwalk(ms_body) do expression
        if @capture(expression, varexpr_ ~ fform_(arguments__))
            return :($varexpr ~ $(fform)($((normalize_tilde_arguments(arguments))...); ))
        elseif @capture(expression, varexpr_ ~ (fform_(arguments__) where { options__ }))
            return :($varexpr ~ $(fform)($((normalize_tilde_arguments(arguments))...); $(options...)))
        else
            return expression
        end
    end

    varids = Set{Symbol}()
       
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
        elseif @capture(expression, varexpr_ ~ fform_(arguments__; kwarguments__))
            nodeexpr = gensym()
            varexpr, short_id, full_id = parse_varexpr(varexpr)

            variables = map((argexpr) -> write_as_variable(backend, model, argexpr), arguments)
            options   = parse_node_options(fform, [ varexpr, arguments... ], kwarguments)
            
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
        @capture(expression, return ret_) ? quote activate!($model); $expression end : expression
    end
        
    res = quote
        function $ms_name($(ms_args...))
            $model = Model()
            $ms_body
            error("'return' statement is missing")
        end     
    end
        
    return esc(res)
end

end # module
