using TupleTools
import TupleTools: ntuple, StaticLength

struct BitSetTuple{N}
    constraint::NTuple{N,BitSet}
end


BitSetTuple(::Val{N}) where {N} = BitSetTuple(ntuple((_) -> BitSet(1:N), StaticLength(N)))
BitSetTuple(N::Int) = BitSetTuple(Val(N))
BitSetTuple(labels::AbstractArray) =
    BitSetTuple(ntuple((i) -> BitSet(labels[i]), StaticLength(length(labels))))
BitSetTuple(labels::NTuple{N,T}) where {N,T} =
    BitSetTuple(ntuple((i) -> BitSet(labels[i]), StaticLength(N)))


getconstraint(c::BitSetTuple{N} where {N}) = c.constraint
Base.intersect!(left::BitSetTuple{N}, right::BitSetTuple{N}) where {N} =
    intersect!.(getconstraint(left), getconstraint(right))
Base.:(==)(left::BitSetTuple{N}, right::BitSetTuple{N}) where {N} =
    getconstraint(left) == getconstraint(right)

function complete!(constraint::BitSetTuple, max_element::Int)
    constraint_sets = getconstraint(constraint)
    for node = 1:max_element
        if !any(node .∈ constraint_sets)    #If a variable does not occur in any group
            Base.push!.(constraint_sets, node)   #Add it to all groups
        end
    end
end

function convert_to_constraint(constraint::BitSetTuple, max_element::Int)
    constraint_sets = getconstraint(constraint)
    result = map(
        node -> union(constraint_sets[findall(node .∈ constraint_sets)]...),
        ntuple((i) -> i, StaticLength(max_element)),
    )
    return BitSetTuple(result)
end
