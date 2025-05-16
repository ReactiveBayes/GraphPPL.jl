struct VariableNodeLabel <: NodeLabelInterface
    id::Int
end

struct FactorNodeLabel <: NodeLabelInterface
    id::Int
end

get_id(label::VariableNodeLabel) = label.id
get_id(label::FactorNodeLabel) = label.id
