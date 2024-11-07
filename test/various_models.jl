using RxInfer
using Distributions
using Random
using GraphPlot
using Graphs
using MetaGraphsNext
using GraphPPL
using GraphViz
using Dictionaries
using Plots
using StableRNGs
using LinearAlgebra
using StatsPlots
using LaTeXStrings
using DataFrames
using CSV
using GLM
using Dates

using Cairo # necessary for draw PDF...
using Fontconfig # necessary for draw PDF...
using Compose # necessary for draw PDF...

include("../ext/GraphPPLGraphVizExt.jl") # ??

using .GraphPPLGraphVizExt: generate_dot, show_gv, dot_string_to_pdf


## COIN TOSS MODEL
# GraphPPL.jl export `@model` macro for model specification
# It accepts a regular Julia function and builds an FFG under the hood
@model function coin_model(y, a, b)
    # We endow θ parameter of our model with some prior
    θ ~ Beta(a, b)
    # or, in this particular case, the `Uniform(0.0, 1.0)` prior also works:
    # θ ~ Uniform(0.0, 1.0)

    # We assume that outcome of each coin flip is governed by the Bernoulli distribution
    for i in eachindex(y)
        y[i] ~ Bernoulli(θ)
    end
end

# condition the model on some observed data
conditioned = coin_model(a = 2.0, b = 7.0) | (y = [ true, false, true ], )

# `Create` the actual graph of the model conditioned on the data
rxi_model = RxInfer.create_model(conditioned)

gppl_model = RxInfer.getmodel(rxi_model)

# Extract the MetaGraphsNext graph
meta_graph = gppl_model.graph

## NEATO LAYOUT 
# gen_dot_result_coin_simple = generate_dot(
#     model_graph = gppl_model,
#     strategy = :simple,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "neato",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# gen_dot_result_coin_bfs = generate_dot(
#     model_graph = gppl_model,
#     strategy = :bfs,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "neato",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# dot_string_to_pdf(gen_dot_result_coin_simple, "test_imgs/neato_layout/coin_model_simple_itr_VM.pdf")
# dot_string_to_pdf(gen_dot_result_coin_bfs, "test_imgs/neato_layout/coin_model_bfs_itr_VM.pdf")

# ## DOT Layout
# gen_dot_result_coin_simple = generate_dot(
#     model_graph = gppl_model,
#     strategy = :simple,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "dot",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# gen_dot_result_coin_bfs = generate_dot(
#     model_graph = gppl_model,
#     strategy = :bfs,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "dot",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# dot_string_to_pdf(gen_dot_result_coin_simple, "test_imgs/DOT_layout/coin_model_simple_itr_VM.pdf")
# dot_string_to_pdf(gen_dot_result_coin_bfs, "test_imgs/DOT_layout/coin_model_bfs_itr_VM.pdf")



































# ## LINEAR REGRESSION MODEL
# function generate_data(a, b, v, nr_samples; rng=StableRNG(1234))
#     x = float.(collect(1:nr_samples))
#     y = a .* x .+ b .+ randn(rng, nr_samples) .* sqrt(v)
#     return x, y
# end

# x_data, y_data = generate_data(0.5, 25.0, 1.0, 250)

# @model function linear_regression(x, y)
#     a ~ Normal(mean = 0.0, variance = 1.0)
#     b ~ Normal(mean = 0.0, variance = 100.0)    
#     y .~ Normal(mean = a .* x .+ b, variance = 1.0)
# end

# # Prepare the data
# x_data = [1.0, 2.0, 3.0, 4.0, 5.0]  # example input data
# y_data = [2.0, 4.1, 6.2, 8.3, 10.4];  # example observed data

# linr_conditioned = linear_regression() | (x = x_data, y = y_data, )

# # Create the RxInfer model and inject the data
# linr_rxi_model = GraphPPL.create_model(linr_conditioned)

# # Extract the GraphPPL.Model
# linr_gppl_model = RxInfer.getmodel(linr_rxi_model)

# # Extract the MetaGraphsNext meta graph
# linr_meta_graph = linr_gppl_model.graph


# ## NEATO LAYOUT
# gen_dot_result_linr_simple = generate_dot(
#     model_graph = linr_gppl_model,
#     strategy = :simple,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "neato",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# gen_dot_result_linr_bfs = generate_dot(
#     model_graph = linr_gppl_model,
#     strategy = :bfs,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "neato",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# dot_string_to_pdf(gen_dot_result_linr_simple, "test_imgs/neato_layout/gen_dot_result_linr_simple_itr_VM.pdf")
# dot_string_to_pdf(gen_dot_result_linr_bfs, "test_imgs/neato_layout/gen_dot_result_linr_bfs_itr_VM.pdf")


# ## DOT LAYOUT
# gen_dot_result_linr_simple = generate_dot(
#     model_graph = linr_gppl_model,
#     strategy = :simple,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "dot",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# gen_dot_result_linr_bfs = generate_dot(
#     model_graph = linr_gppl_model,
#     strategy = :bfs,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "dot",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# dot_string_to_pdf(gen_dot_result_linr_simple, "test_imgs/DOT_layout/gen_dot_result_linr_simple_itr_VM.pdf")
# dot_string_to_pdf(gen_dot_result_linr_bfs, "test_imgs/DOT_layout/gen_dot_result_linr_bfs_itr_VM.pdf")










































# ## HIDDEN MARKOV MODEL WITH CONTROL
# @model function hidden_markov_model(x)
#     B ~ MatrixDirichlet(ones(3, 3))
#     A ~ MatrixDirichlet([10.0 1.0 1.0; 
#                          1.0 10.0 1.0; 
#                          1.0 1.0 10.0 ])    
#     s₀ ~ Categorical(fill(1.0/3.0, 3))
    
#     sₖ₋₁ = s₀
#     for k in eachindex(x)
#         s[k] ~ Transition(sₖ₋₁, B)
#         x[k] ~ Transition(s[k], A)
#         sₖ₋₁ = s[k]
#     end
# end

# hmm_conditioned = hidden_markov_model() | (x = [[1.0, 0.0, 0.0], [0.0, 0.0, 1.0]],)
# hmm_rxi_model = RxInfer.create_model(hmm_conditioned)
# hmm_gppl_model = RxInfer.getmodel(hmm_rxi_model)
# hmm_meta_graph = hmm_gppl_model.graph

## NEATO LAYOUT
# gen_dot_result_hmm_simple = generate_dot(
#     model_graph = hmm_gppl_model,
#     strategy = :simple,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "neato",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# gen_dot_result_hmm_bfs = generate_dot(
#     model_graph = hmm_gppl_model,
#     strategy = :bfs,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "neato",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# dot_string_to_pdf(gen_dot_result_hmm_simple, "test_imgs/neato_layout/gen_dot_result_hmm_simple_itr_VM.pdf")
# dot_string_to_pdf(gen_dot_result_hmm_bfs, "test_imgs/neato_layout/gen_dot_result_hmm_bfs_itr_VM.pdf")

# # DOT LAYOUT
# gen_dot_result_hmm_simple = generate_dot(
#     model_graph = hmm_gppl_model,
#     strategy = :simple,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "dot",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# gen_dot_result_hmm_bfs = generate_dot(
#     model_graph = hmm_gppl_model,
#     strategy = :bfs,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "dot",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# dot_string_to_pdf(gen_dot_result_hmm_simple, "test_imgs/DOT_layout/gen_dot_result_hmm_simple_itr_VM.pdf")
# dot_string_to_pdf(gen_dot_result_hmm_bfs, "test_imgs/DOT_layout/gen_dot_result_hmm_bfs_itr_VM.pdf")















































# TIME-VARYING AUTOREGRESSINVE MODEL
@model function lar_model(
    x, ##. data/observations 
    𝚃ᴬᴿ, ##. Uni/Multi variate 
    Mᴬᴿ, ##. AR order
    vᵤ, ##. unit vector 
    τ) ##. observation precision     
    ## Priors
    γ  ~ Gamma(α = 1.0, β = 1.0) ##. for transition precision    
    if 𝚃ᴬᴿ === Multivariate
        θ  ~ MvNormal(μ = zeros(Mᴬᴿ), Λ = diageye(Mᴬᴿ)) ##.kw μ,Λ only work inside macro
        s₀ ~ MvNormal(μ = zeros(Mᴬᴿ), Λ = diageye(Mᴬᴿ)) ##.kw μ,Λ only work inside macro
    else ## Univariate
        θ  ~ Normal(μ = 0.0, γ = 1.0)
        s₀ ~ Normal(μ = 0.0, γ = 1.0)
    end
    sₜ₋₁ = s₀
    for t in eachindex(x)
        s[t] ~ AR(sₜ₋₁, θ, γ) #.Eq (2b)
        if 𝚃ᴬᴿ === Multivariate
            x[t] ~ Normal(μ = dot(vᵤ, s[t]), γ = τ) #.Eq (2c)
        else
            x[t] ~ Normal(μ = vᵤ*s[t], γ = τ) #.Eq (2c)
        end
        sₜ₋₁ = s[t]
    end
end

𝚃ᴬᴿ = Univariate
m = 1
τ̃ = 0.001 ## assumed observation precision
lar_conditioned = lar_model(
    𝚃ᴬᴿ=𝚃ᴬᴿ, 
    Mᴬᴿ=m, 
    vᵤ=ReactiveMP.ar_unit(𝚃ᴬᴿ, m), 
    τ=τ̃
) | (x = [266.0, 145.0, 183.0],)

lar_rxi_model = RxInfer.create_model(lar_conditioned)
lar_gppl_model = RxInfer.getmodel(lar_rxi_model)
lar_meta_graph = lar_gppl_model.graph

# ## NEATO LAYOUT
# gen_dot_result_lar_simple = generate_dot(
#     model_graph = lar_gppl_model,
#     strategy = :simple,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "neato",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# gen_dot_result_lar_bfs = generate_dot(
#     model_graph = lar_gppl_model,
#     strategy = :bfs,
#     font_size = 12,
#     edge_length = 1.0,
#     layout = "neato",
#     overlap = false,
#     width = 10.0, 
#     height = 10.0 
# )

# dot_string_to_pdf(gen_dot_result_lar_simple, "test_imgs/neato_layout/gen_dot_result_lar_simple_itr_VM.pdf")
# dot_string_to_pdf(gen_dot_result_lar_bfs, "test_imgs/neato_layout/gen_dot_result_lar_bfs_itr_VM.pdf")


## DOT LAYOUT
gen_dot_result_lar_simple = generate_dot(
    model_graph = lar_gppl_model,
    strategy = :simple,
    font_size = 12,
    edge_length = 1.0,
    layout = "dot",
    overlap = false,
    width = 10.0, 
    height = 10.0 
)

gen_dot_result_lar_bfs = generate_dot(
    model_graph = lar_gppl_model,
    strategy = :bfs,
    font_size = 12,
    edge_length = 1.0,
    layout = "dot",
    overlap = false,
    width = 10.0, 
    height = 10.0 
)

dot_string_to_pdf(gen_dot_result_lar_simple, "test_imgs/DOT_layout/gen_dot_result_lar_simple_itr_VM.pdf")
dot_string_to_pdf(gen_dot_result_lar_bfs, "test_imgs/DOT_layout/gen_dot_result_lar_bfs_itr_VM.pdf")