"""
    ContextInterface

Abstract interface for a context in a probabilistic graphical model.
Contains information about a model or submodel's variables, factors, and structure.
"""
abstract type ContextInterface end

"""
    create_context(
        ::Type{C}, factor_identifier_type::FI, factor_label_type::FL, variable_label_type::VL
    ) where {C <: ContextInterface, F, FI, FL, VL}

Create a new context of type C with the given factor identifier type, factor data type, and variable data type.
"""
function create_context(
    ::Type{C}, factor_identifier_type::FI, factor_label_type::FL, variable_label_type::VL
) where {C <: ContextInterface, F, FI, FL, VL}
    throw(GraphPPLInterfaceNotImplemented(create_context, C, ContextInterface))
end

"""
    create_child_context(parent::C, fucntional_form::F) where {C <: ContextInterface, F}

Create a new child context of type C with the given functional form.
"""
function create_child_context(parent::C, fucntional_form::F) where {C <: ContextInterface, F}
    throw(GraphPPLInterfaceNotImplemented(create_child_context, C, ContextInterface))
end

# Basic Properties
"""
    get_depth(context::C) where {C<:ContextInterface}

Get the depth of the context in the model hierarchy.
"""
function get_depth(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_depth, C, ContextInterface))
end

"""
    get_functional_form(context::C) where {C<:ContextInterface}

Get the functional form (model function) associated with this context.
"""
function get_functional_form(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_functional_form, C, ContextInterface))
end

"""
    get_prefix(context::C) where {C<:ContextInterface}

Get the prefix string used for naming entities in this context.
"""
function get_prefix(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_prefix, C, ContextInterface))
end

"""
    get_parent(context::C) where {C<:ContextInterface}

Get the parent context, or nothing if this is a root context.
"""
function get_parent(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_parent, C, ContextInterface))
end

"""
    get_short_name(context::C) where {C<:ContextInterface}

Get a short name identifier for the context.
"""
function get_short_name(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_short_name, C, ContextInterface))
end

"""
    get_returnval(context::C) where {C<:ContextInterface}

Get the return value of this context.
"""
function get_returnval(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_returnval, C, ContextInterface))
end

"""
    set_returnval!(context::C, value) where {C<:ContextInterface}

Set the return value of this context.
"""
function set_returnval!(context::C, value) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_returnval!, C, ContextInterface))
end

"""
    get_path_to_root(context::C) where {C<:ContextInterface}

Get the path from this context to the root context.
"""
function get_path_to_root(context::C) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_path_to_root, C, ContextInterface))
end

# Variable Access - Specific Types
function get_variable(context::C, name, index) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_variable, C, ContextInterface))
end

"""
    get_factor_node(context::C, fform, identifier) where {C<:ContextInterface}
    
Get a factor node by functional form and identifier.
"""
function get_factor_node(context::C, fform, identifier) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_factor_node, C, ContextInterface))
end

"""
    get_child_context(context::C, fform, identifier) where {C<:ContextInterface}
    
Get a child context by functional form and identifier.
"""
function get_child_context(context::C, fform, identifier) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(get_child_context, C, ContextInterface))
end

# Has Key Checks
function has_variable(context::C, name, index) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_variable, C, ContextInterface))
end

"""
    has_factor_node(context::C, fform, identifier) where {C<:ContextInterface}
    
Check if a factor node with the given functional form and identifier exists.
"""
function has_factor_node(context::C, fform, identifier) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(has_factor_node, C, ContextInterface))
end

# Setters for Variables and Nodes

function set_variable!(context::C, variable, index)
    throw(GraphPPLInterfaceNotImplemented(set_variable!, C, ContextInterface))
end

"""
    set_factor_node!(context::C, fform, identifier, value::NodeLabelInterface) where {C<:ContextInterface}
    
Set a factor node.
"""
function set_factor_node!(context::C, fform, identifier, value::NodeLabelInterface) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_factor_node!, C, ContextInterface))
end

"""
    set_child_context!(context::C, fform, identifier, value::ContextInterface) where {C<:ContextInterface}
    
Set a child context.
"""
function set_child_context!(context::C, fform, identifier, value::ContextInterface) where {C <: ContextInterface}
    throw(GraphPPLInterfaceNotImplemented(set_child_context!, C, ContextInterface))
end
