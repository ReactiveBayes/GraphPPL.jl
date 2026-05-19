using Test
using GraphPPL
using Distributions

@model function test_colon_bug(media)
    for g in 1:2
        for i in 1:3
            media_effect[g, i] := media[g, :, i]
        end
    end
end

@testset "Colon index in middle of indices" begin
    media_data = rand(2, 5, 3)
    model = create_model(test_colon_bug(media = media_data))
    @test model !== nothing
end
