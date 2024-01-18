@testitem "NodeCreatedByPlugin" begin 
    import GraphPPL: NodeCreatedByPlugin, NodeCreationOptions, materialize_plugin, EmptyCreatedBy

    plugin, options = @inferred(materialize_plugin(NodeCreatedByPlugin, NodeCreationOptions()))
    @test plugin.created_by == EmptyCreatedBy
    @test options == NodeCreationOptions()

    plugin, options = @inferred(materialize_plugin(NodeCreatedByPlugin, NodeCreationOptions(created_by = :(1 + 1))))
    @test plugin.created_by == :(1 + 1)
    @test options == NodeCreationOptions()

    plugin, options = @inferred(materialize_plugin(NodeCreatedByPlugin, NodeCreationOptions(created_by = :(x ~ Normal(0, 1)))))
    @test plugin.created_by == :(x ~ Normal(0, 1))
    @test options == NodeCreationOptions()
end