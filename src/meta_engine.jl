struct FactorMetaDescriptor{T}
    fform::Any
    fargs::T
end

Base.show(io::IO, m::FactorMetaDescriptor{Nothing}) = print(io, m.fform)
function Base.show(io::IO, m::FactorMetaDescriptor{<:Tuple})
    print(io, m.fform)
    print(io, "(", join(m.fargs, ", "), ")")
end

struct VariableMetaDescriptor
    node_descriptor::IndexedVariable
end

Base.show(io::IO, m::VariableMetaDescriptor) = print(io, m.node_descriptor)

const NodeMetaDescriptor = Union{FactorMetaDescriptor,VariableMetaDescriptor}

struct MetaObject{S<:NodeMetaDescriptor,T}
    node_descriptor::S
    meta_object::T
end
function Base.show(io::IO, m::MetaObject)
    print(io, m.node_descriptor)
    print(io, " -> ")
    print(io, m.meta_object)
end


getnodedescriptor(m::MetaObject) = m.node_descriptor
getmetainfo(m::MetaObject) = m.meta_object

struct SpecificSubModelMeta
    tag::Symbol
    meta_objects::Any
end

getsubmodel(c::SpecificSubModelMeta) = c.tag
getmetaobjects(c::SpecificSubModelMeta) = c.meta_objects
Base.push!(m::SpecificSubModelMeta, o) = push!(m.meta_objects, o)

struct GeneralSubModelMeta
    fform::Any
    meta_objects::Any
end

getsubmodel(c::GeneralSubModelMeta) = c.fform
getmetaobjects(c::GeneralSubModelMeta) = c.constraints
Base.push!(m::GeneralSubModelMeta, o) = push!(m.meta_objects, o)

struct MetaSpecification
    meta_objects::Vector
end

MetaSpecification() =
    MetaSpecification(Vector{Union{MetaObject,GeneralSubModelMeta,SpecificSubModelMeta}}())
Base.push!(m::MetaSpecification, o) = push!(m.meta_objects, o)

SubModelMeta(x::Symbol, meta = MetaSpecification()::MetaSpecification) =
    SpecificSubModelMeta(x, meta)
SubModelMeta(fform::Function, meta = MetaSpecification()::MetaSpecification) =
    GeneralSubModelMeta(fform, meta)

getmetaobjects(m::MetaSpecification) = m.meta_objects

function apply!(model::Model, meta::MetaSpecification)
    apply!(model, GraphPPL.get_principal_submodel(model), meta)
end

function apply!(model::Model, context::Context, meta::MetaSpecification)
    for meta_obj in getmetaobjects(meta)
        apply!(model, context, meta_obj)
    end
end

function apply!(model::Model, context::Context, meta::GeneralSubModelMeta)
    for (_, factor_context) in context.factor_nodes
        if isdefined(factor_context, :fform)
            if factor_context.fform == getsubmodel(meta)
                apply!(model, factor_context, getmetaobjects(meta))
            end
        end
    end
end

function apply!(model::Model, context::Context, meta::SpecificSubModelMeta)
    for (tag, factor_context) in context.factor_nodes
        if tag == getsubmodel(meta)
            apply!(model, factor_context, getmetaobjects(meta))
        end
    end
end

function apply!(
    model::Model,
    context::Context,
    meta::MetaObject{S,T} where {S<:VariableMetaDescriptor,T},
)
    nodes = context[getnodedescriptor(meta).node_descriptor]
    apply!(model, context, meta, nodes)
end

function apply!(
    model::Model,
    context::Context,
    meta::MetaObject{S,T} where {S<:VariableMetaDescriptor,T},
    node::NodeLabel,
)
    save_meta!(model, node, meta)
end

function apply!(
    model::Model,
    context::Context,
    meta::MetaObject{S,T} where {S<:VariableMetaDescriptor,T},
    nodes::AbstractArray{NodeLabel},
)
    for node in nodes
        save_meta!(model, node, meta)
    end
end


function apply!(
    model::Model,
    context::Context,
    meta::MetaObject{S,T} where {S<:FactorMetaDescriptor{<:Tuple},T},
)
    applicable_nodes = intersect(
        GraphPPL.neighbors.(
            Ref(model),
            vec.(getindex.(Ref(context), GraphPPL.getnodedescriptor(meta).fargs)),
        )...,
    )
    for node in applicable_nodes
        apply!(model, context, meta, node)
    end
end

function apply!(
    model::Model,
    context::Context,
    meta::MetaObject{S,T} where {S<:FactorMetaDescriptor{Nothing},T},
)
    for node in values(context.factor_nodes)
        apply!(model, context, meta, node)
    end
end

apply!(
    model::Model,
    context::Context,
    meta::MetaObject{S,T} where {S<:FactorMetaDescriptor,T},
    node::Context,
) = nothing

function apply!(
    model::Model,
    context::Context,
    meta::MetaObject{S,T} where {S<:FactorMetaDescriptor,T},
    node::NodeLabel,
)
    if model[node].fform == getnodedescriptor(meta).fform
        save_meta!(model, node, meta)
    end
end

function save_meta!(
    model::Model,
    node::NodeLabel,
    meta::MetaObject{S,T} where {S,T<:NamedTuple},
)
    if :q in keys(getmetainfo(meta))
        error("Cannot specify q in meta as it is reserved for the constraint specification")
    end
    model[node].options = merge(model[node].options, getmetainfo(meta))
end

function save_meta!(model::Model, node::NodeLabel, meta::MetaObject{S,T} where {S,T})
    model[node].options = merge(model[node].options, (meta = getmetainfo(meta),))
end
