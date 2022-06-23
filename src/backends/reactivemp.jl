export ReactiveMPBackend

using TupleTools

struct ReactiveMPBackend end

function write_model_structure(::ReactiveMPBackend, 
    ms_name, 
    ms_model,
    ms_args_checks, 
    ms_args_const_init_block,
    ms_args,
    ms_kwargs,
    ms_constraints, 
    ms_meta,
    ms_options,
    ms_body
) 

    # We create two variables for type stability
    constraints_in = gensym(Symbol(ms_name, :constraints_in))
    constraints    = gensym(Symbol(ms_name, :constraints))
    meta_in        = gensym(Symbol(ms_name, :meta_in))
    meta           = gensym(Symbol(ms_name, :meta))
    options_in     = gensym(Symbol(ms_name, :options_in))
    options        = gensym(Symbol(ms_name, :options))

    return quote 

        struct $ms_name <: ReactiveMP.AbstractModelSpecification 
            $ms_name(args...; kwargs...) = ReactiveMP.create_model($ms_name, $(ms_constraints), $(ms_meta), $(ms_options), args...; kwargs...)

            function $ms_name(constraints::Union{ ReactiveMP.UnspecifiedConstraints, ReactiveMP.ConstraintsSpecification }, args...; kwargs...) 
                return ReactiveMP.create_model($ms_name, constraints, $(ms_meta), $(ms_options), args...; kwargs...)
            end

            function $ms_name(meta::Union{ ReactiveMP.UnspecifiedMeta, ReactiveMP.MetaSpecification }, args...; kwargs...) 
                return ReactiveMP.create_model($ms_name, $(ms_constraints), meta, $(ms_options), args...; kwargs...)
            end

            function $ms_name(options::ReactiveMP.ModelOptions, args...; kwargs...) 
                return ReactiveMP.create_model($ms_name, $(ms_constraints), $(ms_meta), options, args...; kwargs...)
            end

            function $ms_name(constraints::Union{ ReactiveMP.UnspecifiedConstraints, ReactiveMP.ConstraintsSpecification }, meta::Union{ ReactiveMP.UnspecifiedMeta, ReactiveMP.MetaSpecification }, args...; kwargs...) 
                return ReactiveMP.create_model($ms_name, constraints, meta, $(ms_options), args...; kwargs...)
            end

            function $ms_name(constraints::Union{ ReactiveMP.UnspecifiedConstraints, ReactiveMP.ConstraintsSpecification }, options::ReactiveMP.ModelOptions, args...; kwargs...) 
                return ReactiveMP.create_model($ms_name, constraints, $(ms_meta), options, args...; kwargs...)
            end

            function $ms_name(meta::Union{ ReactiveMP.UnspecifiedMeta, ReactiveMP.MetaSpecification }, options::ReactiveMP.ModelOptions, args...; kwargs...) 
                return ReactiveMP.create_model($ms_name, $(ms_constraints), meta, options, args...; kwargs...)
            end

            function $ms_name(constraints::Union{ ReactiveMP.UnspecifiedConstraints, ReactiveMP.ConstraintsSpecification }, meta::Union{ ReactiveMP.UnspecifiedMeta, ReactiveMP.MetaSpecification }, options::ReactiveMP.ModelOptions, args...; kwargs...) 
                return ReactiveMP.create_model($ms_name, constraints, meta, options, args...; kwargs...)
            end
        end

        function ReactiveMP.create_model(::Type{ $ms_name }, $constraints_in, $meta_in, $options_in, $(ms_args...); $(ms_kwargs...))

            $(ms_args_checks...)

            $constraints = something($constraints_in, $(ms_constraints))
            $meta        = something($meta_in, $(ms_meta))
            $options     = merge($(ms_options), something($options_in, $(ms_options)))
            $ms_model    = ReactiveMP.FactorGraphModel($constraints, $meta, $options)

            $(ms_args_const_init_block...)

            $ms_body
        end  

        ReactiveMP.model_name(::$ms_name)         = $(QuoteNode(ms_name))
        ReactiveMP.model_name(::Type{ $ms_name }) = $(QuoteNode(ms_name))
    end
end

function write_argument_guard(::ReactiveMPBackend, argument::Symbol)
    return :(@assert !($argument isa ReactiveMP.AbstractVariable) "It is not allowed to pass AbstractVariable objects to a model definition arguments. ConstVariables should be passed as their raw values.")
end

function write_randomvar_expression(::ReactiveMPBackend, model, varexp, options, arguments)
    return :($varexp = ReactiveMP.randomvar($model, $options, $(GraphPPL.fquote(varexp)), $(arguments...)))
end

function write_datavar_expression(::ReactiveMPBackend, model, varexpr, options, type, arguments)
    errstr    = "The expression `$varexpr = datavar($(type))` is incorrect. datavar(::Type, [ dims... ]) requires `Type` as a first argument, but `$(type)` is not a `Type`."
    checktype = :(GraphPPL.ensure_type($(type)) || error($errstr))
    return :($checktype; $varexpr = ReactiveMP.datavar($model, $options, $(GraphPPL.fquote(varexpr)), ReactiveMP.PointMass{ $type }, $(arguments...)))
end

function write_constvar_expression(::ReactiveMPBackend, model, varexpr, arguments)
    return :($varexpr = ReactiveMP.constvar($model, $(GraphPPL.fquote(varexpr)), $(arguments...)))
end

function write_as_variable(::ReactiveMPBackend, model, varexpr)
    return :(ReactiveMP.as_variable($model, $varexpr))
end

function write_undo_as_variable(::ReactiveMPBackend, varexpr)
    return :(ReactiveMP.undo_as_variable($varexpr))
end

function write_anonymous_variable(::ReactiveMPBackend, model, varexpr)
    return :(ReactiveMP.setanonymous!($varexpr, true))
end

function write_make_node_expression(::ReactiveMPBackend, model, fform, variables, options, nodeexpr, varexpr)
    return :($nodeexpr = ReactiveMP.make_node($model, $options, $fform, $varexpr, $(variables...)))
end

function write_broadcasted_make_node_expression(::ReactiveMPBackend, model, fform, variables, options, nodeexpr, varexpr)
    return :($nodeexpr = ReactiveMP.make_node.($model, $options, $fform, $varexpr, $(variables...)))
end

function write_autovar_make_node_expression(::ReactiveMPBackend, model, fform, variables, options, nodeexpr, varexpr, autovarid)
    return :(($nodeexpr, $varexpr) = ReactiveMP.make_node($model, $options, $fform, ReactiveMP.AutoVar($(GraphPPL.fquote(autovarid))), $(variables...)))
end

function write_check_variable_existence(::ReactiveMPBackend, model, varid, errormsg)
    return :(ReactiveMP.haskey($model, $(QuoteNode(varid))) || Base.error($errormsg))
end

function write_node_options(::ReactiveMPBackend, model, fform, variables, options)
    is_factorisation_option_present = false
    is_meta_option_present          = false
    is_pipeline_option_present      = false

    factorisation_option = :(nothing)
    meta_option          = :(nothing)
    pipeline_option      = :(nothing)

    foreach(options) do option
        # Factorisation constraint option
        if @capture(option, q = fconstraint_)
            !is_factorisation_option_present || error("Factorisation constraint option $(option) for $(fform) has been redefined.")
            is_factorisation_option_present = true
            factorisation_option = write_fconstraint_option(fform, variables, fconstraint)
        elseif @capture(option, meta = fmeta_)
            !is_meta_option_present || error("Meta specification option $(option) for $(fform) has been redefined.")
            is_meta_option_present = true
            meta_option = write_meta_option(fform, fmeta)
        elseif @capture(option, pipeline = fpipeline_)
            !is_pipeline_option_present || error("Pipeline specification option $(option) for $(fform) has been redefined.")
            is_pipeline_option_present = true
            pipeline_option = write_pipeline_option(fform, fpipeline)
        else
            error("Unknown option '$option' for '$fform' node")
        end
    end

    return :(ReactiveMP.FactorNodeCreationOptions($factorisation_option, $meta_option, $pipeline_option))
end

# Meta helper functions

function write_meta_option(fform, fmeta)
    return :($fmeta)
end

# Pipeline helper functions

function write_pipeline_option(fform, fpipeline)
    if @capture(fpipeline, +(stages__))
        return :(+($(map(stage -> write_pipeline_stage(fform, stage), stages)...)))
    else
        return :($(write_pipeline_stage(fform, fpipeline)))
    end
end

function write_pipeline_stage(fform, stage)
    if @capture(stage, Default())
        return :(ReactiveMP.DefaultFunctionalDependencies())
    elseif @capture(stage, RequireEverything())
        return :(ReactiveMP.RequireEverythingFunctionalDependencies())
    elseif @capture(stage, RequireInbound(args__))

        specs = map(args) do arg
            if @capture(arg, name_Symbol)
                return (name, :nothing)
            elseif @capture(arg, name_Symbol = dist_)
                return (name, dist)
            else
                error("Invalid arg specification in node's WithInbound dependencies list: $(arg). Should be either `name` or `name = initial` expression")
            end
        end

        indices  = Expr(:tuple, map(s -> :(ReactiveMP.interface_get_index(Val{ $(GraphPPL.fquote(fform)) }, Val{ $(GraphPPL.fquote(first(s))) })), specs)...)
        initials = Expr(:tuple, map(s -> :($(last(s))), specs)...)

        return :(ReactiveMP.RequireInboundFunctionalDependencies($indices, $initials))
    else
        return stage
    end
end

# Factorisation constraint helper functions

function factorisation_replace_var_name(varnames, arg::Expr)
    index = findfirst(==(arg), varnames)
    return index === nothing ? error("Invalid factorisation argument: $arg. $arg should be available within tilde expression") : index
end

function factorisation_replace_var_name(varnames, arg::Symbol)
    index = findfirst(==(arg), varnames)
    return index === nothing ? arg : index
end

function factorisation_name_to_index(form, name)
    return :(ReactiveMP.interface_get_index(Val{ $(GraphPPL.fquote(form)) }, Val{ ReactiveMP.interface_get_name(Val{ $(GraphPPL.fquote(form)) }, Val{ $(GraphPPL.fquote(name)) }) }))
end

function check_uniqueness(t)
    return TupleTools.minimum(TupleTools.diff(TupleTools.sort(TupleTools.flatten(t)))) > 0
end

function sorted_factorisation(t)
    subfactorisations = map(TupleTools.sort, t)
    firstindices      = map(first, subfactorisations)
    staticlength      = TupleTools.StaticLength(length(firstindices))
    withindices       = ntuple(i -> (i, firstindices[i]), staticlength)
    permutation       = map(first, TupleTools.sort(withindices; by = last))
    return ntuple(i -> subfactorisations[permutation[i]], staticlength)
end

function write_fconstraint_option(form, variables, fconstraint)
    if @capture(fconstraint, (*(factors__)) | (q(names__)))
        factors = factors === nothing ? [ fconstraint ] : factors

        indexed = map(factors) do factor
            @capture(factor, q(names__)) || error("Invalid factorisation constraint: $factor")
            return map((n) -> GraphPPL.factorisation_name_to_index(form, n), map((n) -> GraphPPL.factorisation_replace_var_name(variables, n), names))
        end

        factorisation = Expr(:tuple, map(f -> Expr(:tuple, f...), indexed)...)
        errorstr = """Invalid factorisation constraint: ($fconstraint). Arguments are not unique, check node's interface names and model specification variable names.""" 

        return :(GraphPPL.check_uniqueness($factorisation) ? GraphPPL.sorted_factorisation($factorisation) : error($errorstr))
    elseif @capture(fconstraint, MeanField())
        return :(ReactiveMP.MeanField())
    elseif @capture(fconstraint, FullFactorisation())
        return :(ReactiveMP.FullFactorisation())
    else
        error("Invalid factorisation constraint: $fconstraint")
    end
end

## 

function write_randomvar_options(::ReactiveMPBackend, variable, options)
    is_pipeline_option_present                     = false
    is_prod_constraint_option_present              = false
    is_prod_strategy_option_present                = false
    is_marginal_form_constraint_option_present     = false
    is_marginal_form_check_strategy_option_present = false
    is_messages_form_constraint_option_present     = false
    is_messages_form_check_strategy_option_present = false

    pipeline_option                     = :(nothing)
    prod_constraint_option              = :(nothing)
    prod_strategy_option                = :(nothing)
    marginal_form_constraint_option     = :(nothing)
    marginal_form_check_strategy_option = :(nothing)
    messages_form_constraint_option     = :(nothing)
    messages_form_check_strategy_option = :(nothing)
    
    foreach(options) do option 
        if @capture(option, pipeline = value_)
            !is_pipeline_option_present || error("`pipeline` option $(option) for random variable $(variable) has been redefined.")
            is_pipeline_option_present = true
            pipeline_option = value
        elseif @capture(option, $(:(prod_constraint)) = value_) 
            !is_prod_constraint_option_present || error("`prod_constraint` option $(option) for random variable $(variable) has been redefined.")
            is_prod_constraint_option_present = true
            prod_constraint_option = value
        elseif @capture(option, $(:(prod_strategy)) = value_) 
            !is_prod_strategy_option_present || error("`prod_strategy` option $(option) for random variable $(variable) has been redefined.")
            is_prod_strategy_option_present = true
            prod_strategy_option = value
        elseif @capture(option, $(:(marginal_form_constraint)) = value_) 
            !is_marginal_form_constraint_option_present || error("`marginal_form_constraint` option $(option) for random variable $(variable) has been redefined.")
            is_marginal_form_constraint_option_present = true
            marginal_form_constraint_option = value
        elseif @capture(option, $(:(form_constraint)) = value_) # backward compatibility
            @warn "`form_constraint` option is deprecated. Use `marginal_form_constraint` option for variable $(variable) instead."
            !is_marginal_form_constraint_option_present || error("`marginal_form_constraint` option $(option) for random variable $(variable) has been redefined.")
            is_marginal_form_constraint_option_present = true
            marginal_form_constraint_option = value
        elseif @capture(option, $(:(marginal_form_check_strategy)) = value_) 
            !is_marginal_form_check_strategy_option_present || error("`marginal_form_check_strategy` option $(option) for random variable $(variable) has been redefined.")
            is_marginal_form_check_strategy_option_present = true
            marginal_form_check_strategy_option = value
        elseif @capture(option, $(:(messages_form_constraint)) = value_) 
            !is_messages_form_constraint_option_present || error("`messages_form_constraint` option $(option) for random variable $(variable) has been redefined.")
            is_messages_form_constraint_option_present = true
            messages_form_constraint_option = value
        elseif @capture(option, $(:(messages_form_check_strategy)) = value_) 
            !is_messages_form_check_strategy_option_present || error("`messages_form_check_strategy` option $(option) for random variable $(variable) has been redefined.")
            is_messages_form_check_strategy_option_present = true
            messages_form_check_strategy_option = value
        else
            error("Unknown option '$option' for randomv variable '$variable'.")
        end
    end

    return :(ReactiveMP.RandomVariableCreationOptions(
        $pipeline_option,
        nothing, # it does not make a lot of sense to override `proxy_variables` option
        $prod_constraint_option,
        $prod_strategy_option,
        $marginal_form_constraint_option,
        $marginal_form_check_strategy_option,
        $messages_form_constraint_option,
        $messages_form_check_strategy_option
    ))
end

function write_datavar_options(::ReactiveMPBackend, variable, type, options)
    is_subject_option_present       = false
    is_allow_missing_option_present = false

    # default options
    subject_option       = :(nothing)
    allow_missing_option = :(Val(false))

    foreach(options) do option 
        if @capture(option, subject = value_)
            !is_subject_option_present || error("`subject` option $(option) for data variable $(variable) has been redefined.")
            is_subject_option_present = true
            subject_option = value
        elseif @capture(option, $(:(allow_missing)) = value_) 
            !is_allow_missing_option_present || error("`allow_missing` option $(option) for data variable $(variable) has been redefined.")
            is_allow_missing_option_present = true
            allow_missing_option = :(Val($value))
        else
            error("Unknown option '$option' for data variable '$variable'.")
        end
    end

    return :(ReactiveMP.DataVariableCreationOptions(ReactiveMP.PointMass{ $type }, $subject_option, $allow_missing_option))
end

function write_default_model_constraints(::ReactiveMPBackend)
    return :(ReactiveMP.UnspecifiedConstraints())
end

function write_default_model_meta(::ReactiveMPBackend)
    return :(ReactiveMP.UnspecifiedMeta())
end

# Constraints specification language

## Factorisations constraints specification language

function write_constraints_specification(::ReactiveMPBackend, factorisation, marginalsform, messagesform, options) 
    return :(ReactiveMP.ConstraintsSpecification($factorisation, $marginalsform, $messagesform, $options))
end

function write_constraints_specification_options(::ReactiveMPBackend, options)
    @capture(options, [ entries__ ]) || error("Invalid constraints specification options syntax. Should be `@constraints [ option1 = value1, ... ] ...`, but `$(options)` found.")
    
    is_warn_option_present = false

    warn_option = :(true)

    foreach(entries) do option 
        if @capture(option, warn = value_)
            !is_warn_option_present || error("`warn` option $(option) for constraints specification has been redefined.")
            is_warn_option_present = true
            @assert value isa Bool "`warn` option for constraints specification expects true/false value"
            warn_option = value
        else
            error("Unknown option '$option' for constraints specification.")
        end
    end

    return :(ReactiveMP.ConstraintsSpecificationOptions($warn_option))
end

function write_factorisation_constraint(::ReactiveMPBackend, names, entries) 
    return :(ReactiveMP.FactorisationConstraintsSpecification($names, $entries))
end

function write_factorisation_constraint_entry(::ReactiveMPBackend, names, entries) 
    return :(ReactiveMP.FactorisationConstraintsEntry($names, $entries))
end

function write_init_factorisation_not_defined(::ReactiveMPBackend, spec, name) 
    return :($spec = ReactiveMP.FactorisationSpecificationNotDefinedYet{$(QuoteNode(name))}())
end

function write_check_factorisation_is_not_defined(::ReactiveMPBackend, spec)
    return :($spec isa ReactiveMP.FactorisationSpecificationNotDefinedYet)
end

function write_factorisation_split(::ReactiveMPBackend, left, right)
    return :(ReactiveMP.factorisation_split($left, $right)) 
end

function write_factorisation_combined_range(::ReactiveMPBackend, left, right) 
    return :(ReactiveMP.CombinedRange($left, $right))
end

function write_factorisation_splitted_range(::ReactiveMPBackend, left, right) 
    return :(ReactiveMP.SplittedRange($left, $right))
end

function write_factorisation_functional_index(::ReactiveMPBackend, repr, fn)
    return :(ReactiveMP.FunctionalIndex{$(QuoteNode(repr))}($fn))
end

function write_form_constraint_specification_entry(::ReactiveMPBackend, T, args, kwargs) 
    return :(ReactiveMP.make_form_constraint($T, $args...; $kwargs...)) 
end

function write_form_constraint_specification(::ReactiveMPBackend, specification)
    return :(ReactiveMP.FormConstraintSpecification($specification))
end

## Meta specification language

function write_meta_specification(::ReactiveMPBackend, entries, options) 
    return :(ReactiveMP.MetaSpecification($entries, $options))
end

function write_meta_specification_options(::ReactiveMPBackend, options)
    @capture(options, [ entries__ ]) || error("Invalid meta specification options syntax. Should be `@meta [ option1 = value1, ... ] ...`, but `$(options)` found.")
    
    is_warn_option_present = false

    warn_option = :(true)

    foreach(entries) do option 
        if @capture(option, warn = value_)
            !is_warn_option_present || error("`warn` option $(option) for meta specification has been redefined.")
            is_warn_option_present = true
            @assert value isa Bool "`warn` option for meta specification expects true/false value"
            warn_option = value
        else
            error("Unknown option '$option' for meta specification.")
        end
    end

    return :(ReactiveMP.MetaSpecificationOptions($warn_option))
end

function write_meta_specification_entry(::ReactiveMPBackend, F, N, meta) 
    return :(ReactiveMP.MetaSpecificationEntry(Val($F), Val($N), $meta))
end