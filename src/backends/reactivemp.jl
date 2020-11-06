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