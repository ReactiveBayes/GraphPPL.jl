using MacroTools

function check_for_returns(e::Expr)
    if e.head == :return
        error("The constraints macro does not support return statements.")
    end
    return e
end

function add_constraints_construction(e::Expr)
    return quote
        constraints = GraphPPL.Constraints()
        $e
        return constraints
    end
end

function replace_begin_end(e::Expr)
    if @capture(e, var_[index_])
        if index == :begin
            return :($var[GraphPPL.FunctionalIndex{:begin}(firstindex)])
        elseif index === :end
            return :($var[GraphPPL.FunctionalIndex{:end}(lastindex)])
        end
    elseif @capture(e, var_[index__])
        index = map(i -> i === :begin ? :(GraphPPL.FunctionalIndex{:begin}(firstindex)) : i === :end ? :(GraphPPL.FunctionalIndex{:end}(lastindex)) : i, index)
        return :($var[$(index...)])
    end
    return e
end

function create_submodel_constraints(e::Expr)
    if @capture(e, (
        for q in submodel_
            body__
        end
    ))
        return quote
            let outer_constraints = constraints
                let constraints = GraphPPL.SubModelConstraints($submodel)
                    $(body...)
                    push!(outer_constraints, constraints)
                end
            end
        end
    else
        return e
    end
end

function create_factorization_split(e::Expr)
    if @capture(e, lhs_ .. rhs_)
        return :(GraphPPL.factorization_split([$lhs], [$rhs]))
    else
        return e
    end
end

function create_factorization_combinedrange(e::Expr)
    if @capture(e, a_:b_)
        return :(CombinedRange($a, $b))
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

function convert_rhs_multiplication(e::Expr)
    if @capture(e, (q(vars__) = rhs_))
        rhs = prettify(rhs)
        if rhs isa Expr && rhs.args[1] == :*
            rhs = rhs.args[2:end]
        else
            rhs = [rhs]
        end
        return :(q($(vars...)) = $(Expr(:vect, rhs...)))
    end
    return e
end
what_walk(::typeof(convert_rhs_multiplication)) = walk_until_occurrence(:(q(vars__) = rhs_))

function convert_functionalform_constraints(e::Expr)
    if @capture(e, (q(vars_)::T_))
        return quote
            push!(constraints, GraphPPL.FunctionalFormConstraint($vars, $T))
        end
    elseif @capture(e, (q(vars__)::T_))
        return quote
            push!(constraints, GraphPPL.FunctionalFormConstraint($(Expr(:vect, vars...)), $T))
        end
    else
        return e
    end
end

function convert_message_constraints(e::Expr)
    if @capture(e, (μ(vars_)::T_))
        return quote
            push!(constraints, GraphPPL.MessageConstraint($vars, $T))
        end
    elseif @capture(e, (μ(vars__)::T_))
        return quote
            push!(constraints, GraphPPL.MessageConstraint($(Expr(:vect, vars...)), $T))
        end
    else
        return e
    end
end

function convert_factorization_constraints(e::Expr)
    if @capture(e, (q(lhs__) = rhs_))
        rhs = walk_until_occurrence(:(q(vars__)))(rhs) do expr
            if @capture(expr, (q(vars__)))
                return :(GraphPPL.FactorizationConstraintEntry($(Expr(:vect, vars...))))
            end
            return expr
        end
        return quote
            push!(constraints, GraphPPL.FactorizationConstraint($(Expr(:vect, lhs...)), $rhs))
        end
    end
    return e
end

function constraints_macro_interior(cs_body::Expr)
    cs_body = apply_pipeline(cs_body, check_for_returns)
    cs_body = add_constraints_construction(cs_body)
    cs_body = apply_pipeline(cs_body, replace_begin_end)
    cs_body = apply_pipeline(cs_body, create_submodel_constraints)
    cs_body = apply_pipeline(cs_body, create_factorization_split)
    cs_body = apply_pipeline(cs_body, create_factorization_combinedrange)
    cs_body = apply_pipeline(cs_body, convert_variable_statements)
    cs_body = apply_pipeline(cs_body, convert_rhs_multiplication)
    cs_body = apply_pipeline(cs_body, convert_functionalform_constraints)
    cs_body = apply_pipeline(cs_body, convert_message_constraints)
    cs_body = apply_pipeline(cs_body, convert_factorization_constraints)
    @show prettify(cs_body)
    return cs_body
end

macro constraints(constraints_specification)
    return esc(GraphPPL.constraints_macro_interior(constraints_specification))
end
