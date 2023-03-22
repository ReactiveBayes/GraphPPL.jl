
"""
    write_meta_specification(backend, entries, options)
"""
function write_meta_specification end

"""
    write_meta_specification_options(backend, options)
"""
function write_meta_specification_options end

"""
    write_meta_specification_entry(backend, F, N, meta)
"""
function write_meta_specification_entry end

struct MetaSpecificationLHSInfo
    hash::UInt
    checkname::Symbol
end

function generate_meta_expression(backend, meta_options, meta_specification)

    if isblock(meta_specification)
        generatedfname = gensym(:constraints)
        generatedfbody = :(function $(generatedfname)()
            $meta_specification
        end)
        return :($(generate_meta_expression(backend, meta_options, generatedfbody))())
    end

    @capture(
        meta_specification,
        (function cs_name_(cs_args__; cs_kwargs__)
            cs_body_
        end) | (function cs_name_(cs_args__)
            cs_body_
        end)
    ) || error("Meta specification language requires full function definition")

    cs_args = cs_args === nothing ? [] : cs_args
    cs_kwargs = cs_kwargs === nothing ? [] : cs_kwargs
    cs_options = write_meta_specification_options(backend, meta_options)

    lhs_dict = Dict{UInt,MetaSpecificationLHSInfo}()

    meta_spec_symbol = gensym(:meta)
    meta_spec_symbol_init = :($meta_spec_symbol = ())

    cs_body = postwalk(cs_body) do expression
        if @capture(expression, f_(args__) -> meta_)

            if !issymbol(f) || any(a -> !issymbol(a), args)
                error("Invalid meta specification $(expression)")
            end

            lhs = :($f($(args...)))
            lhs_hash = hash(lhs)
            lhs_info = if haskey(lhs_dict, lhs_hash)
                lhs_dict[lhs_hash]
            else
                lhs_checkname = gensym(f)
                lhs_info = MetaSpecificationLHSInfo(lhs_hash, lhs_checkname)
                lhs_dict[lhs_hash] = lhs_info
            end

            lhs_checkname = lhs_info.checkname
            error_msg = "Meta specification $lhs has been redefined"
            meta_entry = write_meta_specification_entry(
                backend,
                QuoteNode(f),
                :(($(map(QuoteNode, args)...),)),
                meta,
            )

            return quote
                ($lhs_checkname) && error($error_msg)
                $meta_spec_symbol = ($meta_spec_symbol..., $meta_entry)
                $lhs_checkname = true
            end
        end
        return expression
    end

    lhs_checknames_init = map(collect(pairs(lhs_dict))) do pair
        lhs_info = last(pair)
        lhs_checkname = lhs_info.checkname
        return quote
            $lhs_checkname = false
        end
    end

    ret_meta_specification = write_meta_specification(backend, meta_spec_symbol, cs_options)

    res = quote
        function $cs_name($(cs_args...); $(cs_kwargs...))
            $meta_spec_symbol_init
            $(lhs_checknames_init...)
            $cs_body
            $ret_meta_specification
        end
    end

    return esc(res)
end
