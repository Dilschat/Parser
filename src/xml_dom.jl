import Base.print
abstract type AbstractElement end

Base.iterate(node::AbstractElement, state::AbstractElement = node) = (state, getnext(state))
Base.iterate(node::AbstractElement, state::Nothing) = nothing

getname(node::AbstractElement) = nothing
getnext(node::AbstractElement) = nothing

shift!(node::AbstractElement, offset::Int64, whocalled::Type = Element) = throw(MethodError(shift!, "method should be implemented"))
shift!(n::Nothing, i::Int64, whocalled) = nothing
setposition!(node::AbstractElement, position::Position) = throw(MethodError("method should be implemented"))
getvalue(node::AbstractElement) = throw(MethodError("method should be implemented"))
print(node::AbstractElement) = throw(MethodError("method should be implemented"))

getposition(node::AbstractElement) = throw(MethodError("method should be implemented"))

getattribute(node::AbstractElement) = throw(MethodError("method should be implemented"))
setattribute!(node::AbstractElement) = throw(MethodError("method should be implemented"))

get(node::AbstractElement) = throw(MethodError("method should be implemented"))
get(node::AbstractElement) = throw(MethodError("method should be implemented"))

append!(node::AbstractElement) = throw(MethodError("method should be implemented"))
shift!(node::Nothing, i::Int64) = nothing
Parent = Union{AbstractElement,Nothing}

mutable struct TextElement <: AbstractElement
    input::StringBuffer
    value::Position
    parent::Parent
end
TextElement(input::StringBuffer, value::Position) = TextElement(input, value, nothing)
getvalue(node::TextElement) = node.input[node.value]
getposition(node::TextElement) = node.value
Base.print(io::IO, node::TextElement) = Base.print(io, getvalue(node))
Base.last(node::TextElement) = node
mutable struct Attribute <: AbstractElement
    input::StringBuffer
    name::Position
    value::Position
    parent::Parent
    next::Parent
end

Attribute(buffer::StringBuffer, name::Position, value::Position) =
    Attribute(buffer, name, value, nothing, nothing)

getname(node::Attribute) = node.input[node.name]
getnext(node::Attribute) = node.next
getposition(node::Attribute) = first(node.name):last(node.value)+1
getvalue(node::Attribute) = node.input[node.value]
getparent(node::Attribute) = node.parent
Base.last(node::Attribute) =  begin
    while !isnothing(node.next)
        node = next
    end
    return node
end
setnext!(dest::Attribute, newattr::Attribute) = last(dest).next = newattr
setattributevalue!(node::Attribute, value::String) = begin
    old_length = length(node.value)
    offset = ncodeunits(value) - old_length
    replace!(node.input, value, node.value)
    node.value = first(node.value):first(node.value)+ncodeunits(value)-1
    shift!(node.next, offset)
    shift!(node.parent, offset, Attribute)
    alignattributes!(getparent(getparent(node)))
end

shift!(node::Attribute, offset::Int64) = begin
    node.name = node.name .+ offset
    node.value = node.value .+ offset
    if !isnothing(node.next) shift!(node.next, offset) end
end

Base.print(io::IO, node::Attribute) = print(io, node.input, getposition(node))

ChildElement = Union{AbstractElement, Nothing}
mutable struct Element <: AbstractElement
    input::StringBuffer
    name::Position
    attributes::Union{Nothing, Attribute}
    value::ChildElement
    parent::Parent
    next::Parent
end

getnext(node::Element) = node.next
getname(node::Element) = node.input[node.name]
getvalue(node::Element) = node.value
Base.last(node::Element) = begin
    while !isnothing(node.next)
        node = node.next
    end
    return node
end
getposition(node::Element) = begin
    namestartbound = first(node.name)
    valuebound = if isnothing(node.value)
                    isnothing(node.attributes) ?
                        last(node.name) :
                        last(getposition(last(node.attributes)))
                else
                    last(getposition(last(node.value)))
                end
    return findprev(node.input, "<", namestartbound - 1):findnext(node.input, ">", valuebound + 1)
end

getattribute(node::Element, name::String) = begin
    isnothing(node.attributes) && return nothing
    for i in node.attributes
        if name == getname(i) return i end
    end
    return nothing
end

getattribute(node::Element, idx::Int64) = begin
    isnothing(node.attributes) && return nothing
    i = 1
    for attr in node.attributes
        if i == idx return attr end
        i = i + 1
    end
    return nothing
end

Base.getindex(node::Element, key::String, default = nothing) = begin
    isnothing(node.value) && return nothing
    for i in node.value
        if key == getname(i) return i end
    end
    return default
end

Base.getindex(node::Element, key::Int64, default = nothing) = begin
    isnothing(node.value) && return nothing
    i = 1
    for val in node.value
        if i == key return val end
        i = i + 1
    end
    return default
end
getparent(node::Element) = node.parent

alignattributes!(node::Element) = begin
    values = getvalue(node)
    maxbound = maximum(v -> last(getposition(v.name))+1, values)
    collected_values = ()
    for i in values
        collected_values = (collected_values..., i.attributes)
    end
    cimulativeoffset = alignattributes!(collected_values, maxbound)
    cimulativeoffset == 0 && return
    shift(node, cumulativeoffset, Attribute)
end

alignattributes!(prev::Tuple, maxbound::Int64) = begin
    collectted_attrs = prev
    cumulativeoffset = 0
    while !isempty(collectted_attrs)
        attrs_with_offsets = map(a -> (a, findprev(a.input, "prev", first(getposition(a)))), collectted_attrs)
        groupped_attrs = _groupby(p -> getname(p[1]), attrs_with_offsets)
        for attributes in groupped_attrs
            minoffset = _findmostleft(attributes)
            cumulativeoffset += minoffset > maxbound ?
                _normalizeindents(attributes, minoffset) :
                _normalizeindents(attributes, maxbound+1)
            maxbound = _findmaxlength(attributes) + minoffset > maxbound ?
                _normalizeindents(attributes, minoffset) :
                _normalizeindents(attributes, maxbound+1)
        end
        collectted_attrs = filter(p -> !isnothing(p), map(p -> p.next, prev))
    end
    return cumulativeoffset
end

_normalizeindents(attributes_with_offsets::Tuple, requiredoffset::Int64) = begin
    cumulativeoffset = 0
    for a in attributes
        buffer = a.input
        curoffset = a[2]
        shift = requiredoffset - curoffset
        shift == 0 && return
        shift > 0 ?
            insert!(buffer," "^shift, curoffset) :
            delete!(buffer, curoffset-shift:curoffset)
        shift!(a, shift)
        cumulativeoffset += shift
    end
    return cumulativeoffset
end

_groupby(f, collection) = begin
    sorteddtuple = ()
    for i in collection
        if isempty(sorteddtuple)
            sorteddtuple = ((i,),)
            continue
        else
            found = false
            temp = ()
            for group in sorteddtuple
                if getname(i[1]) == getname(group[1][1])
                    temp = (temp..., (group..., i,),)
                    found = true
                else
                    temp = (temp..., group,)
                end

            end
            if !found temp = (temp..., (i,),) end
            sorteddtuple = temp
        end
    end
    sorteddtuple = _sortbyoffset(sorteddtuple)
    return sorteddtuple
end

_sortbyoffset(collection) = begin
    sorted = ()
    for attrs_with_offset in collection
        if isempty(sorted)
            sorted = (attrs_with_offset,)
            continue
        end
        for i in eachindex(sorted)
            if _isless(attrs_with_offset, sorted[i])
                sorted = (sorted[begin:i-1]..., attrs_with_offset, sorted[i:end]..., )
                break
            end
            if i == length(sorted)
                sorted = (sorted..., attrs_with_offset, )
                break
            end
        end
    end
    return sorted
end

_isless(a::Tuple, b::Tuple) = _findmostleft(a) < _findmostleft(b)

_findmostleft(attributes_with_offsets::Tuple) = minimum(a -> a[2], attributes_with_offsets)

_findmaxlength(attributes_with_offsets::Tuple) = maximum(a -> length(getposition(a[1])), attributes_with_offsets)

setparent!(dest::Element, parent::Parent) = dest.parent = parent
setnext!(dest::Element, newelmnt::Element) = dest.next = newelmnt
Base.append!(node::Element, name::String, value::String) = begin
    newnode = "<$name>$value</$name>"
    lastchild = last(node.value)
    offset = last(getposition(lastchild)) + 1
    taglength = 1
    nameposition = offset + taglength:offset + ncodeunits(name)
    valuestart = last(nameposition) + taglength + 1
    valueposition =  valuestart:valuestart + ncodeunits(value) - 1
    textvalue = TextElement(node.input, valueposition)
    newelmnt = Element(node.input, nameposition, textvalue, node)
    if isnothing(lastchild)
        node.value = newelmnt
    else
        lastchild.next = newelmnt
    end
    insert!(node.input, newnode, offset)
end

Element(input::StringBuffer, name::Position, value::TextElement, parent::Parent) = begin
    new_element = Element(input, name, nothing, value, nothing, parent)
    return new_element
end

#TODO gереписать шифты, сделать их независимымыми
shift!(node::Element, offset::Int64, whocalled::Type{ChildElement}) = begin
    isnothing(node.next) ? shift!(node.parent, offset, ChildElement) : shift!(node.next, offset)
end

shift!(node::Element, offset::Int64, whocalled::Type{Element}) = begin
    node.name = node.name .+ offset
    shift!(node.attributes, offset)
    shift!(node.value, offset, Element)
    isnothing(node.next) ? shift!(node.parent, offset, ChildElement) : shift!(node.next, offset, Element)
end

shift!(node::Element, offset::Int64, whocalled::Type{Attribute}) = begin
    shift!(node.value, offset, Element)
    isnothing(node.next) ? shift!(node.parent, offset, ChildElement) : shift!(node.next, offset, Element)
end
shift!(node::TextElement, offset::Int64, whocalled::Type{Element}) = node.value = node.value .+ offset

Base.print(io::IO, node::Element) = print(io, node.input, getposition(node))

struct Document <: AbstractElement
    input::StringBuffer
    root::Element
end

alignattributes!(node::Document) = nothing

getvalue(node::Document) = node.root
Base.getindex(node::Document, key::String, default = nothing) = getname(node.root) == key ? node.root : nothing



shift!(node::Document, offset::Int64, whocalled::Type) = nothing

Base.print(io::IO, node::Document) = Base.print(io, node.input)
