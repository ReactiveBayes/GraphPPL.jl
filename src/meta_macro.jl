using MacroTools

function add_meta_construction(e::Expr)
    return quote
        __meta__ = GraphPPL.MetaSpecification()
        $e
        return __meta__
    end
end

function create_submodel_meta(e::Expr)
    if @capture(e, (
        for meta in submodel_
            body__
        end
    ))
        return quote
            let __outer_meta__ = __meta__
                let __meta__ = begin
                        try
                            GraphPPL.SubModelMeta($submodel)
                        catch
                            GraphPPL.SubModelMeta($(QuoteNode(submodel)))
                        end
                    end
                    $(body...)
                    push!(__outer_meta__, __meta__)
                end
            end
        end
    else
        return e
    end
end

function convert_meta_variables(e::Expr)
    if @capture(e, (fform_(vars__) -> meta_obj_))
        vars = map(var -> __convert_to_indexed_statement(var), vars)
        return quote
            $fform($(vars...)) -> $meta_obj
        end
    elseif @capture(e, (var_ -> meta_obj_))
        var = __convert_to_indexed_statement(var)
        return quote
            $var -> $meta_obj
        end
    end
    return e
end

what_walk(::typeof(convert_meta_variables)) = walk_until_occurrence(:(lhs_ -> rhs_))

function convert_meta_object(e::Expr)
    if @capture(e, (var_ -> meta_obj_))
        if @capture(var, (GraphPPL.IndexedVariable(args__)))
            return quote
                push!(
                    __meta__,
                    GraphPPL.MetaObject(GraphPPL.VariableMetaDescriptor($var), $meta_obj),
                )
            end
        elseif @capture(e, (fform_(vars__) -> meta_obj_))

            return quote
                push!(
                    __meta__,
                    GraphPPL.MetaObject(
                        GraphPPL.FactorMetaDescriptor($fform, ($(vars...),)),
                        $meta_obj,
                    ),
                )
            end
        end
    else
        return e
    end
end
