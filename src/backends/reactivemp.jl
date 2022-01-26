export ReactiveMPBackend

using TupleTools

struct ReactiveMPBackend end

function write_argument_guard(::ReactiveMPBackend, argument::Symbol)
    return :(@assert !($argument isa ReactiveMP.AbstractVariable) "It is not allowed to pass AbstractVariable objects to a model definition arguments. ConstVariables should be passed as their raw values.")
end

function write_randomvar_expression(::ReactiveMPBackend, model, varexp, arguments, kwarguments)
    return :($varexp = ReactiveMP.randomvar($model, $(GraphPPL.fquote(varexp)), $(arguments...); $(kwarguments...)))
end

function write_datavar_expression(::ReactiveMPBackend, model, varexpr, type, arguments, kwarguments)
    return :($varexpr = ReactiveMP.datavar($model, $(GraphPPL.fquote(varexpr)), ReactiveMP.PointMass{ GraphPPL.ensure_type($(type)) }, $(arguments...); $(kwarguments...)))
end

function write_constvar_expression(::ReactiveMPBackend, model, varexpr, arguments, kwarguments)
    return :($varexpr = ReactiveMP.constvar($model, $(GraphPPL.fquote(varexpr)), $(arguments...); $(kwarguments...)))
end

function write_as_variable(::ReactiveMPBackend, model, varexpr)
    return :(ReactiveMP.as_variable($model, $varexpr))
end

function write_make_node_expression(::ReactiveMPBackend, model, fform, variables, options, nodeexpr, varexpr)
    return :($nodeexpr = ReactiveMP.make_node($model, $fform, $varexpr, $(variables...); $(options...)))
end

function write_autovar_make_node_expression(::ReactiveMPBackend, model, fform, variables, options, nodeexpr, varexpr, autovarid)
    return :(($nodeexpr, $varexpr) = ReactiveMP.make_node($model, $fform, ReactiveMP.AutoVar($(GraphPPL.fquote(autovarid))), $(variables...); $(options...)))
end

function write_node_options(::ReactiveMPBackend, fform, variables, options)
    return map(options) do option

        # Factorisation constraint option
        if @capture(option, q = fconstraint_)
            return write_fconstraint_option(fform, variables, fconstraint)
        elseif @capture(option, meta = fmeta_)
            return write_meta_option(fform, fmeta)
        elseif @capture(option, pipeline = fpipeline_)
            return write_pipeline_option(fform, fpipeline)
        end

        error("Unknown option '$option' for '$fform' node")
    end
end

# Meta helper functions

function write_meta_option(fform, fmeta)
    return :(meta = $fmeta)
end

# Pipeline helper functions

function write_pipeline_option(fform, fpipeline)
    if @capture(fpipeline, +(stages__))
        return :(pipeline = +($(map(stage -> write_pipeline_stage(fform, stage), stages)...)))
    else
        return :(pipeline = $(write_pipeline_stage(fform, fpipeline)))
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

        return :(RequireInboundFunctionalDependencies($indices, $initials))
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

        return :(factorisation = GraphPPL.check_uniqueness($factorisation) ? GraphPPL.sorted_factorisation($factorisation) : error($errorstr))
    elseif @capture(fconstraint, MeanField())
        return :(factorisation = MeanField())
    elseif @capture(fconstraint, FullFactorisation())
        return :(factorisation = FullFactorisation())
    else
        error("Invalid factorisation constraint: $fconstraint")
    end
end

## 

function write_randomvar_options(::ReactiveMPBackend, variable, options)
    return map(options) do option
        @capture(option, name_Symbol = value_) || error("Invalid variable options specification: $option. Should be in a form of 'name = value'")
        return option
    end
end

function write_constvar_options(::ReactiveMPBackend, variable, options)
    return map(options) do option
        @capture(option, name_Symbol = value_) || error("Invalid variable options specification: $option. Should be in a form of 'name = value'")
        return option
    end
end

function write_datavar_options(::ReactiveMPBackend, variable, options)
    return map(options) do option
        @capture(option, name_Symbol = value_) || error("Invalid variable options specification: $option. Should be in a form of 'name = value'")
        return option
    end
end

# Constraints specification language

## Factorisations constraints specification language

function write_make_constraints(::ReactiveMPBackend) 
    return :(ReactiveMP.Constraints())
end

function write_factorisation_spec(::ReactiveMPBackend, constraints, entries) 
    return :(ReactiveMP.make_factorisation_spec($constraints, $(entries...)))
end

function write_factorisation_spec_entry(::ReactiveMPBackend, constraints, name, index) 
    return :(ReactiveMP.make_factorisation_spec_entry($constraints, $name, $index))
end

function write_factorisation_merge_spec_entries(::ReactiveMPBackend, constraints, left, right)
    return :(Base.merge!($left, $right))
end

function write_factorisation_node(::ReactiveMPBackend, constraints, key, rhs) 
    return :(ReactiveMP.add_factorisation_node($constraints, $key, $(rhs)))
end