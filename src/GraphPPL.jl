module GraphPPL

import ReactiveMP

export @model

import MacroTools: @capture, postwalk

include("helpers.jl")

function quote_symbol(sym::Symbol)
    return Expr(:quote, sym)
end

function quote_symbol(sym::Expr)
    return sym
end

function collect_varid(varid::Symbol)
   return varid, varid, varid
end

function collect_varid(varid::Expr)
   @capture(varid, id_[idx__]) || 
       error("Variable identificator can be in form of a single symbol (x ~ ...) or indexing expression (x[i] ~ ...)")
   
   short_id = id
   full_id  = Expr(:call, :Symbol, GraphPPL.quote_symbol(id), Expr(:quote, :_), ReactiveMP.with_separator(Expr(:quote, :_), idx)...)
   
   return short_id, full_id, varid
end

function write_randomvar_expression(model, varid, inputs)
    return :($varid = ReactiveMP.randomvar($model, $(GraphPPL.quote_symbol(varid)), $(inputs...)))
 end

function write_datavar_expression(model, varid, inputs)
   return :($varid = ReactiveMP.datavar($model, $(GraphPPL.quote_symbol(varid)), Dirac{$(inputs[1])}, $(inputs[2:end]...)))
end

function write_as_variable_args(model, args)
    return map(arg -> :(ReactiveMP.as_variable($model, $(GraphPPL.quote_symbol(gensym(:arg))), $arg)), args)
end

function write_make_node_expression(model, varids, fform, args, short_varid, full_varid, varid, nodeid)
   if short_varid ∈ varids
       return quote 
           $nodeid = ReactiveMP.make_node($model, $fform, $varid, $(GraphPPL.write_as_variable_args(model, args)...)) 
       end
   else    
       push!(varids, short_varid)
       return quote 
           $nodeid, $varid = ReactiveMP.make_node($model, $fform, ReactiveMP.AutoVar($(GraphPPL.quote_symbol(full_varid))), $(GraphPPL.write_as_variable_args(model, args)...))
       end
   end
end

macro model(model_specification)
    @capture(model_specification, function ms_name_(ms_args__) ms_body_ end) || 
        error("Model specification language requires full function definition")
       
    model = gensym(:model)
   
    varids = Set{Symbol}()

    ms_body = postwalk(ms_body) do expression
        if @capture(expression, varid_ = datavar(inputs__)) 
            @assert varid ∉ varids
            push!(varids, varid)
            return GraphPPL.write_datavar_expression(model, varid, inputs)
        elseif @capture(expression, varid_ = randomvar(inputs__))
            @assert varid ∉ varids
            push!(varids, varid)
            return GraphPPL.write_randomvar_expression(model, varid, inputs)
        else
            return expression
        end
    end
       
    ms_body = postwalk(ms_body) do expression
        if @capture(expression, varid_ ~ fform_(args__)) 
            normalized_args = postwalk(args) do arg
                if @capture(arg, f_(g__))
                    nvarid = gensym()
                    return quote $nvarid ~ $f($(g...)); $nvarid end
                else
                    return arg
                end
            end
            return :($varid ~ $(fform)($(normalized_args...)))
        else
            return expression
        end
    end
       
    ms_body = postwalk(ms_body) do expression
        if @capture(expression, varid_ ~ fform_(args__))
            short_varid, full_varid, varid = collect_varid(varid)
            return write_make_node_expression(model, varids, fform, args, short_varid, full_varid, varid, gensym())
        else
            return expression
        end
    end
                
    ms_body = postwalk(ms_body) do expression
        @capture(expression, return ret_) ? quote activate!($model); $expression end : expression
    end
        
    res = quote
        function $ms_name($(ms_args...))
            $model = Model()
            $ms_body
            error("'return' statement is missing")
        end     
    end
        
    return esc(res)
end

end # module
