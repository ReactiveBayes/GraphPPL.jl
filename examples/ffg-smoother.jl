using GraphPPL
using ForneyLab
using Distributions

# State prior

@RV x_0 ~ GaussianMeanVariance(m_x_0, v_x_0)

# Transition and observation model
x = Vector{Variable}(undef, n_samples)
y = Vector{Variable}(undef, n_samples)

x_t_min = x_0
for t = 1:n_samples
    @RV n_t ~ GaussianMeanVariance(0.0, 200.0) # observation noise
    @RV x[t] = x_t_min + 1.0
    @RV y[t] = x[t] + n_t

    # Data placeholder
    placeholder(y[t], :y, index=t)
    
    # Reset state for next step
    x_t_min = x[t]
end
