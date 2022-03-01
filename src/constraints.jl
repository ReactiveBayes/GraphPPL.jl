export @constraints

"""
    write_constraints_specification(backend, factorisation, marginalsform, messagesform) 
"""
function write_constraints_specification end

"""
    write_factorisation_constraint(backend, names, entries)
"""
function write_factorisation_constraint end

"""
    write_factorisation_constraint_entry(backend, names, entries) 
"""
function write_factorisation_constraint_entry end

"""
    write_init_factorisation_not_defined(backend, spec, name) 
"""
function write_init_factorisation_not_defined end

"""
    write_check_factorisation_is_not_defined(backend, spec)
"""
function write_check_factorisation_is_not_defined end

"""
    write_factorisation_split(backend, left, right)
"""
function write_factorisation_split end

"""
    write_factorisation_combined_range(backend, left, right)
"""
function write_factorisation_combined_range end

"""
    write_factorisation_splitted_range(backend, left, right)
"""
function write_factorisation_splitted_range end

"""
    write_factorisation_functional_index(backend, repr, fn)
"""
function write_factorisation_functional_index end

"""
    write_form_constraint_specification(backend, T, args, kwargs)
"""
function write_form_constraint_specification end

macro constraints(constraints_specification)
    return generate_constraints_expression(__get_current_backend(), constraints_specification)
end

## Factorisation constraints

struct FactorisationConstraintLHSMeta
    name :: String
    hash :: UInt
    varname :: Symbol
end

## 

## Form constraints

function flatten_functional_form_constraint_specification(expr) 
    return flatten_functional_form_constraint_specification!(expr, Expr(:(call), :(::)))
end

function flatten_functional_form_constraint_specification!(symbol::Symbol, toplevel::Expr)
    push!(toplevel.args, symbol)
    return toplevel
end

function flatten_functional_form_constraint_specification!(expr::Expr, toplevel::Expr)
    if ishead(expr, :(::)) && ishead(expr.args[1], :(::))
        flatten_functional_form_constraint_specification!(expr.args[1], toplevel)
        flatten_functional_form_constraint_specification!(expr.args[2], toplevel)
    elseif ishead(expr, :(::))
        push!(toplevel.args, expr.args[1])
        push!(toplevel.args, expr.args[2])
    else
        push!(toplevel.args, expr)
    end
    return toplevel
end

function parse_form_constraint(backend, expr)
    T, args, kwargs = if expr isa Symbol
        expr, :(()), :((;))
    else
        if @capture(expr, f_(args__; kwargs__))
            f, :(($(args...), )), :((; $(kwargs...), ))
        elseif @capture(expr, f_(args__))

            as = []
            ks = []

            for arg in args
                if ishead(arg, :kw)
                    push!(ks, arg)
                else
                    push!(as, arg)
                end
            end

            f, :(($(as...), )), :((; $(ks...), ))
        elseif @capture(expr, f_())
            f, :(()), :((;))
        else
            error("Unssuported form constraints call specification in the expression `$(expr)`")
        end
    end 

    return write_form_constraint_specification(backend, T, args, kwargs)
end

##

function generate_constraints_expression(backend, constraints_specification)

    if isblock(constraints_specification)
        generatedfname = gensym(:constraints)
        generatedfbody = :(function $(generatedfname)() $constraints_specification end)
        return :($(generate_constraints_expression(backend, generatedfbody))())
    end

    @capture(constraints_specification, (function cs_name_(cs_args__; cs_kwargs__) cs_body_ end) | (function cs_name_(cs_args__) cs_body_ end)) || 
        error("Constraints specification language requires full function definition")
    
    cs_args   = cs_args === nothing ? [] : cs_args
    cs_kwargs = cs_kwargs === nothing ? [] : cs_kwargs
    
    lhs_dict = Dict{UInt, FactorisationConstraintLHSMeta}()
    
    marginals_form_constraints_symbol      = gensym(:marginals_form_constraint)
    marginals_form_constraints_symbol_init = :($marginals_form_constraints_symbol = (;))

    messages_form_constraints_symbol      = gensym(:messages_form_constraint)
    messages_form_constraints_symbol_init = :($messages_form_constraints_symbol = (;))
    
    factorisation_constraints_symbol      = gensym(:factorisation_constraint)
    factorisation_constraints_symbol_init = :($factorisation_constraints_symbol = ())

    # First we modify form constraints related statements
    cs_body = prewalk(cs_body) do expression 
        if ishead(expression, :(::))
            return flatten_functional_form_constraint_specification(expression)
        end
        return expression
    end

    cs_body = prewalk(cs_body) do expression
        if iscall(expression, :(::))
            if @capture(expression.args[2], q(formsym_Symbol)) 
                specs = map((e) -> parse_form_constraint(backend, e), view(expression.args, 3:lastindex(expression.args)))
                return quote 
                    if haskey($marginals_form_constraints_symbol, $(QuoteNode(formsym)))
                        error("Marginal form constraint q($(formsym)) has been redefined.")
                    end
                    $marginals_form_constraints_symbol = (; $marginals_form_constraints_symbol..., $formsym = ($(specs... ),))
                end
            elseif @capture(expression.args[2], μ(formsym_Symbol)) 
                specs = map((e) -> parse_form_constraint(backend, e), view(expression.args, 3:lastindex(expression.args)))
                return quote 
                    if haskey($messages_form_constraints_symbol, $(QuoteNode(formsym)))
                        error("Messages form constraint μ($(formsym)) has been redefined.")
                    end
                    $messages_form_constraints_symbol = (; $messages_form_constraints_symbol..., $formsym = ($(specs... ),))
                end
            else
                error("Invalid form factorisation constraint. $(expression.args[2]) has to be in the form of q(varname) for marginal form constraint or μ(varname) for messages form constraint.")
            end
        end
        return expression
    end

    # Second we modify factorisation constraints related statements
    # First we record all lhs expression's hash ids and create unique variable names for them
    # q(x, y) = q(x)q(y) -> hash(q(x, y))
    # We do allow multiple definitions in case of if statements, but we do check later overwrites, which are not allowed
    cs_body = postwalk(cs_body) do expression
        # We also do a simple sanity check right now, names should be an array of Symbols only
        if @capture(expression, lhs_ = rhs_) && @capture(lhs, q(names__))
            
            (length(names) !== 0 && all(name -> name isa Symbol, names)) || 
                error("""Error in factorisation constraints specification $(lhs_name) = ...\nLeft hand side of the equality expression should have only variable identifiers.""")
            
            # We replace '..' in RHS expression with `write_factorisation_split`
            rhs = postwalk(rhs) do rexpr
                if @capture(rexpr, a_ .. b_)
                    return write_factorisation_split(backend, a, b)
                end
                return rexpr
            end
            
            lhs_names = Set{Symbol}(names)
            rhs_names = Set{Symbol}()
            
            # We do a simple check to be sure that LHS and RHS has the exact same set of names
            # We also check here that all indices are either a simple Symbol or an indexing expression here
            rhs = postwalk(MacroTools.prettify(rhs, alias = false)) do entry
                if @capture(entry, q(indices__))
                    for index in indices
                        if index isa Symbol
                            (index ∉ rhs_names) || error("RHS of the $(expression) expression used $(index) without indexing twice, which is not allowed. Try to decompose factorisation constraint expression into several subexpression.")
                            push!(rhs_names, index)
                            (index ∉ lhs_names) && error("LHS of the $(expression) expression does not have $(index) variable, but is used in RHS.")
                        elseif isref(index)
                            push!(rhs_names, first(index.args))
                            (first(index.args) ∉ lhs_names) && error("LHS of the $(expression) expression does not have $(first(index.args)) variable, but is used in RHS.")
                        else
                           error("Cannot parse expression $(index) in the RHS $(rhs) expression. Index expression should be either a single variable symbol or an indexing expression.") 
                        end
                    end
                end
                return entry
            end
            
            (lhs_names == rhs_names) || error("LHS and RHS of the $(expression) expression has different set of variables.")
            
            lhs_hash = hash(lhs)
            lhs_meta = if haskey(lhs_dict, lhs_hash)
                lhs_dict[ lhs_hash ]
            else
                lhs_name = string("q(", join(names, ", "), ")")
                lhs_varname = gensym(lhs_name)
                lhs_meta = FactorisationConstraintLHSMeta(lhs_name, lhs_hash, lhs_varname)
                lhs_dict[lhs_hash] = lhs_meta
            end
            
            lhs_name = lhs_meta.name
            lhs_varname = lhs_meta.varname
            
            new_factorisation_specification = write_factorisation_constraint(backend, :(Val(($(map(QuoteNode, names)...),))), :(Val($(rhs))))
            check_is_not_defined            = write_check_factorisation_is_not_defined(backend, lhs_varname)
            
            result = quote 
                $(check_is_not_defined) || error("Factorisation constraints specification $($lhs_name) = ... has been redefined.")
                $(lhs_varname) = $(new_factorisation_specification)
                $factorisation_constraints_symbol = ($factorisation_constraints_symbol..., $(lhs_varname))
            end
            
            return result
        end
        return expression
    end
    
    # This block write initial variables for factorisation specification
    cs_lhs_init_block = map(collect(lhs_dict)) do pair
        lhs_meta = last(pair)
        lhs_name = lhs_meta.name
        lhs_varname = lhs_meta.varname
        lhs_symbol = Symbol(lhs_name)
        return write_init_factorisation_not_defined(backend, lhs_varname, lhs_symbol)
    end
    
    cs_body = prewalk(cs_body) do expression
        if @capture(expression, q(args__))
            rhs_prod_names = Symbol[]
            rhs_prod_entries_args = map(args) do arg
                if arg isa Symbol
                    push!(rhs_prod_names, arg)
                    return :(nothing)
                elseif isref(arg)
                    (length(arg.args) === 2) || error("Indexing expression $(expression) is too difficult to parse and is not supported (yet?).")
                    push!(rhs_prod_names, first(arg.args))

                    index = last(arg.args)

                    # First we replace all `begin` and `end` with `firstindex` and `lastindex` functions
                    index = postwalk(index) do iexpr
                        if iexpr isa Symbol && iexpr === :begin
                            return write_factorisation_functional_index(backend, :begin, :firstindex)
                        elseif iexpr isa Symbol && iexpr === :end
                            return write_factorisation_functional_index(backend, :end, :lastindex)
                        else
                            return iexpr
                        end
                    end

                    if @capture(index, a_:b_)
                        return write_factorisation_combined_range(backend, a, b)
                    else
                        return index
                    end
                else
                    error("Cannot parse expression $(index) in the RHS $(rhs) expression. Index expression should be either a single variable symbol or an indexing expression.") 
                end
            end

            entry = write_factorisation_constraint_entry(backend, :(Val(($(map(QuoteNode, rhs_prod_names)...), ))), :(Val(($(rhs_prod_entries_args...), ))))

            return :(($entry, ))
        end
        return expression
    end
    
    return_specification = write_constraints_specification(backend, factorisation_constraints_symbol, marginals_form_constraints_symbol, messages_form_constraints_symbol)
    
    res = quote
         function $cs_name($(cs_args...); $(cs_kwargs...))
            $(marginals_form_constraints_symbol_init)
            $(messages_form_constraints_symbol_init)
            $(factorisation_constraints_symbol_init)
            $(cs_lhs_init_block...)
            $(cs_body)
            $(return_specification)
        end 
    end
    
    return esc(res)
end