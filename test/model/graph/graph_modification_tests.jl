@testitem "GraphPPL.Model interface tests" setup = [ModelInterfaceTests] begin
    ModelInterfaceTests.model_interface_test_suite(GraphPPL.Model, GraphPPL.VariableNodeData, GraphPPL.FactorNodeData, GraphPPL.EdgeData)
end
