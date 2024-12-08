using GraphPPL
using RxInfer
using Distributions
using Random
using Cairo
using Graphs
using MetaGraphsNext
using Dictionaries
using StableRNGs
using LinearAlgebra
using StatsPlots 
using DataFrames 
using CSV
using GLM


#### COIN TOSS MODEL ####
@model function coin_model(y, a, b)
    θ ~ Beta(a, b)
    for i in eachindex(y)
        y[i] ~ Bernoulli(θ)
    end
end

# create the specified model and return the GraphPPL.Model
function create_coin_model()
    conditioned = coin_model(a = 2.0, b = 7.0) | (y = [ true, false, true ], )
    rxi_model = RxInfer.create_model(conditioned)
    return RxInfer.getmodel(rxi_model)
end


#### HIDDEN MARKOV MODEL ####
# Taken from: https://learnableloop.com/posts/FFGViz5_KE.html
@model function hidden_markov_model(x)
    B ~ MatrixDirichlet(ones(3, 3))
    A ~ MatrixDirichlet([10.0 1.0 1.0; 
                         1.0 10.0 1.0; 
                         1.0 1.0 10.0 ])    
    s₀ ~ Categorical(fill(1.0/3.0, 3))
    
    sₖ₋₁ = s₀
    for k in eachindex(x)
        s[k] ~ Transition(sₖ₋₁, B)
        x[k] ~ Transition(s[k], A)
        sₖ₋₁ = s[k]
    end
end


# create the specified model and return the GraphPPL.Model
# Taken from: https://learnableloop.com/posts/FFGViz5_KE.html
function create_hmm_model()
    hmm_conditioned = hidden_markov_model() | (x = [[1.0, 0.0, 0.0], [0.0, 0.0, 1.0]],)
    hmm_rxi_model = RxInfer.create_model(hmm_conditioned)
    return RxInfer.getmodel(hmm_rxi_model)
end


#### LAR MODEL ####
# Taken from: https://learnableloop.com/posts/FFGViz5_KE.html
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

# create the specified model and return the GraphPPL.Model
# Taken from: https://learnableloop.com/posts/FFGViz5_KE.html
function create_lar_model()
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
    return RxInfer.getmodel(lar_rxi_model)
end


#### DRONE NAV MODEL ####
# Taken from: https://learnableloop.com/posts/FFGViz5_KE.html
@model function dronenav_model(x, mᵤ, Vᵤ, mₓ, Vₓ, mₛ₍ₜ₋₁₎, Vₛ₍ₜ₋₁₎, T, Rᵃ)
    ## Transition function
    g = (sₜ₋₁::AbstractVector) -> begin
        sₜ = similar(sₜ₋₁) ## Next state
        sₜ = Aᵃ(sₜ₋₁, 1.0) + sₜ₋₁
        return sₜ
    end
    
    ## Function for modeling turn/yaw control
    h = (u::AbstractVector) -> Rᵃ(u[1])

    _γ = 1e4 ## transition precision (system noise)
    _ϑ = 1e-4 ## observation variance (observation noise)
    
    Γ = _γ*diageye(4) ## Transition precision
    𝚯 = _ϑ*diageye(4) ## Observation variance
    
    ## sₜ₋₁ ~ MvNormal(mean=mₛ₍ₜ₋₁₎, cov=Vₛ₍ₜ₋₁₎)
    s₀ ~ MvNormal(mean=mₛ₍ₜ₋₁₎, cov=Vₛ₍ₜ₋₁₎)
    ## sₖ₋₁ = sₜ₋₁
    sₖ₋₁ = s₀
    
    local s

    for k in 1:T
        ## Control
        u[k] ~ MvNormal(mean=mᵤ[k], cov=Vᵤ[k])
        hIuI[k] ~ h(u[k]) where { meta=DeltaMeta(method=Unscented()) }

        ## State transition
        gIsI[k] ~ g(sₖ₋₁) where { meta=DeltaMeta(method=Unscented()) }
        ghSum[k] ~ gIsI[k] + hIuI[k]#.
        s[k] ~ MvNormal(mean=ghSum[k], precision=Γ)

        ## Likelihood of future observations
        x[k] ~ MvNormal(mean=s[k], cov=𝚯)

        ## Target/Goal prior
        x[k] ~ MvNormal(mean=mₓ[k], cov=Vₓ[k])

        sₖ₋₁ = s[k]
    end
    return (s, )
end

# create the specified model and return the GraphPPL.Model
# Taken from: https://learnableloop.com/posts/FFGViz5_KE.html
function create_drone_nav_model()
    _Fᴱⁿᵍᴸⁱᵐⁱᵗ = 0.1

    function Rᵃ(a::Real) ## turn/yaw rate
        b = [ 0.0, 0.0, 1.0, 0.0 ]
        return b*_Fᴱⁿᵍᴸⁱᵐⁱᵗ*tanh(a)
    end
    ## Rᵃ(0.25)

    # _γ = 1e4 ## transition precision (system noise) # OG LOCATION 
    # _ϑ = 1e-4 ## observation variance (observation noise) # OG LOCATION 

    ## T =_Tᵃⁱ,
    ## T =100
    T =3
    Rᵃ=Rᵃ

    mᵤ = Vector{Float64}[ [0.0] for k=1:T ] ##Set control priors
    ξ = 0.1
    Ξ  = fill(ξ, 1, 1) ##Control prior variance
    Vᵤ = Matrix{Float64}[ Ξ for k=1:T ]
    mₓ      = [zeros(4) for k=1:T]
    x₊ = [0.0, 0.0, 0.0*π, 0.1] ## Target/Goal state
    mₓ[end] = x₊ ##Set prior mean to reach target/goal at t=T
    Vₓ      = [huge*diageye(4) for k=1:T]
    σ = 1e-4
    Σ       = σ*diageye(4) ##Target/Goal prior variance
    Vₓ[end] = Σ ##Set prior variance to reach target/goal at t=T
    s₀ = [8.0, 8.0, -0.1, 0.1] ## initial state
    mₛ₍ₜ₋₁₎ = s₀
    Vₛ₍ₜ₋₁₎ = tiny*diageye(4)

    drone_conditioned = dronenav_model(
        mᵤ= mᵤ, 
        Vᵤ= Vᵤ, 
        mₓ= mₓ, 
        Vₓ= Vₓ,
        mₛ₍ₜ₋₁₎= mₛ₍ₜ₋₁₎,
        Vₛ₍ₜ₋₁₎= Vₛ₍ₜ₋₁₎,
        T=T, 
        Rᵃ=Rᵃ
    ) | (x = [ [8.099, 7.990, -0.109, 0.1],  [8.198, 7.979, -0.119, 0.1],  [8.298, 7.967, -0.129, 0.1]],)
    ## ) | (x = [ [8.099, 7.990, -0.109],  [8.198, 7.979, -0.119],  [8.298, 7.967, -0.129]],)

    drone_rxi_model = RxInfer.create_model(drone_conditioned)

    return RxInfer.getmodel(drone_rxi_model)
end