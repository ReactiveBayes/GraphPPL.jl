struct FactorizationConstraint{N, K}
    variables::NTuple{N, Symbol}
    factorization::NTuple{K, Tuple}
end

constraint_data(f::FactorizationConstraint) = f.factorization
variables(f::FactorizationConstraint) = f.variables

struct FunctionalFormConstraint
    variable::Symbol
    expression::Expr
end

constraint_data(f::FunctionalFormConstraint) = f.expression
variables(f::FunctionalFormConstraint) = (f.variable,)

const MaterializedConstraints = Union{FactorizationConstraint, FunctionalFormConstraint}

struct GeneralSubModelConstraints
    fform::Function
    constraints
end

struct SpecificSubModelConstraints 
    tag::Symbol
    constraints
end

struct Constraints
    factorization_constraints::Vector{FactorizationConstraint}
    functional_form_constraints::Vector{FunctionalFormConstraint}
    submodel_constraints::Vector{Union{GeneralSubModelConstraints, SpecificSubModelConstraints}}
end

SubModelConstraints(x::Symbol, constraints::Constraints) = SpecificSubModelConstraints(x, constraints)
SubModelConstraints(fform::Function, constraints::Constraints) = GeneralSubModelConstraints(fform, constraints)

all_constraints(c::Constraints) = vcat(c.factorization_constraints, c.functional_form_constraints)

apply!(model::Model, constraints::Constraints) = apply!(model, context(model), constraints)

function apply!(model::Model, context::Context, constraints::Constraints)
    for constraint in all_constraints(constraints)
        apply!(model, context, constraint)
    end
end

function references_existing_variables(context::Context, variables::NTuple{N, Symbol}) where N
    if all(var -> (haskey(context.individual_variables, var) || haskey(context.vector_variables, var) || haskey(context.tensor_variables, var)), variables)
        return Val(true)
    else
        return Val(false)
    end
end


apply!(model::Model, context::Context, constraint::MaterializedConstraints) = apply!(references_existing_variables(context, variables(constraint)), model, context, constraint)
apply!(::Val{false}, model::Model, context::Context, constraint::MaterializedConstraints) = error("Variables $(variables(constraint)) not found in context $context")


function apply!(::Val{true}, model::Model, context::Context, constraint::FactorizationConstraint)
    applicable_nodes = intersect(GraphPPL.neighbors.(Ref(model), getindex.(Ref(context), constraint.variables))...)
    if length(applicable_nodes) == 0
        @warn("No nodes found for constraint $constraint")
        return
    end
    for node in applicable_nodes
        store_constraint!(model, context, node, constraint)
    end
end

function apply!(::Val{true}, model::Model, context::Context, constraint::FunctionalFormConstraint)
    node = context[constraint.variable]
    store_constraint!(model, context, node, constraint)
end

store_constraint!(model::Model, context::Context, node::NodeLabel, constraint::FunctionalFormConstraint) = _store_constraint_data!(model, node, constraint.expression)


function store_constraint!(model::Model, context::Context, node::NodeLabel, constraint::FactorizationConstraint)
    interface_names = get_interface_names(model, context, node, constraint_data(constraint))
    _store_constraint_data!(model, node, interface_names)
end

function _store_constraint_data!(model::Model, node::NodeLabel, data)
    if node_options(model[node]) === nothing
        model[node].options = Dict{Symbol, Any}(:constraint => data)
    elseif haskey(node_options(model[node]), :constraint)
        error("Node $node already has a constraint applied, therefore constraint $data cannot be applied.")
    else
        model[node].options[:constraint] = data
    end
end

function get_interface_names(model::Model, ctx::Context, node::NodeLabel, t::Tuple)
    return map(x -> get_interface_names(model, ctx, node, x), t)
end

function get_interface_names(model::Model, ctx::Context, node::NodeLabel, t::Symbol)
    return model[node, ctx[t]]
end

function contains_array_variable(context::Context, variables::NTuple{N, Symbol}) where N
    # if all(var -> haskey(context, var), variables)
        if all(var -> haskey(context.individual_variables, var), variables)
            return Val(false)
        else
            return Val(true)
        end
    # end
end