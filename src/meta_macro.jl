export @meta
using MacroTools



"""
    add_meta_construction(e::Expr)

Add a meta construction to the given expression `e`. This function creates a new `GraphPPL.MetaSpecification` object
and assigns it to the `__meta__` variable. It then evaluates the given expression `e` in the context of this new
`GraphPPL.MetaSpecification` object, and returns the resulting `GraphPPL.MetaSpecification` object.

# Arguments
- `e::Expr`: The expression to evaluate in the context of the new `GraphPPL.MetaSpecification` object.

# Returns
- `e::Expr`: The expression that will generate the `GraphPPL.MetaSpecification` object.
"""
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

"""
    convert_meta_variables(e::Expr)

Converts all variable references on the left hand side of a meta specification to IndexedVariable calls.

# Arguments
- `e::Expr`: The expression to convert.

# Returns
- `Expr`: The resulting expression with all variable references converted to IndexedVariable calls.

# Examples
"""

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

"""
    convert_meta_object(e::Expr)

Converts a variable meta or a factor meta call on the left hand side of a meta specification to a `GraphPPL.MetaObject`.

# Arguments
- `e::Expr`: The expression to convert.

# Returns
- `Expr`: The resulting expression with the variable reference or factor function call converted to a `GraphPPL.MetaObject`.

# Examples
"""
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

function meta_macro_interior(meta_body::Expr)
    meta_body = apply_pipeline(meta_body, (x) -> check_for_returns(x; tag = "meta"))
    meta_body = add_meta_construction(meta_body)
    meta_body = apply_pipeline(meta_body, create_submodel_meta)
    meta_body = apply_pipeline(meta_body, convert_meta_variables)
    meta_body = apply_pipeline(meta_body, convert_meta_object)
    return meta_body
end

macro meta(meta_body)
    return esc(GraphPPL.meta_macro_interior(meta_body))
end
