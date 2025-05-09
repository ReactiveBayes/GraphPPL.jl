struct NotImplementedError <: Exception
    message::String
end

showerror(io::IO, e::NotImplementedError) = print(io, "NotImplementedError: " * e.message)

"""
    GraphPPLInterfaceNotImplemented{F, T, I} <: Exception

Exception thrown when a required interface method is not implemented for a specific type.
This is used to signal that a concrete subtype has not implemented a required method
from an interface.

# Type Parameters
- `F`: The function or method that was not implemented
- `T`: The concrete type that should implement the method
- `I`: The interface type that defines the required method

# Fields
- `method_name::String`: The name of the method that was not implemented
- `concrete_type::T`: The concrete type that should implement the method
- `interface_type::I`: The interface type that defines the required method
"""
struct GraphPPLInterfaceNotImplemented{F, T, I} <: Exception
    method_name::F
    concrete_type::T
    interface_type::I
end

function Base.showerror(io::IO, e::GraphPPLInterfaceNotImplemented{F, T, I}) where {F, T, I}
    print(
        io,
        "GraphPPLInterfaceNotImplemented: The method '$(e.method_name)' is not implemented for type '$(e.concrete_type)' which should implement the '$(e.interface_type)' interface"
    )
end
