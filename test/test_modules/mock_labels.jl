@testmodule MockLabels begin
    import GraphPPL: VariableNodeLabelInterface, FactorNodeLabelInterface
    struct MockVariableNodeLabel <: VariableNodeLabelInterface
        id::Int
    end
    struct MockFactorNodeLabel <: FactorNodeLabelInterface
        id::Int
    end
    struct MockFactorIdentifier{F}
        fform::F
        id::Int
    end
end