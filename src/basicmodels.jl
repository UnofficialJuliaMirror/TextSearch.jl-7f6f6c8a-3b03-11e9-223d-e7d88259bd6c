import SimilaritySearch: fit
export VectorModel, fit, vectorize, TfidfModel, TfModel, IdfModel, FreqModel

"""
    abstract type Model

An abstract type that represents a weighting model
"""
abstract type Model end

"""
    mutable struct VectorModel

Models a text through a vector space
"""
mutable struct VectorModel <: Model
    config::TextConfig
    vocab::BOW
    maxfreq::Int
    n::Int
end


"""
    fit(::Type{VectorModel}, config::TextConfig, corpus::AbstractVector; lower=0, higher=1.0)

Trains a vector model using the text preprocessing configuration `config` and the input corpus. It also allows for filtering
tokens with low and high number of occurrences. `lower` is specified as an integer and `higher` as a proportion between
the frequency of the current token and the maximum frequency of the model.
"""
function fit(::Type{VectorModel}, config::TextConfig, corpus::AbstractVector; lower=0, higher=1.0)
    voc = BOW()
    n = 0
    maxfreq = 0.0
    println(stderr, "fitting VectorModel with $(length(corpus)) items")

    for data in corpus
        n += 1
        _, maxfreq = compute_bow(config, data, voc)
        n % 1000 == 0 && print(stderr, "x")
        n % 100000 == 0 && println(stderr, " $(n/length(corpus))")
    end

    println(stderr, "finished VectorModel: $n processed items")
    if lower != 0 || higher != 1.0
        voc, maxfreq = filter_vocab(voc, maxfreq, lower, higher)
    end

    VectorModel(config, voc, Int(maxfreq), n)
end

"""
    filter_vocab(vocab, maxfreq, lower::int, higher::Float64=1.0)

Drops terms in the vocabulary with less than `low` and and higher than `high` frequences.
- `lower` is specified as an integer, and must be read as the lower accepted frequency (lower frequencies will be dropped)
- `higher` is specified as a float, 0 < higher <= 1.0; it is readed as the higher frequency that is preserved (it a proportion of the maximum frequency)

"""
function filter_vocab(vocab::BOW, maxfreq, lower::Int, higher::Float64=1.0)
    X = BOW()

    for (t, freq) in vocab
        if freq < lower || freq > maxfreq * higher
            continue
        end

        X[t] = freq
    end

    X, floor(Int, maxfreq * higher)
end

"""
    update!(a::VectorModel, b::VectorModel)

Updates `a` with `b` inplace; returns `a`.
"""
function update!(a::VectorModel, b::VectorModel)
    i = 0
    for (k, freq1) in b.vocab
        i += 1
        freq2 = get(a, k, 0.0)
        if freq1 == 0.0
            a[k] = freq1
        else
            a[k] = freq1 + freq2
        end
    end

    a.maxfreq = max(a.maxfreq, b.maxfreq)
    a.n += b.n
    a
end

abstract type TfidfModel end
abstract type TfModel end
abstract type IdfModel end
abstract type FreqModel end

"""
    vectorize(model::VectorModel, weighting::Type, data, modify_bow!::Function=identity)::Dict{Symbol, Float64}

Computes `data`'s weighted bag of words using the given model and weighting scheme.
It takes a function `modify_bow!` to modify the bag
before applying the weighting scheme; `modify_bow!` defaults to `identity`.
"""
function vectorize(model::VectorModel, weighting::Type, data, modify_bow!::Function=identity)::BOW
    W = BOW()
    bag, maxfreq = compute_bow(model.config, data)
    bag = modify_bow!(bag)
    for (token, freq) in bag
        global_freq = get(model.vocab, token, 0.0)
        if global_freq > 0.0
            W[token] = _weight(weighting, freq, maxfreq, model.n, global_freq)
        end
    end
  
    W
end

vectorize(model::VectorModel, data, modify_bow!::Function=identity) = vectorize(model, TfidfModel, data, modify_bow!)

function broadcastable(model::VectorModel)
    (model,)
end

"""
    _weight(::Type{T}, freq::Integer, maxfreq::Integer, n::Integer, global_freq::Integer)::Float64

Computes a weight for the given stats using scheme T
"""
function _weight(::Type{TfidfModel}, freq::Real, maxfreq::Real, n::Real, global_freq::Real)::Float64
    (freq / maxfreq) * log(2, 1 + n / global_freq)
end

function _weight(::Type{TfModel}, freq::Real, maxfreq::Real, n::Real, global_freq::Real)::Float64
    freq / maxfreq
end

function _weight(::Type{IdfModel}, freq::Real, maxfreq::Real, n::Real, global_freq::Real)::Float64
    log(2, n / global_freq)
end

function _weight(::Type{FreqModel}, freq::Real, maxfreq::Real, n::Real, global_freq::Real)::Float64
    freq
end
