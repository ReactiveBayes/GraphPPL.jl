struct Constraints
    variable_constraints::Dict{Symbol,Expr}
end

function apply!(model::Model, context::Context, constraints::Constraints)
    for (var, expr) in constraints.variable_constraints
        node = model[context[var]]
        add_to_node_options!(node, GraphPPL.node_options(node), expr)
    end
end

function add_to_node_options!(
    node::VariableNodeData,
    node_options::AbstractDict,
    constraint::Expr,
)
    if haskey(node_options, :constraints)
        push!(node_options[:constraints], constraint)
    else
        node_options[:constraints] = [constraint]
    end
end

function add_to_node_options!(
    node::VariableNodeData,
    node_options::Nothing,
    constraint::Expr,
)
    node.options = Dict{Symbol,Any}(:constraints => [constraint])
end

apply!(model::Model, constraints::Constraints) =
    apply!(model, GraphPPL.context(model), constraints)
