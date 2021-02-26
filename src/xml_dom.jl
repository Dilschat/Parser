import Base.print
abstract type AbstractElement end
include("string_buffer.jl")

Position = UnitRange{Int64}

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

struct Document <: AbstractElement
    input::StringBuffer
    root::AbstractElement
end

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
    parent::Union{AbstractElement,Nothing}
    next::Union{Attribute,Nothing}
end
mutable struct Element <: AbstractElement
    input::StringBuffer
    name::Position
    attributes::Union{Nothing, Attribute}
    value::Union{TextElement, Element, Nothing}
    parent::Union{Document, Element,Nothing}
    next::Union{Element,Nothing}
end
ChildElement = Union{TextElement, Element, Nothing}


Attribute(buffer::StringBuffer, name::Position, value::Position) =
    Attribute(buffer, name, value, nothing, nothing)

getname(node::Attribute) = node.input[node.name]
getnext(node::Attribute) = node.next
getposition(node::Attribute) = first(node.name):last(node.value)+1
getvalue(node::Attribute) = node.input[node.value]
getparent(node::Attribute) = node.parent
Base.last(node::Attribute) =  begin
    while !isnothing(node.next)
        node = node.next
    end
    return node
end
setnext!(dest::Attribute, newattr::Attribute) = last(dest).next = newattr
setattributevalue!(node::Attribute, value::String) = begin
    old_length = length(node.value)
    new_length = ncodeunits(value)
    offset = new_length - old_length
    replace!(node.input, value, node.value)
    node.value = first(node.value):first(node.value)+new_length-1
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
Base.last(node::Element) = begin
    while !isnothing(node.next)
        node = node.next
    end
    return node
end

alignattributes!(node::Element) = begin
    values = getvalue(node)
    maxbound = -1#maximum(v -> 1 + last(v.name) - findprev(node.input, "\n", first(v.name)), values)
    collected_values = ()
    for i in values
        collected_values = (collected_values..., i.attributes)
    end
    cumulativeoffset = alignattributes!(collected_values, maxbound)
    cumulativeoffset == 0 && return
    shift!(node, cumulativeoffset, ChildElement)
end

alignattributes!(prev::Tuple, maxbound::Int64) = begin
    collectted_attrs = filter(i -> !isnothing(i), prev)
    cumulativeoffset = 0
    allattrs = ()
    while !isempty(collectted_attrs)
        allattrs = (allattrs..., collectted_attrs...,)
        collectted_attrs = filter(p -> !isnothing(p), map(p -> p.next, collectted_attrs))
    end
    groupped_attrs = _groupby(p -> getname(p), allattrs)
    for attributes in groupped_attrs
        attributes = _update_offsets(attributes)
        minoffset = _findmostleft(attributes)
        requiredoffset = minoffset > maxbound ? minoffset : maxbound+1
        cumulativeoffset += _normalizeindents(attributes, requiredoffset)
        maxbound = requiredoffset + _findmaxlength(attributes)
    end
    return cumulativeoffset
end

_normalizeindents(attributes_with_offsets::Tuple, requiredoffset::Int64) = begin
    cumulativeoffset = 0
    for a in attributes_with_offsets
        shift!(a[1].parent, cumulativeoffset)
        buffer = a[1].input
        curoffset = a[2]
        shift = requiredoffset - curoffset
        shift == 0 && continue
        startposition = first(getposition(a[1]))
        shift > 0 ?
            insert!(buffer," "^shift, startposition) :
            delete!(buffer, startposition+shift:startposition-1)
        shift!(a[1], shift)
        shift!(a[1].parent.value, shift)
        #shift!(a[1].parent.parent.next, shift)
        cumulativeoffset += shift
    end
    return cumulativeoffset
end

_groupby(f, collection) = begin
    sorteddtuple = ()
    collection = _calculate_offsets(collection)
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

_calculate_offsets(attributes) = map(a -> (a, first(getposition(a)) - findprev(a.input, "\n", first(getposition(a)))), attributes)
_update_offsets(attributes) = map(a -> (a[1], first(getposition(a[1])) - findprev(a[1].input, "\n", first(getposition(a[1])))), attributes)

_isless(a::Tuple, b::Tuple) = _findmostleft(a) < _findmostleft(b)

_findmostleft(attributes_with_offsets::Tuple) = minimum(a -> a[2], attributes_with_offsets)

_findmaxlength(attributes_with_offsets::Tuple) = maximum(a -> length(getposition(a[1])), attributes_with_offsets)

setparent!(dest::Element, parent::Parent) = dest.parent = parent
setnext!(dest::Element, newelmnt::Element) = dest.next = newelmnt
setvalue!(dest::Element, child) = dest.value = child
addattribute!(element::Element, attribute::Attribute) = begin
    if isnothing(element.attributes)
        element.attributes = attribute
        attribute.parent = element
        return
    end
    lastattribute = last(element.attributes)
    lastattribute.next = attribute
    attribute.parent = element
end

addchild!(parent_element::Element, element::Element) = begin
    parent_element.value = _getupdatedchild!(parent_element.value, element)
    element.parent = parent_element
end

_getupdatedchild!(value::Nothing, newchild::Element) = newchild
_getupdatedchild!(value::TextElement, newchild::Element) = throw(DomainError(value, "cannot add child to text"))
_getupdatedchild!(value::Element, newchild::Element) = begin
    lastelement = last(value)
    lastelement.next = newchild
    return value
end
Base.append!(node::Element, name::String, value::String) = begin
    newnode = "<$name>$value</$name>"
    lastchild = last(node.value)
    offset = last(getposition(lastchild)) + 1
    taglength = 1
    nameposition = offset + taglength:offset + ncodeunits(name)
    valuestart = last(nameposition) + taglength + 1
    valueposition =  valuestart:valuestart + ncodeunits(value) - 1
    if isnothing(lastchild)
        textvalue = TextElement(node.input, valueposition)
        newelmnt = Element(node.input, nameposition, textvalue, node)
        node.value = newelmnt
    else
        startelement = first(getposition(lastchild))
        indentstart = Base.findprev(node.input, "\n", startelement)
        indentsize = isnothing(indentstart) ? 0 : startelement - 1 - indentstart
        indent = "\n"*" "^(indentsize)
        newnode = indent*newnode
        textvalue = TextElement(node.input, valueposition .+ (indentsize+1))
        newelmnt = Element(node.input, nameposition .+ (indentsize+1), textvalue, node)
        lastchild.next = newelmnt
    end
    insert!(node.input, newnode, offset)
    shift!(node, ncodeunits(newnode), ChildElement)
end

Element(input::StringBuffer, name::Position) = begin
    Element(input, name, nothing, nothing, nothing, nothing)
end
Element(input::StringBuffer, name::Position, value::TextElement, parent::Parent) = begin
    new_element = Element(input, name, nothing, value, parent, nothing)
    return new_element
end

#TODO gереписать шифты, сделать их независимымыми
shift!(node::Element, offset::Int64, whocalled::Type{ChildElement}) = begin
    isnothing(node.next) ? shift!(node.parent, offset, ChildElement) : shift!(node.next, offset, Element)
end

shift!(node::Element, offset::Int64) = begin
    node.name = node.name .+ offset
    shift!(node.attributes, offset)
    shift!(node.value, offset)
    if !isnothing(node.next) shift!(node.next, offset) end
end
shift!(node::Element, offset::Int64, whocalled::Type{Element}) = begin
    node.name = node.name .+ offset
    shift!(node.attributes, offset)
    shift!(node.value, offset)
    isnothing(node.next) ? shift!(node.parent, offset, ChildElement) : shift!(node.next, offset, Element)
end

shift!(node::Element, offset::Int64, whocalled::Type{Attribute}) = begin
    shift!(node.value, offset)
    isnothing(node.next) ? shift!(node.parent, offset, ChildElement) : shift!(node.next, offset, Element)
end
shift!(node::TextElement, offset::Int64) = node.value = node.value .+ offset

Base.print(io::IO, node::Element) = print(io, node.input, getposition(node))


alignattributes!(node::Document) = nothing

getvalue(node::Document) = node.root
Base.getindex(node::Document, key::String, default = nothing) = getname(node.root) == key ? node.root : nothing



shift!(node::Document, offset::Int64, whocalled::Type) = nothing

Base.print(io::IO, node::Document) = Base.print(io, node.input)
