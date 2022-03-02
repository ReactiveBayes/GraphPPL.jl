
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
iscall(expr)       = ishead(expr, :call) && length(expr.args) >= 1
iscall(expr, fsym) = iscall(expr) && first(expr.args) === fsym

"""
    isref(expr)

Shorthand for `ishead(expr, :ref)`.

See also: [`ishead`](@ref)
"""
isref(expr) = ishead(expr, :ref)