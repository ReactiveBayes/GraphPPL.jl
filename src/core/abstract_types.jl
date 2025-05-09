
abstract type AbstractModelFilterPredicate end

abstract type AbstractVariableReference end

"""
    AbstractInterfaces

Base type for all interfaces definition types. Interfaces define the connection points between 
nodes in a probabilistic graphical model. Different implementations can provide various ways to
represent and manipulate these interfaces, such as using static types for compile-time reasoning
or dynamic types for runtime flexibility.
"""
abstract type AbstractInterfaces end

"""
    AbstractInterfaceAliases

Base type for all interface alias definition types. Interface aliases allow different names to refer
to the same interface, enabling more flexible and intuitive model specifications. Different 
implementations can provide various ways to represent and manipulate these aliases.
"""
abstract type AbstractInterfaceAliases end