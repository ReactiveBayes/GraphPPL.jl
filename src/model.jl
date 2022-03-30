export @model

import MacroTools: @capture, postwalk, prewalk, walk

function conditioned_walk(f, condition_skip, condition_apply, x) 
    walk(x, x -> condition_skip(x) ? x : condition_apply(x) ? f(x) : conditioned_walk(f, condition_skip, condition_apply, x), identity)
end

"""
    fquote(expr)

This function forces `Expr` or `Symbol` to be quoted.
"""
fquote(expr::Symbol) = Expr(:quote, expr)
fquote(expr::Int)    = expr
fquote(expr::Expr)   = expr

"""
    ensure_type
"""
ensure_type(x::Type) = x
ensure_type(x)       = error("Valid type object was expected but '$x' has been found")

is_kwargs_expression(x)       = false
is_kwargs_expression(x::Expr) = x.head === :parameters

"""
    parse_varexpr(varexpr)

This function parses variable id and returns a tuple of 3 different representations of the same variable 
1. Original expression
2. Short variable identificator (used in variables lookup table)
3. Full variable identificator (used in model as a variable id)
"""
function parse_varexpr(varexpr::Symbol)
    varexpr  = varexpr
    short_id = varexpr
    full_id  = varexpr
    return varexpr, short_id, full_id
end

function parse_varexpr(varexpr::Expr)

    # TODO: It might be handy to have this feature in the future for e.g. interacting with UnPack.jl package
    # TODO: For now however we fallback to a more informative error message since it is not obvious how to parse such expressions yet
    @capture(varexpr, (tupled_ids__, )) && 
        error("Multiple variable declarations, definitions and assigments are forbidden within @model macro. Try to split $(varexpr) into several independent statements.")

    @capture(varexpr, id_[idx__]) || 
        error("Variable identificator can be in form of a single symbol (x ~ ...) or indexing expression (x[i] ~ ...)")
   
    varexpr  = varexpr
    short_id = id
    full_id  = Expr(:call, :Symbol, fquote(id), Expr(:quote, :_), Expr(:quote, Symbol(join(idx, :_))))

    return varexpr, short_id, full_id
end

"""
    normalize_tilde_arguments(backend, model, args)

This function 'normalizes' every argument of a tilde expression making every inner function call to be a tilde expression as well. 
It forces MSL to create anonymous node for any non-linear variable transformation or deterministic relationships. MSL does not check (and cannot in general) 
if some inner function call leads to a constant expression or not (e.g. `Normal(0.0, sqrt(10.0))`). Backend API should decide whenever to create additional anonymous nodes 
for constant non-linear transformation expressions or not by analyzing input arguments.
"""
function normalize_tilde_arguments(backend, model, args)
    return map(args) do arg
        if @capture(arg, id_[idx_])
            return :($(__normalize_arg(backend, model, id))[$idx])
        else
            return __normalize_arg(backend, model, arg)
        end
    end
end

function __normalize_arg(backend, model, arg)
    if @capture(arg, (f_(v__) where { options__ }) | (f_(v__)))
        if f === :(|>)
            @assert length(v) === 2 "Unsupported pipe syntax in model specification: $(arg)"
            f = v[2]
            v = [ v[1] ]
        end
        nvarexpr  = gensym(:nvar)
        nnodeexpr = gensym(:nnode)
        options  = options !== nothing ? options : []
        v = normalize_tilde_arguments(backend, model, v)
        return :(($nnodeexpr, $nvarexpr) ~ $f($(v...); $(options...)); $(write_anonymous_randomvar(backend, model, nvarexpr)); $nvarexpr)
    else
        return arg
    end
end

argument_write_default_value(arg, default::Nothing) = arg
argument_write_default_value(arg, default)          = Expr(:kw, arg, default)

""" 
    write_model_structure(backend, 
        ms_name, 
        ms_args_checks, 
        ms_args_const_init_block,
        ms_args,
        ms_kwargs,
        ms_constraints, 
        ms_meta,
        ms_options,
        ms_body
    )
"""
function write_model_structure end

"""
    write_argument_guard(backend, argument)
"""
function write_argument_guard end

"""
    write_randomvar_expression(backend, model, varexpr, options, arguments)
"""
function write_randomvar_expression end

"""
    write_datavar_expression(backend, model, varexpr, options, type, arguments)
"""
function write_datavar_expression end

"""
    write_constvar_expression(backend, model, varexpr, arguments)
"""
function write_constvar_expression end

"""
    write_as_variable(backend, model, varexpr)
"""
function write_as_variable end

"""
    write_anonymous_randomvar(backend, model, varexpr)
"""
function write_anonymous_randomvar end

"""
    write_make_node_expression(backend, model, fform, variables, options, nodeexpr, varexpr)
"""
function write_make_node_expression end

"""
    write_autovar_make_node_expression(backend, model, fform, variables, options, nodeexpr, varexpr, autovarid)
"""
function write_autovar_make_node_expression end

"""
    write_node_options(backend, model, fform, variables, options)
"""
function write_node_options end

"""
    write_randomvar_options(backend, variable, options)
"""
function write_randomvar_options end

"""
    write_datavar_options(backend, variable, type, options)
"""
function write_datavar_options end

"""
    write_default_model_constraints(backend)
"""
function write_default_model_constraints end

"""
    write_default_model_meta(backend)
"""
function write_default_model_meta end

macro model(model_specification)
    return esc(:(@model [] $model_specification))
end

macro model(model_options, model_specification)
    return GraphPPL.generate_model_expression(__get_current_backend(), model_options, model_specification)
end

function generate_model_expression(backend, model_options, model_specification)
    @capture(model_options, [ ms_options__ ]) ||
        error("Model specification options should be in a form of [ option1 = ..., option2 = ... ]")

    ms_options = map(ms_options) do option
        (@capture(option, name_ = value_) && name isa Symbol) || error("Invalid option specification: $(option). Expected: 'option_name = option_value'.")
        return (name, value)
    end

    ms_constraints = write_default_model_constraints(backend)
    ms_meta        = write_default_model_meta(backend)
    ms_options     = :(NamedTuple{ ($(tuple(map(first, ms_options)...))) }((($(tuple(map(last, ms_options)...)...)),)))
    

    @capture(model_specification, (function ms_name_(ms_args__; ms_kwargs__) ms_body_ end) | (function ms_name_(ms_args__) ms_body_ end)) || 
        error("Model specification language requires full function definition")

    model = gensym(:model)

    ms_args_ids       = Vector{Symbol}()
    ms_args_guard_ids = Vector{Symbol}()
    ms_args_const_ids = Vector{Tuple{Symbol, Symbol}}()

    ms_arg_expression_converter = (ms_arg) -> begin
        if @capture(ms_arg, arg_::ConstVariable = smth_) || @capture(ms_arg, arg_::ConstVariable)
            # rc_arg = gensym(:constvar) 
            push!(ms_args_const_ids, (arg, arg)) # backward compatibility for old behaviour with gensym
            push!(ms_args_guard_ids, arg)
            push!(ms_args_ids, arg)
            return argument_write_default_value(arg, smth)
        elseif @capture(ms_arg, arg_::T_ = smth_) || @capture(ms_arg, arg_::T_)
            push!(ms_args_guard_ids, arg)
            push!(ms_args_ids, arg)
            return argument_write_default_value(:($(arg)::$(T)), smth)
        elseif @capture(ms_arg, arg_Symbol = smth_) || @capture(ms_arg, arg_Symbol)
            push!(ms_args_guard_ids, arg)
            push!(ms_args_ids, arg)
            return argument_write_default_value(arg, smth)
        else
            error("Invalid argument specification: $(ms_arg)")
        end
    end

    ms_args   = ms_args === nothing ? [] : map(ms_arg_expression_converter, ms_args)
    ms_kwargs = ms_kwargs === nothing ? [] : map(ms_arg_expression_converter, ms_kwargs)

    if length(Set(ms_args_ids)) !== length(ms_args_ids)
        error("There are duplicates in argument specification list: $(ms_args_ids)")
    end

    ms_args_const_init_block = map(ms_args_const_ids) do ms_arg_const_id
        return write_constvar_expression(backend, model, first(ms_arg_const_id), [ last(ms_arg_const_id) ])
    end

    # Step 0: Check that all inputs are not AbstractVariables
    # It is highly recommended not to create AbstractVariables outside of the model creation macro
    # Doing so can lead to undefined behaviour
    ms_args_checks = map((ms_arg) -> write_argument_guard(backend, ms_arg), ms_args_guard_ids)

    # Step 1: Probabilistic arguments normalisation
    ms_body = prewalk(ms_body) do expression
        if @capture(expression, (varexpr_ ~ fform_(arguments__) where { options__ }) | (varexpr_ ~ fform_(arguments__)))
            options   = options === nothing ? [] : options

            # Filter out keywords arguments to options array
            arguments = filter(arguments) do arg
                ifparameters = arg isa Expr && arg.head === :parameters
                if ifparameters
                    foreach(a -> push!(options, a), arg.args)
                end
                return !ifparameters
            end

            varexpr   =  @capture(varexpr, (nodeid_, varid_)) ? varexpr : :(($(gensym(:nnode)), $varexpr))
            return :($varexpr ~ $(fform)($((normalize_tilde_arguments(backend, model, arguments))...); $(options...)))
        elseif @capture(expression, varexpr_ = randomvar(arguments__) where { options__ })
            return :($varexpr = randomvar($(arguments...); $(options...)))
        elseif @capture(expression, varexpr_ = datavar(arguments__) where { options__ })
            return :($varexpr = datavar($(arguments...); $(options...)))
        elseif @capture(expression, varexpr_ = constvar(arguments__) where { options__ })
            return error("Error in the expression $(expression). `constvar()` call does not support `where {  }` syntax.")
        elseif @capture(expression, varexpr_ = randomvar(arguments__))
            return :($varexpr = randomvar($(arguments...); ))
        elseif @capture(expression, varexpr_ = datavar(arguments__))
            return :($varexpr = datavar($(arguments...); ))
        elseif @capture(expression, varexpr_ = constvar(arguments__))
            return :($varexpr = constvar($(arguments...)))
        else
            return expression
        end
    end

    bannedids = Set{Symbol}()

    ms_body = postwalk(ms_body) do expression
        if @capture(expression, lhs_ = rhs_)
            if !(@capture(rhs, datavar(args__))) && !(@capture(rhs, randomvar(args__))) && !(@capture(rhs, constvar(args__)))
                varexpr, short_id, full_id = parse_varexpr(lhs)
                push!(bannedids, short_id)
            end
        end
        return expression
    end

    varids = Set{Symbol}(ms_args_ids)
       
    # Step 2: Main pass
    ms_body = postwalk(ms_body) do expression
        # Step 2.1 Convert datavar calls
        if @capture(expression, varexpr_ = datavar(arguments__; options__)) 
            @assert varexpr ∉ varids "Invalid model specification: '$varexpr' id is duplicated"
            @assert length(arguments) >= 1 "Invalid datavar() creation. datavar(::Type{T}, [ dims... ]) requires type specification as a first argument, but the expression `$(expression)` has no type argument."
            
            push!(varids, varexpr)

            type_argument  = arguments[1]
            tail_arguments = arguments[2:end]
            dvoptions      = write_datavar_options(backend, varexpr, type_argument, options)

            return write_datavar_expression(backend, model, varexpr, dvoptions, type_argument, tail_arguments)
        # Step 2.2 Convert randomvar calls
        elseif @capture(expression, varexpr_ = randomvar(arguments__; options__))
            @assert varexpr ∉ varids "Invalid model specification: '$varexpr' id is duplicated"
            push!(varids, varexpr)

            rvoptions = write_randomvar_options(backend, varexpr, options)

            return write_randomvar_expression(backend, model, varexpr, rvoptions, arguments)
        # Step 2.3 Conver constvar calls 
        elseif @capture(expression, varexpr_ = constvar(arguments__))
            @assert varexpr ∉ varids "Invalid model specification: '$varexpr' id is duplicated"
            push!(varids, varexpr)

            return write_constvar_expression(backend, model, varexpr, arguments)
        # Step 2.2 Convert tilde expressions
        elseif @capture(expression, (nodeexpr_, varexpr_) ~ fform_(arguments__; kwarguments__))
            # println(expression)
            varexpr, short_id, full_id = parse_varexpr(varexpr)

            if short_id ∈ bannedids
                error("Invalid name '$(short_id)' for new random variable. '$(short_id)' was already initialized with '=' operator before.")
            end

            variables = map((argexpr) -> write_as_variable(backend, model, argexpr), arguments)
            options = write_node_options(backend, model, fform, [ varexpr, arguments... ], kwarguments)
            
            if short_id ∈ varids
                return write_make_node_expression(backend, model, fform, variables, options, nodeexpr, varexpr)
            else
                push!(varids, short_id)
                return write_autovar_make_node_expression(backend, model, fform, variables, options, nodeexpr, varexpr, full_id)
            end
        else
            return expression
        end
    end

    # Step 3: Final pass
    final_pass_exceptions = (x) -> @capture(x, (some_ -> body_) | (function some_(args__) body_ end) | (some_(args__) = body_))
    final_pass_target     = (x) -> @capture(x, return ret_)

    ms_body = quote 
        $ms_body
        return nothing
    end

    ms_body = conditioned_walk(final_pass_exceptions, final_pass_target, ms_body) do expression
        @capture(expression, return ret_) ? quote activate!($model); return $model, ($ret) end : expression
    end

    ms_structure = write_model_structure(backend, 
        ms_name, 
        model,
        ms_args_checks, 
        ms_args_const_init_block,
        ms_args,
        ms_kwargs,
        ms_constraints, 
        ms_meta,
        ms_options,
        ms_body
    ) 
        
    return esc(ms_structure)
end