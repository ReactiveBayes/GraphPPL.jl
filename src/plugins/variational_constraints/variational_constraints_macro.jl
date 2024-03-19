export @constraints
using MacroTools

function check_reserved_variable_names_constraints(e::Expr)
    if any(reserved_name -> MacroTools.inexpr(e, reserved_name), [:(__constraints__), :(__outer_constraints__)])
        error("Variable name in $(prettify(e)) cannot be used as it is a reserved variable name in the model macro.")
    end
    return e
end

function check_for_returns(e::Expr; tag = "model")
    if e.head == :return
        error("The $tag macro does not support return statements.")
    end
    return e
end

check_for_returns_constraints = (x) -> check_for_returns(x; tag = "constraints")

function add_constraints_construction(e::Expr)
    if @capture(e, (function c_name_(c_args__; c_kwargs__)
        c_body_
    end) | (function c_name_(c_args__)
        c_body_
    end))
        c_kwargs = c_kwargs === nothing ? [] : c_kwargs
        return quote
            function $c_name($(c_args...); $(c_kwargs...))
                __constraints__ = GraphPPL.Constraints()
                $c_body
                return __constraints__
            end
        end
    else
        return quote
            let __constraints__ = GraphPPL.Constraints()
                $e
                __constraints__
            end
        end
    end
end

function create_submodel_constraints(e::Expr)
    if @capture(e, (
        for q in submodel_
            body__
        end
    ))
        if @capture(submodel, (name_, index_))
            submodel_constructor = :(GraphPPL.SpecificSubModelConstraints(GraphPPL.FactorID($name, $index)))
        else
            submodel_constructor = :(GraphPPL.GeneralSubModelConstraints($submodel))
        end

        return quote
            let __outer_constraints__ = __constraints__
                let __constraints__ = $submodel_constructor
                    $(body...)
                    push!(__outer_constraints__, __constraints__)
                end
            end
        end
    else
        return e
    end
end

function create_factorization_split(e::Expr)
    if @capture(e, lhs_ .. rhs_)
        return :((GraphPPL.factorization_split($lhs, $rhs)))
    else
        return e
    end
end

function create_factorization_combinedrange(e::Expr)
    if @capture(e, a_:b_)
        return :(GraphPPL.CombinedRange($a, $b))
    end
    return e
end

__convert_to_indexed_statement(e::Symbol) = :(GraphPPL.IndexedVariable($(QuoteNode(e)), nothing))
function __convert_to_indexed_statement(e::Expr)
    if @capture(e, (var_[index_]))
        return :(GraphPPL.IndexedVariable($(QuoteNode(var)), $index))
    elseif @capture(e, (var_[index__]))
        return :(GraphPPL.IndexedVariable($(QuoteNode(var)), $(Expr(:vect, index...))))
    end
    return e
end

function convert_variable_statements(e::Expr)
    if @capture(e, q(vars__))
        vars = map(var -> __convert_to_indexed_statement(var), vars)
        return quote
            q($(vars...))
        end
    elseif @capture(e, μ(vars__))
        vars = map(var -> __convert_to_indexed_statement(var), vars)
        return quote
            μ($(vars...))
        end
    end
    return e
end

function convert_functionalform_constraints(e::Expr)
    if @capture(e, (q(vars_)::T_))
        return quote
            push!(__constraints__, GraphPPL.MarginalFormConstraint($vars, $T))
        end
    elseif @capture(e, (q(vars__)::T_))
        return quote
            push!(__constraints__, GraphPPL.MarginalFormConstraint($(Expr(:tuple, vars...)), $T))
        end
    else
        return e
    end
end

function convert_message_constraints(e::Expr)
    if @capture(e, (μ(vars_)::T_))
        return quote
            push!(__constraints__, GraphPPL.MessageFormConstraint($vars, $T))
        end
    elseif @capture(e, (μ(vars__)::T_))
        return quote
            push!(__constraints__, GraphPPL.MessageFormConstraint($(Expr(:tuple, vars...)), $T))
        end
    else
        return e
    end
end

function convert_factorization_constraints(e::Expr)
    if @capture(e, (q(lhs__) = rhs_))
        rhs = walk_until_occurrence(:(q(vars__)))(rhs) do expr
            if @capture(expr, (q(vars__)))
                return :(GraphPPL.FactorizationConstraintEntry($(Expr(:tuple, vars...))))
            end
            return expr
        end
        return quote
            push!(__constraints__, GraphPPL.FactorizationConstraint($(Expr(:tuple, lhs...)), $rhs))
        end
    end
    return e
end

function constraints_macro_interior(cs_body::Expr)
    cs_body = apply_pipeline(cs_body, check_for_returns_constraints)
    cs_body = add_constraints_construction(cs_body)
    cs_body = apply_pipeline(cs_body, replace_begin_end)
    cs_body = apply_pipeline(cs_body, create_submodel_constraints)
    cs_body = apply_pipeline(cs_body, create_factorization_split)
    cs_body = apply_pipeline(cs_body, create_factorization_combinedrange)
    cs_body = apply_pipeline(cs_body, convert_variable_statements)
    cs_body = apply_pipeline(cs_body, convert_functionalform_constraints)
    cs_body = apply_pipeline(cs_body, convert_message_constraints)
    cs_body = apply_pipeline(cs_body, convert_factorization_constraints)
    return cs_body
end

macro constraints(constraints_specification)
    return esc(GraphPPL.constraints_macro_interior(constraints_specification))
end
