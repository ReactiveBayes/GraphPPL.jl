abstract type AbstractModelFilterPredicate end
struct FactorNodePredicate{N} <: AbstractModelFilterPredicate end

function apply(::FactorNodePredicate{N}, model, something) where {N}
    return apply(IsFactorNode(), model, something) && get_functional_form(get_factor_data(model, something)) ∈ get_aliases(model, N)
end

struct IsFactorNode <: AbstractModelFilterPredicate end

function apply(::IsFactorNode, model, something)
    return is_factor(model.graph, something.label)
end

struct VariableNodePredicate{V} <: AbstractModelFilterPredicate end

function apply(::VariableNodePredicate{N}, model, something) where {N}
    return apply(IsVariableNode(), model, something) && get_name(get_variable_data(model, something)) === N
end

struct IsVariableNode <: AbstractModelFilterPredicate end

function apply(::IsVariableNode, model, something)
    return is_variable(model.graph, something.label)
end

struct SubmodelPredicate{S, C} <: AbstractModelFilterPredicate end

function apply(::SubmodelPredicate{S, False}, model, something) where {S}
    # return fform(get_context(model[something])) === S
end

function apply(::SubmodelPredicate{S, True}, model, something) where {S}
    # return S ∈ fform.(path_to_root(getcontext(model[something])))
end

struct AndNodePredicate{L, R} <: AbstractModelFilterPredicate
    left::L
    right::R
end

function apply(and::AndNodePredicate, model, something)
    return apply(and.left, model, something) && apply(and.right, model, something)
end

struct OrNodePredicate{L, R} <: AbstractModelFilterPredicate
    left::L
    right::R
end

function apply(or::OrNodePredicate, model, something)
    return apply(or.left, model, something) || apply(or.right, model, something)
end

Base.:(|)(left::AbstractModelFilterPredicate, right::AbstractModelFilterPredicate) = OrNodePredicate(left, right)
Base.:(&)(left::AbstractModelFilterPredicate, right::AbstractModelFilterPredicate) = AndNodePredicate(left, right)

as_node(any) = FactorNodePredicate{any}()
as_node() = IsFactorNode()
as_variable(any) = VariableNodePredicate{any}()
as_variable() = IsVariableNode()
as_context(any; children = false) = SubmodelPredicate{any, typeof(static(children))}()

function Base.filter(predicate::AbstractModelFilterPredicate, model::FactorGraphModelInterface)
    return Iterators.filter(
        something -> apply(predicate, model, something), vcat(collect(get_variables(model)), collect(get_factors(model)))
    )
end