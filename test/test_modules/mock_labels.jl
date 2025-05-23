@testmodule MockLabels begin
    import GraphPPL
    struct MockVariableNodeLabel
        id::Int
    end
    struct MockFactorNodeLabel
        id::Int
    end
    struct MockFactorIdentifier{F}
        fform::F
        id::Int
    end
end