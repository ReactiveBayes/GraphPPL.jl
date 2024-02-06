export MeanField, FullFactorization

using TupleTools
using StaticArrays
using Unrolled
using BitSetTuples
using MetaGraphsNext
using DataStructures
using Memoization

struct MeanField end

struct FullFactorization end

include("variational_constraints_macro.jl")
include("variational_constraints_engine.jl")

