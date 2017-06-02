export TextConfig, save, load, normalize_text, tokenize, wtokenize

# const _PUNCTUACTION = """;:,.@#&\\-\"'/:*"""
const _PUNCTUACTION = """;:,.&\\-\"'/:*"""
const _SYMBOLS = "()[]¿?¡!{}~<>|"
const PUNCTUACTION  = _PUNCTUACTION * _SYMBOLS
# A symbol s in this list will be expanded to BLANK*s if the predecesor of s is neither s nor BLANK
# On changes from s to BLANK or [^s] it will produce also produce an extra BLANK
# Note that enabled del_punc will delete all these symbols without any of the previous expansions

const BLANK_LIST = string(' ', '\t', '\n', '\v', '\r')
const RE_USER = r"""@[^;:,.@#&\\\-\"'/:\*\(\)\[\]\¿\?\¡\!\{\}~\<\>\|\s]+"""
const RE_URL = r"(http|ftp|https)://\S+"
const BLANK = ' '
const PUNCTUACTION_BLANK = string(PUNCTUACTION, BLANK)

# SKIP_WORDS = set(["…", "..", "...", "...."])

type TextConfig
    lc::Bool
    del_diac::Bool
    del_dup::Bool
    del_punc::Bool
    del_num::Bool
    del_url::Bool
    del_usr::Bool
    qlist::Vector{Int}
    nlist::Vector{Int}
    skiplist::Vector{Tuple{Int,Int}}
end

TextConfig() = TextConfig(true, true, false, false, true, true, true, [], [1], [])
# TextConfig(qlist, nlist, skiplist) = TextConfig(true, true, false, false, true, true, qlist, nlist, skiplist)

function save(ostream, config::TextConfig)
    write(ostream, JSON.json(config), '\n')
end

function load(istream, ::Type{TextConfig})
    obj = TextConfig()
    line = readline(istream)

    for (k, v) in JSON.parse(line)
        if k in ("qlist", "nlist")
            v = Int[x for x in v]
        elseif k == "skiplist"
            v = Tuple{Int,Int}[(x[1], x[2]) for x in v]
        end
        setfield!(obj, Symbol(k), v)
    end

    obj
end

function normalize_text(text::String, config::TextConfig, findwords=false)::Vector{Char}
    if config.lc
        text = lowercase(text)
    end

    if config.del_url
        text = replace(text, RE_URL, s"")
    end

    if config.del_usr
        text = replace(text, RE_USER, s"")
    end

    L = Char[BLANK]
    prev = BLANK

    @inbounds for u in normalize_string(text, :NFD)
        if config.del_diac
            o = Int(u)
            0x300 <= o && o <= 0x036F && continue
        end

        if u in BLANK_LIST
            u = BLANK
        elseif config.del_dup && prev == u
            continue
        elseif config.del_punc && u in PUNCTUACTION
            prev = u
            continue
        elseif config.del_num && isdigit(u)
            continue
        # elseif findwords && prev in PUNCTUACTION && !(u in PUNCTUACTION)
        #     push!(L, BLANK)
        # elseif findwords && !(prev in PUNCTUACTION_BLANK) && u in PUNCTUACTION
        #     push!(L, BLANK)
        end

        prev = u
        push!(L, u)
    end
    push!(L, BLANK)

    L
end

function wtokenize(text::Vector{Char})
    n = length(text)
    L = String[]
    W = Char[]
    @inbounds for i in 1:n
        c = text[i]

        if c == BLANK
            length(W) == 0 && continue

            push!(L, W |> join)
            W = Char[]

        elseif i > 1
            if text[i-1] in PUNCTUACTION && !(c in PUNCTUACTION)
                push!(L, W |> join)
                W = Char[c]
                continue
            elseif !(text[i-1] in PUNCTUACTION_BLANK) && c in PUNCTUACTION
                push!(L, W |> join)
                W = Char[c]
                continue
            else
                push!(W, c)
            end
        else
            push!(W, c)
        end
    end

    length(W) > 0 && push!(L, W |> join)
    return L
end

function tokenize(text::String, config::TextConfig)
    tokenize(normalize_text(text, config), config)
end

function tokenize(text::Vector{Char}, config::TextConfig)
    n = length(text)
    L = String[]

    @inbounds for q in config.qlist
        for i in 1:(n - q + 1)
            w = text[i:i+q-1] |> join
            push!(L, w)
        end
    end

    if length(config.nlist) > 0 || length(config.skiplist) > 0
        ltext = wtokenize(text)
        n = length(ltext)

        @inbounds for q in config.nlist
            for i in 1:(n - q + 1)
                wl = ltext[i:i+q-1]
                push!(L, join(wl, BLANK))
            end
        end
        
        @inbounds for (qsize, skip) in config.skiplist
            for start in 1:(n - (qsize + (qsize - 1) * skip) + 1)
                if qsize == 2
                    t = string(ltext[start], BLANK, ltext[start + 1 + skip])
                else
                    t = join([ltext[start + i * (1+skip)] for i in 0:(qsize-1)], BLANK)
                end
                push!(L, t)
            end
        end
    end

    L
end
