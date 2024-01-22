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

# include("constraints_macro.jl")
include("constraints_engine.jl")