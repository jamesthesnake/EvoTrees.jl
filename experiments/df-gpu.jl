using Revise
using EvoTrees
using CSV
using DataFrames
using CategoricalArrays
import CUDA
using Base.Iterators: partition
using Base.Threads: nthreads, @threads
using BenchmarkTools
using Random: seed!

# using StatsBase
# x1 = rand(Bool, 10)
# nbins = 2
# edges = sort(unique(quantile(skipmissing(x1), (1:nbins-1) / nbins)))
# searchsortedfirst(edges, edges[1])
# searchsortedfirst(edges, 1.0)
# searchsortedfirst(edges, edges[9] + 0.01)

seed!(123)
nrounds = 20
nobs = Int(1e6)
nfeats_num = Int(100)
T = Float32
nthread = Base.Threads.nthreads()
@info "testing with: $nobs observations | $nfeats_num features."
x_train = rand(T, nobs, nfeats_num);
y_train = rand(T, nobs);

dtrain = DataFrame(x_train, :auto);
dtrain[:, :y] = y_train;

# dtrain[:, :x_cat_1] = rand(["lvl1", "lvl2", "lvl3"], nobs);
# transform!(dtrain, "x_cat_1" => (x -> categorical(x, ordered=false)) => "x_cat_1")

@info nthread
loss = "linear"
if loss == "linear"
    loss_evo = :mse
    metric_evo = :mae
elseif loss == "logistic"
    loss_evo = :logloss
    metric_evo = :logloss
end

hyper = EvoTreeRegressor(
    T=T,
    loss=loss_evo,
    nrounds=nrounds,
    alpha=0.5,
    lambda=0.0,
    gamma=0.0,
    eta=0.05,
    max_depth=6,
    min_weight=1.0,
    rowsample=0.5,
    colsample=0.5,
    nbins=64,
    rng=123,
)

target_name = "y"
device = "gpu"
CUDA.allowscalar(false)
@time model, cache = EvoTrees.init(hyper, dtrain, EvoTrees.GPU; target_name);
CUDA.@time model, cache = EvoTrees.init(hyper, dtrain, EvoTrees.GPU; target_name);

@time EvoTrees.grow_evotree!(model, cache, hyper, EvoTrees.GPU);
@btime EvoTrees.grow_evotree!(model, cache, hyper, EvoTrees.GPU);
@time m = fit_evotree(hyper, dtrain; target_name, device, verbosity=false);
# @btime fit_evotree(hyper, dtrain; target_name, verbosity = false);

@time m = fit_evotree(hyper, dtrain; target_name, deval=dtrain, metric=metric_evo, device, print_every_n=100, verbosity=false);
@btime m = fit_evotree(hyper, dtrain; target_name, deval=dtrain, metric=metric_evo, device, print_every_n=100, verbosity=false);

@time pred = m(dtrain);
@btime m($dtrain);