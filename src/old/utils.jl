
issymbol(::Symbol) = true
issymbol(any)      = false

isexpr(expr::Expr) = true
isexpr(expr)       = false

"""
    ishead(expr, head)

Checks if `expr` has head set to `head`. Returns false if expr is not a valid Julia `Expr` object.
"""
ishead(expr, head) = isexpr(expr) && expr.head === head

"""
    isblock(expr)

Shorthand for `ishead(expr, :block)`

See also: [`ishead`](@ref)
"""
isblock(expr) = ishead(expr, :block)

"""
    iscall(expr)
    iscall(expr, fsym)

Shorthand for `ishead(expr, :call)` and arguments length check. If an extra `fsym` argument specified function checks if `fsym` function being called.

See also: [`ishead`](@ref)
"""
iscall(expr) = ishead(expr, :call) && length(expr.args) >= 1
iscall(expr, fsym) = iscall(expr) && first(expr.args) === fsym

"""
    isbroadcastedcall(expr) 
    isbroadcastedcall(expr, fsym) 

Checks if expression represents a broadcast call to some function. Optionally accepts `fsym` to check for exact function name match.

See also: [`iscall`](@ref)
"""
function isbroadcastedcall(expr)
    if isblock(expr) # TODO add for other functions?
        nextexpr = findnext(isexpr, expr.args, 1)
        return nextexpr !== nothing ? isbroadcastedcall(expr.args[nextexpr]) : false
    end
    (iscall(expr) && length(expr.args) >= 1 && first(string(first(expr.args))) === '.') || # Checks for `:(a .+ b)` syntax
        (ishead(expr, :(.))) # Checks for `:(f.(x))` syntax
end

function isbroadcastedcall(expr, fsym)
    if isblock(expr) # TODO add for other functions?
        nextexpr = findnext(isexpr, expr.args, 1)
        return nextexpr !== nothing ? isbroadcastedcall(expr.args[nextexpr], fsym) : false
    end
    (iscall(expr) && length(expr.args) >= 1 && first(string(first(expr.args))) === '.' && Symbol(string(first(expr.args))[2:end]) === fsym) || # Checks for `:(a .+ b)` syntax
        (ishead(expr, :(.)) && first(expr.args) === fsym) # Checks for `:(f.(x))` syntax
end

"""
    isref(expr)

Shorthand for `ishead(expr, :ref)`.

See also: [`ishead`](@ref)
"""
isref(expr) = ishead(expr, :ref)

"""
    getref(expr)

Returns ref indices from `expr` in a form of a tuple.

See als: [`isref`](@ref)
"""
getref(expr) = isref(expr) ? (view(expr.args, 2:lastindex(expr.args))...,) : ()

"""
    ensure_type(x)

Checks if `x` is of type `Type` 
"""
ensure_type(x::Type) = true
ensure_type(x) = false

fold_linear_operator_call(any) = any

fold_linear_operator_call_first_arg(::typeof(foldl), args) = args[begin + 1]
fold_linear_operator_call_tail_args(::typeof(foldl), args) = args[(begin + 2):end]

fold_linear_operator_call_first_arg(::typeof(foldr), args) = args[end]
fold_linear_operator_call_tail_args(::typeof(foldr), args) = args[(begin + 1):(end - 1)]

function fold_linear_operator_call(expr::Expr, fold = foldl)
    if @capture(expr, op_(args__)) && length(args) > 2
        return fold((res, el) -> Expr(:call, op, res, el), fold_linear_operator_call_tail_args(fold, expr.args); init = fold_linear_operator_call_first_arg(fold, expr.args))
    else
        return expr
    end
end
