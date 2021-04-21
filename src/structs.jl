# define an abstrat tree node type - concrete types are TreeSplit and TreeLeaf
abstract type Node{T<:AbstractFloat} end


# struct TreeNode{T<:AbstractFloat, S<:Integer, B<:Bool}
#     left::S
#     right::S
#     feat::S
#     cond::T
#     gain::T
#     pred::Vector{T}
#     split::B
# end

# TreeNode(left::S, right::S, feat::S, cond::T, gain::T, L::S) where {T<:AbstractFloat, S<:Integer} = TreeNode{L,T,S,Bool}(left, right, feat, cond, gain, zeros(T, L), true)
# TreeNode(pred::Vector{T}) where {T} = TreeNode(0, 0, 0, zero(T), zero(T), pred, false)

# single tree is made of a root node that containes nested nodes and leafs
mutable struct TrainNode{T<:AbstractFloat}
    gain::T
    𝑖::Union{Nothing, AbstractVector{UInt32}}
    ∑::Vector{T}
    h::Vector{Vector{T}}
    hL::Vector{Vector{T}}
    hR::Vector{Vector{T}}
    gains::Vector{Vector{T}}
end

function TrainNode(nvars, nbins, K, T)
    node = TrainNode{T}(
            zero(T),
            nothing,
            zeros(T, 2*K+1), 
            [zeros(T, (2*K+1) * nbins) for j in 1:nvars], 
            [zeros(T, (2*K+1) * nbins) for j in 1:nvars], 
            [zeros(T, (2*K+1) * nbins) for j in 1:nvars], 
            [zeros(T, nbins) for j in 1:nvars])
    
    return node
end

# single tree is made of a vectors of length num nodes
struct Tree{T<:AbstractFloat}
    feat::Vector{Int}
    cond_bin::Vector{UInt8}
    cond_float::Vector{T}
    gain::Vector{T}
    pred::Matrix{T}
    split::Vector{Bool}
end

Tree(x::Vector{T}) where T <: AbstractFloat = Tree(zeros(Int, 1), zeros(UInt8, 1), zeros(T, 1), zeros(T, 1), reshape(x, :, 1), zeros(Bool, 1))
Tree(depth, K, ::T) where {T <: AbstractFloat} = Tree(zeros(Int, 2^depth-1), zeros(UInt8, 2^depth-1), zeros(T, 2^depth-1), zeros(T, 2^depth-1), zeros(T, K, 2^depth-1), zeros(Bool, 2^depth-1))

# eval metric tracking
mutable struct Metric
    iter::Int
    metric::Float32
end
Metric() = Metric(0, Inf)

# gradient-boosted tree is formed by a vector of trees
struct GBTree{T<:AbstractFloat}
    trees::Vector{Tree{T}}
    params::EvoTypes
    metric::Metric
    K::Int
    levels
end
