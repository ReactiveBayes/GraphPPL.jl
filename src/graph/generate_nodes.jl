function generateCodeForDistribution(dist::Type{<:Distribution})
    name = nameof(dist)
    field_names = fieldnames(dist)

    target_expr = 
    """
        function $(name)Node()
            return Node{$name}($field_names, Set{Variable}(), $dist)
        end
        
        function $(name)Node(neighbors::Set{Variable})
            return Node{$name}($field_names, neighbors, $dist)
        end

        function $(name)Node(neighbors::Vector{Variable})
            return Node{$name}($field_names, Set(neighbors), $dist)
        end
    """
    println(target_expr)
    eval(Meta.parse(target_expr))
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
        println(e)
    end
end
