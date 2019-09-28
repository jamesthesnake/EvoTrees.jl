using DataFrames
using CSV
using Statistics
using Base.Threads: @threads
using StatsBase: sample
using StaticArrays
using Revise
using BenchmarkTools
using EvoTrees
using EvoTrees: get_gain, get_edges, binarize, get_max_gain, update_grads!, grow_tree, grow_gbtree, SplitInfo, SplitTrack, Tree, TrainNode, TreeNode, EvoTreeRegressor, predict, predict!, sigmoid
using EvoTrees: find_bags, find_split_turbo!, update_bags!

# prepare a dataset
# features = rand(100_000, 100)
features = rand(1_000, 10)
# x = cat(ones(20), ones(80)*2, dims=1)
# features =  hcat(x, features)

X = features
Y = rand(size(X, 1))
𝑖 = collect(1:size(X,1))
𝑗 = collect(1:size(X,2))

# train-eval split
𝑖_sample = sample(𝑖, size(𝑖, 1), replace = false)
train_size = 0.8
𝑖_train = 𝑖_sample[1:floor(Int, train_size * size(𝑖, 1))]
𝑖_eval = 𝑖_sample[floor(Int, train_size * size(𝑖, 1))+1:end]

X_train, X_eval = X[𝑖_train, :], X[𝑖_eval, :]
Y_train, Y_eval = Y[𝑖_train], Y[𝑖_eval]

# set parameters
params1 = EvoTreeRegressor(
    loss=:linear, metric=:mse,
    nrounds=10, nbins=32,
    λ = 0.0, γ=0.0, η=0.1,
    max_depth = 6, min_weight = 1.0,
    rowsample=1.0, colsample=1.0)

# initial info
δ, δ² = zeros(size(X, 1), params1.K), zeros(size(X, 1), params1.K)
𝑤 = ones(size(X, 1))
pred = zeros(size(Y, 1), params1.K)
# @time update_grads!(Val{params1.loss}(), pred, Y, δ, δ²)
update_grads!(params1.loss, params1.α, pred, Y, δ, δ², 𝑤)
∑δ, ∑δ², ∑𝑤 = vec(sum(δ, dims=1)), vec(sum(δ², dims=1)), sum(𝑤)
gain = get_gain(params1.loss, ∑δ, ∑δ², ∑𝑤, params1.λ)

# initialize train_nodes
train_nodes = Vector{TrainNode{Float64, BitSet, Array{Int64, 1}, Int}}(undef, 2^params1.max_depth-1)
for feat in 1:2^params1.max_depth-1
    train_nodes[feat] = TrainNode(0, fill(-Inf, params1.K), fill(-Inf, params1.K), -Inf, -Inf, BitSet([0]), [0])
    # train_nodes[feat] = TrainNode(0, -Inf, -Inf, -Inf, -Inf, Set([0]), [0], bags)
end

# initializde node splits info and tracks - colsample size (𝑗)
splits = Vector{SplitInfo{Float64, Int}}(undef, size(𝑗, 1))
for feat in 1:size(𝑗, 1)
    splits[feat] = SplitInfo{Float64, Int}(-Inf, zeros(params1.K), zeros(params1.K), 0.0, zeros(params1.K), zeros(params1.K), 0.0, -Inf, -Inf, 0, feat, 0.0)
end
tracks = Vector{SplitTrack{Float64}}(undef, size(𝑗, 1))
for feat in 1:size(𝑗, 1)
    tracks[feat] = SplitTrack{Float64}(zeros(params1.K), zeros(params1.K), 0.0, zeros(params1.K), zeros(params1.K), 0.0, -Inf, -Inf, -Inf)
end

@time edges = get_edges(X_train, params1.nbins)
@time X_bin = binarize(X_train, edges)
@time bags = Vector{Vector{BitSet}}(undef, size(𝑗, 1))
function prep(X_bin, bags)
    @threads for feat in 1:size(𝑗, 1)
         bags[feat] = find_bags(X_bin[:,feat])
    end
    return bags
end

@time bags = prep(X_bin, bags)
@time train_nodes[1] = TrainNode(1, ∑δ, ∑δ², ∑𝑤, gain, BitSet(𝑖), 𝑗)
@time tree = grow_tree(bags, δ, δ², 𝑤, params1, train_nodes, splits, tracks, edges, X_bin)
@btime tree = grow_tree($bags, $δ, $δ², $𝑤, $params1, $train_nodes, $splits, $tracks, $edges, $X_bin)
@time pred_train = predict(tree, X_train)
@btime pred_train = predict($tree, $X_train)

params1 = Params(:linear, 5, λ, γ, 1.0, 5, min_weight, rowsample, colsample, nbins)
@btime model = grow_gbtree($X_train, $Y_train, $params1, print_every_n = 1, metric=:mae)
@time pred_train = predict(model, X_train)

params1 = Params(:linear, 10, λ, γ, 0.1, 5, min_weight, rowsample, colsample, nbins)
@time model = grow_gbtree(X_train, Y_train, params1, X_eval = X_eval, Y_eval = Y_eval, print_every_n = 1, metric=:mae)
@btime model = grow_gbtree($X_train, $Y_train, $params1, X_eval = $X_eval, Y_eval = $Y_eval, print_every_n = 1, metric=:mae)

@time pred_train = predict(model, X_train)
sqrt(mean((pred_train .- Y_train) .^ 2))

#############################################
# Quantiles with turbo
#############################################

𝑖_set = BitSet(𝑖);
@time bags = prep(X_bin, bags);

feat = 1
typeof(bags[feat][1])
train_nodes[1] = TrainNode(1, ∑δ, ∑δ², ∑𝑤, gain, BitSet(𝑖), 𝑗)
find_split_turbo!(bags[feat], view(X_bin,:,feat), δ, δ², 𝑤, params1, splits[feat], tracks[feat], edges[feat], train_nodes[1].𝑖)

length(union(train_nodes[1].bags[1][1:13]...))
length(union(train_nodes[1].bags[1][1:13]...))
length(new_bags[2])
length(new_bags[2][1])
length(bags[2][32])
typeof(bags)
@btime update_bags_intersect($new_bags, $bags, $union(train_nodes[1].bags[1][1:13]...))
length(new_bags[2])
length(new_bags[2][2])
length(bags[2][1])

# extract the best feat from bags, and join all the underlying bins up to split point
best_bag = bags[1]
bins_L = union(best_bag[1:4]...)

function set_1(x, y)
    intersect!(x, y)
    return x
end

x = rand(UInt32, 100_000)
y = rand(x, 1000)

x_set = BitSet(x);
y_set = BitSet(y);

@btime set_1(x, y)
@btime set_1(x_set, y)


x = rand([1,2,3,4,5,6,7,8,9,10, 11,12], 1000)
x = rand(1000)
x_edges = quantile(x, (0:10)/10)
x_edges = unique(x_edges)
x_edges = x_edges[2:(end-1)]

length(x_edges)

x_bin = searchsortedlast.(Ref(x_edges), x) .+ 1
using StatsBase
x_map = countmap(x_bin)

x = reshape(x, (1000, 1))
x_edges = get_edges(x)
unique(quantile(view(X, :,i), (0:nbins)/nbins))[2:(end-1)]
x_bin = searchsortedlast.(Ref(x_edges[1]), x[:,1]) .+ 1
x_map = countmap(x_bin)

edges = get_edges(X, 32)
X_bin = zeros(UInt8, size(X))
@btime binindices(X[:,1], edges[1])
@btime X_bin = binarize(X, edges)

using StatsBase
x_map = countmap(x_bin)

x_edges[1]
