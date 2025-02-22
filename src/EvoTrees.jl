module EvoTrees

export fit_evotree
export EvoTreeRegressor,
    EvoTreeCount,
    EvoTreeClassifier,
    EvoTreeMLE,
    EvoTreeGaussian,
    EvoTree,
    Random

using Base.Threads: @threads, @spawn, nthreads, threadid
using Statistics
using StatsBase: sample, sample!, quantile, proportions
using Random
using Random: seed!, AbstractRNG
using Distributions
using Tables
using CategoricalArrays
using Tables
using CUDA
using CUDA: @allowscalar, allowscalar
using BSON

using NetworkLayout
using RecipesBase

using MLJModelInterface
import MLJModelInterface as MMI
import MLJModelInterface: fit, update, predict, schema
import Base: convert

include("models.jl")

include("structs.jl")
include("loss.jl")
include("eval.jl")
include("predict.jl")
include("init.jl")
include("subsample.jl")
include("fit-utils.jl")
include("fit.jl")

include("gpu/loss.jl")
include("gpu/eval.jl")
include("gpu/predict.jl")
include("gpu/init.jl")
include("gpu/subsample.jl")
include("gpu/fit-utils.jl")
include("gpu/fit.jl")

include("callback.jl")
include("importance.jl")
include("plot.jl")
include("MLJ.jl")

function save(model::EvoTree, path)
    BSON.bson(path, Dict(:model => model))
end

function load(path)
    m = BSON.load(path, @__MODULE__)
    return m[:model]
end

end # module
