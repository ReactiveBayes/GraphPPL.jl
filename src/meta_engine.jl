struct FactorMetaDescriptor{T}
    fform::Any
    fargs::T
end
fform(m::FactorMetaDescriptor) = m.fform
fargs(m::FactorMetaDescriptor) = m.fargs

Base.show(io::IO, m::FactorMetaDescriptor{Nothing}) = print(io, m.fform)
function Base.show(io::IO, m::FactorMetaDescriptor{<:Tuple})
    print(io, m.fform)
    print(io, "(", join(m.fargs, ", "), ")")
end

struct VariableMetaDescriptor
    node_descriptor::IndexedVariable
end

Base.show(io::IO, m::VariableMetaDescriptor) = print(io, m.node_descriptor)

const NodeMetaDescriptor = Union{FactorMetaDescriptor, VariableMetaDescriptor}

struct MetaObject{S <: NodeMetaDescriptor, T}
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

struct MetaSpecification
    meta_objects::Vector
    submodel_meta::Vector
end

getmetaobjects(m::MetaSpecification) = m.meta_objects
getsubmodelmeta(m::MetaSpecification) = m.submodel_meta
getspecificsubmodelmeta(m::MetaSpecification) = filter(m -> is_specificsubmodelmeta(m), getsubmodelmeta(m))
getgeneralsubmodelmeta(m::MetaSpecification) = filter(m -> is_generalsubmodelmeta(m), getsubmodelmeta(m))

# TODO experiment with `findfirst` instead of `get` in benchmarks
getspecificsubmodelmeta(m::MetaSpecification, tag::Any) = get(filter(m -> getsubmodel(m) == tag, getsubmodelmeta(m)), 1, nothing)
getgeneralsubmodelmeta(m::MetaSpecification, fform::Any) = get(filter(m -> getsubmodel(m) == fform, getsubmodelmeta(m)), 1, nothing)

struct SpecificSubModelMeta
    tag::FactorID
    meta_objects::MetaSpecification
end

getsubmodel(c::SpecificSubModelMeta) = c.tag
getmetaobjects(c::SpecificSubModelMeta) = c.meta_objects
Base.push!(m::SpecificSubModelMeta, o) = push!(m.meta_objects, o)
SpecificSubModelMeta(tag::FactorID) = SpecificSubModelMeta(tag, MetaSpecification())
is_specificsubmodelmeta(m::SpecificSubModelMeta) = true
is_specificsubmodelmeta(m) = false
getkey(m::SpecificSubModelMeta) = getsubmodel(m)

struct GeneralSubModelMeta
    fform::Any
    meta_objects::MetaSpecification
end

getsubmodel(c::GeneralSubModelMeta) = c.fform
getmetaobjects(c::GeneralSubModelMeta) = c.constraints
Base.push!(m::GeneralSubModelMeta, o) = push!(m.meta_objects, o)
GeneralSubModelMeta(fform::Any) = GeneralSubModelMeta(fform, MetaSpecification())
is_generalsubmodelmeta(m::GeneralSubModelMeta) = true
is_generalsubmodelmeta(m) = false
getkey(m::GeneralSubModelMeta) = getsubmodel(m)

const SubModelMeta = Union{GeneralSubModelMeta, SpecificSubModelMeta}

MetaSpecification() = MetaSpecification(Vector{MetaObject}(), Vector{SubModelMeta}())
Base.push!(m::MetaSpecification, o::MetaObject) = push!(m.meta_objects, o)
Base.push!(m::MetaSpecification, o::SubModelMeta) = push!(m.submodel_meta, o)

function apply!(model::Model, meta::MetaSpecification)
    apply!(model, GraphPPL.get_principal_submodel(model), meta)
end

function apply!(model::Model, context::Context, meta::MetaSpecification)
    for meta_obj in getmetaobjects(meta)
        apply!(model, context, meta_obj)
    end
    for (factor_id, child) in children(context)
        if (submodel = getspecificsubmodelmeta(meta, factor_id)) !== nothing
            apply!(model, child, getmetaobjects(submodel))
        elseif (submodel = getgeneralsubmodelmeta(meta, fform(factor_id))) !== nothing
            apply!(model, child, getmetaobjects(submodel))
        end
    end
end

function apply!(model::Model, context::Context, meta::MetaObject{S, T} where {S <: VariableMetaDescriptor, T})
    nodes = unroll(context[getnodedescriptor(meta).node_descriptor])
    apply!(model, context, meta, nodes)
end

apply!(model::Model, context::Context, meta::MetaObject{S, T} where {S <: VariableMetaDescriptor, T}, node::NodeLabel) = save_meta!(model, node, meta)

function apply!(model::Model, context::Context, meta::MetaObject{S, T} where {S <: VariableMetaDescriptor, T}, nodes::AbstractArray{NodeLabel})
    for node in nodes
        save_meta!(model, node, meta)
    end
end

function apply!(model::Model, context::Context, meta::MetaObject{S, T} where {S <: FactorMetaDescriptor{<:Tuple}, T})
    applicable_nodes = Iterators.filter(node -> node ∈ values(factor_nodes(context)), filter(as_node(fform(getnodedescriptor(meta))), model))
    for node in applicable_nodes
        neighborhood = neighbors(model, node)
        save = true
        for variable in fargs(getnodedescriptor(meta))
            if !any(vertex -> vertex ∈ neighborhood, unroll(context[variable]))
                # @show node
                save = false
            end
        end
        if save
            save_meta!(model, node, meta)
        end
    end
end

function apply!(model::Model, context::Context, meta::MetaObject{S, T} where {S <: FactorMetaDescriptor{Nothing}, T})
    applicable_nodes = Iterators.filter(node -> node ∈ values(factor_nodes(context)), filter(as_node(fform(getnodedescriptor(meta))), model))
    for node in applicable_nodes
        save_meta!(model, node, meta)
    end
end

function save_meta!(model::Model, node::NodeLabel, meta::MetaObject{S, T} where {S, T})
    options(model[node]).meta = getmetainfo(meta)
end
