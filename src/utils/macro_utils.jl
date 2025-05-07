import MacroTools: postwalk, prewalk, @capture, walk
using NamedTupleTools
using Static

__guard_f(f, e::Expr) = f(e)
__guard_f(f, x) = x

struct guarded_walk{f}
    guard::f
end

function (w::guarded_walk)(f, x)
    return w.guard(x) ? x : walk(x, x -> w(f, x), f)
end

struct walk_until_occurrence{E}
    patterns::E
end

not_enter_indexed_walk = guarded_walk((x) -> (x isa Expr && x.head == :ref) || (x isa Expr && x.head == :call && x.args[1] == :new))
not_created_by = guarded_walk((x) -> (x isa Expr && !isempty(x.args) && x.args[1] == :created_by))

function (w::walk_until_occurrence{E})(f, x) where {E <: Tuple}
    return walk(x, z -> any(pattern -> @capture(x, $(pattern)), w.patterns) ? z : w(f, z), f)
end

function (w::walk_until_occurrence{E})(f, x) where {E <: Expr}
    return walk(x, z -> @capture(x, $(w.patterns)) ? z : w(f, z), f)
end

what_walk(anything) = postwalk

"""
    apply_pipeline(e::Expr, pipeline)

Apply a pipeline function to an expression.

The `apply_pipeline` function takes an expression `e` and a `pipeline` function and applies the function in the pipeline to `e` when walking over it. The walk utilized can be specified by implementing `what_walk` for a pipeline funciton.

# Arguments
- `e::Expr`: An expression to apply the pipeline to.
- `pipeline`: A function to apply to the expressions in `e`.

# Returns
The result of applying the pipeline function to `e`.
"""
function apply_pipeline(e::Expr, pipeline::F) where {F}
    walk = what_walk(pipeline)
    return walk(x -> __guard_f(pipeline, x), e)
end

"""
    apply_pipeline_collection(e::Expr, collection)

Similar to [`apply_pipeline`](@ref), but applies a collection of pipeline functions to an expression. 

# Arguments
- `e::Expr`: An expression to apply the pipeline to.
- `collection`: A collection of functions to apply to the expressions in `e`.

# Returns
The result of applying the pipeline function to `e`.
"""
function apply_pipeline_collection(e::Expr, collection)
    return reduce((e, pipeline) -> apply_pipeline(e, pipeline), collection, init = e)
end