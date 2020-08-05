function generateInterfaceForField(field_name::Symbol, index::Int)
    return "self.i[:$(field_name)] = self.interfaces[$(index)] = associate!(Interface(self), $(field_name))\n"
end

function generateInterfacesForFields(field_names::Tuple)
    code = ""
    for (i, field_name) in enumerate(field_names)
        code *= generateInterfaceForField(field_name, i+1)
    end
    return code
end

function generateCodeForDistribution(dist::Type{<:Distribution})
    name = nameof(dist)
    field_names = fieldnames(dist)

    node_template = """
    mutable struct $(name)Node <: SoftFactor
        id::Symbol
        interfaces::Vector{Interface}
        i::Dict{Symbol,Interface}
    
        function $(name)Node(out, $(join(field_names, ", ")); id=generateId($(name)Node))
            @ensureVariables(out, $(join(field_names, ", ")))
            self = new(id, Array{Interface}(undef, $(length(field_names)+1)), Dict{Symbol,Interface}())
            addNode!(currentGraph(), self)
            self.i[:out] = self.interfaces[1] = associate!(Interface(self), out)
            $(generateInterfacesForFields(field_names))
            return self
        end
    end
    """
    
    eval(Meta.parse(node_template))
    eval(Meta.parse("export $(name)Node"))
end

function nonabstractsubtypes(datatype::Type)
    leafs = []
    stack = Type[datatype]
    # push!(stack, datatype)
    while !isempty(stack)
        for T in subtypes(pop!(stack))
            if !isabstracttype(T)
                push!(leafs, T)
            else
                push!(stack, T)
            end
        end
    end

    return leafs
end

distribution_types = nonabstractsubtypes(Distribution)

for distribution in distribution_types
    try 
        generateCodeForDistribution(distribution)
    catch e
        println("problem")
    end
end
