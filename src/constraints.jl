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
    write_make_constraints(backend)
"""
function write_make_constraints end

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
    write_factorisation_node(backend, constraints, key, entries)
"""
function write_factorisation_node end


macro constraints(constraints_specification)
    return GraphPPL.generate_constraints_expression(__get_current_backend(), constraints_specification)
end

function generate_constraints_expression(backend, constraints_specification)


    @capture(constraints_specification, (function cs_name_(cs_args__; cs_kwargs__) cs_body_ end) | (function cs_name_(cs_args__) cs_body_ end)) || 
        error("Constraints specification language requires full function definition")

    constraints = gensym(:constraints)

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

            # print(rhs)

            return write_factorisation_node(backend, constraints, lhs, rhs)
        end
        return expression
    end

    cs_args   = cs_args === nothing ? [] : cs_args
    cs_kwargs = cs_kwargs === nothing ? [] : cs_kwargs

    res = quote 
        function $cs_name($(cs_args...); $(cs_kwargs...))
            # TODO let block
            function __from_model(model) 
                $constraints = $(GraphPPL.write_make_constraints(backend))
                $cs_body
                $constraints
            end
            return __from_model
        end  
    end

    return esc(res)
end