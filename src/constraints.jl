export @constraints

function parse_qexpr(backend, constraints, expression::Expr)
    if !@capture(expression, q(args__))
        error("Cannot parse q expression: $(expression).")
    end

    entries = map(args) do entry 
        if @capture(entry, name_Symbol)
            return write_factorisation_spec_entry(backend, constraints, QuoteNode(name), :(nothing))
        elseif @capture(entry, name_Symbol[index_])
            return write_factorisation_spec_entry(backend, constraints, QuoteNode(name), index)
        else 
            error("Cannot parse entry of q expression: ($entry)")
        end
    end

    return write_factorisation_spec(backend, constraints, entries)
end

"""
    write_constraints_factorisation(backend)
"""
function write_constraints_factorisation end

"""
    write_constraints_generator(backend, generator)
"""
function write_constraints_generator end

"""
    write_factorisation_spec(backend, constraints, entries)
"""
function write_factorisation_spec end

"""
    write_factorisation_spec_entry(backend, constraints, arguments)
"""
function write_factorisation_spec_entry end

"""
    write_factorisation_merge_spec_entries(backend, constraints, left, right)
"""
function write_factorisation_merge_spec_entries end

"""
    write_factorisation_spec_list(backend, constraints, key, entries)
"""
function write_factorisation_spec_list end


macro constraints(constraints_specification)
    return GraphPPL.generate_constraints_expression(__get_current_backend(), constraints_specification)
end

function generate_constraints_expression(backend, constraints_specification)

    if isblock(constraints_specification)
        generatedfname = gensym(:constraints)
        generatedfbody = :(function $(generatedfname)() $constraints_specification end)
        return :($(generate_constraints_expression(backend, generatedfbody))())
    end

    @capture(constraints_specification, (function cs_name_(cs_args__; cs_kwargs__) cs_body_ end) | (function cs_name_(cs_args__) cs_body_ end)) || 
        error("Constraints specification language requires full function definition")

    modelvar    = gensym(:model)
    constraints = gensym(:constraints)

    # First we modify all expression of the form symbol_[begin] or symbol_[end] 
    # Each expression of this form refers to a special variable called `modelvar` and extract model related variable
    cs_body = prewalk(cs_body) do expression 
        if @capture(expression, symbol_[begin])
            return :($(symbol)[firstindex($(modelvar)[$(QuoteNode(symbol))])])
        elseif @capture(expression, symbol_[end])
            return :($(symbol)[lastindex($(modelvar)[$(QuoteNode(symbol))])])
        end
        return expression
    end

    # Second we transform all expression of the form `q(..) = ...`
    cs_body = prewalk(cs_body) do expression 
        if @capture(expression, lhs_arg_ = rhs_)
            lhs = parse_qexpr(backend, constraints, lhs_arg)

            rhs = prewalk(rhs) do rhs_expression
                if @capture(rhs_expression, q(args__))
                    return parse_qexpr(backend, constraints, rhs_expression)
                elseif @capture(rhs_expression, left_..right_)
                    return write_factorisation_merge_spec_entries(backend, constraints, left, right)
                end

                return rhs_expression
            end
            
            return write_factorisation_spec_list(backend, constraints, lhs, rhs)
        end
        return expression
    end

    cs_args   = cs_args === nothing ? [] : cs_args
    cs_kwargs = cs_kwargs === nothing ? [] : cs_kwargs

    # By default `@constraints` macro should return a callable object over a model
    # In this way we will have an access to model related variables later on
    generatorfn = gensym(:__from_model)

    res = quote 
        function $cs_name($(cs_args...); $(cs_kwargs...))
            # TODO let block
            $generatorfn = ($modelvar) -> begin
                $constraints = $(GraphPPL.write_constraints_factorisation(backend))
                $cs_body
                # TODO add form constraints
                return $constraints
            end
            return $(GraphPPL.write_constraints_generator(backend, generatorfn))
        end  
    end

    return esc(res)
end