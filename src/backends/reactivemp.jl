export ReactiveMPBackend

struct ReactiveMPBackend end

function write_randomvar_expression(::ReactiveMPBackend, model, varexp, arguments)
    return :($varexp = ReactiveMP.randomvar($model, $(fquote(varexp)), $(arguments...)))
end

function write_datavar_expression(::ReactiveMPBackend, model, varexpr, type, arguments)
    return :($varexpr = ReactiveMP.datavar($model, $(fquote(varexpr)), Dirac{ $type }, $(arguments...)))
end

function write_as_variable(::ReactiveMPBackend, model, varexpr)
    return :(ReactiveMP.as_variable($model, $(fquote(gensym(:arg))), $varexpr))
end

function write_make_node_expression(::ReactiveMPBackend, model, fform, variables, options, nodeexpr, varexpr)
    return :($nodeexpr = ReactiveMP.make_node($model, $fform, $varexpr, $(variables...); $(options...)))
end

function write_autovar_make_node_expression(::ReactiveMPBackend, model, fform, variables, options, nodeexpr, varexpr, autovarid)
    return :(($nodeexpr, $varexpr) = ReactiveMP.make_node($model, $fform, ReactiveMP.AutoVar($(fquote(autovarid))), $(variables...); $(options...)))
end

function write_node_options(::ReactiveMPBackend, fform, variables, options)
    return map(options) do option

        # Factorisation constraint option
        if @capture(option, q = fconstraint_)
            return write_fconstraint_option(fform, variables, fconstraint)
        end

        error("Unknown option '$option' for '$fform' node")
    end
end

function factorisation_replace_var_name(varnames, arg::Expr)
    index = findfirst(==(arg), varnames)
    return index === nothing ? error("Invalid factorisation argument: $arg. $arg should be available within tilde expression") : index
end

function factorisation_replace_var_name(varnames, arg::Symbol)
    index = findfirst(==(arg), varnames)
    return index === nothing ? arg : index
end

function factorisation_name_to_index(form, name)
    return ReactiveMP.interface_get_index(Val{ form }, Val{ ReactiveMP.interface_get_name(Val{ form }, Val{ name }) })
end

function write_fconstraint_option(form, variables, fconstraint)
    if @capture(fconstraint, (*(factors__)) | (q(names__)))
        factors = factors === nothing ? [ fconstraint ] : factors
        indexed = map(factors) do factor
            @capture(factor, q(names__)) || error("Invalid factorisation constraint: $factor")
            return map((n) -> factorisation_name_to_index(form, n), map((n) -> factorisation_replace_var_name(variables, n), names))
        end

        factorisation = sort(map(sort, indexed); by = first)

        allunique(Iterators.flatten(factorisation)) || error("Invalid factorisation constraint: $fconstraint. Arguments are not unique")

        return Expr(:(=), :factorisation, Expr(:tuple, map(f -> Expr(:tuple, f...), factorisation)...))
    elseif @capture(fconstraint, MeanField())
        return :(factorisation = MeanField())
    elseif @capture(fconstraint, FullFactorisation())
        return :(factorisation = FullFactorisation())
    else
        error("Invalid factorisation constraint: $fconstraint")
    end
end