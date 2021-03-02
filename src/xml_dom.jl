export AbstractElement, Element, Attribute, TextElement, print, iterate, getindex,
    append!, getattribute, getvalue, setvalue!


import Base: print, iterate, getindex, isnothing, last, append!, findprev
using UnsafeArrays
include("utils.jl")
include("string_buffer.jl")



Position = UnitRange{Int64}
abstract type AbstractElement end

"Text value of xml node : <name>TextElement</name>"
mutable struct TextElement{T<:AbstractElement} <: AbstractElement
    input::StringBuffer
    value::Position
    parent::Union{T,Nothing}
end

"Attribute of xml node"
mutable struct Attribute{T<:AbstractElement} <: AbstractElement
    input::StringBuffer
    name::Position
    value::Position
    parent::Union{T,Nothing}
    index::Int
end

mutable struct Element <: AbstractElement
    input::StringBuffer
    name::Position
    attributes::Union{Nothing,Vector{Attribute{Element}}}
    value::Union{Vector{Element},TextElement{Element},Nothing}
    parent::Union{Element,Nothing}
    index::Int
end

const EMPRTSTRINGVEIW = StringView(uview(unsafe_wrap(Vector{UInt8}, ""), 1:0))
const CONTAINER_FOR_ATTRS = Vector{Attribute{Element}}()
const CONTAINER_FOR_SORTED_ATTRS =
    Vector{Vector{Tuple{Attribute{Element},Int64}}}()
const ATTRS_WITH_OFFSETS = Vector{Tuple{Attribute{Element},Int64}}()

Parent = Union{Element,Nothing}
ChildElement = Union{TextElement,Vector{Element},Nothing}

"Outer constructors"
TextElement{Element}(input::StringBuffer, value::Position) =
    TextElement{Element}(input, value, nothing)
Attribute{Element}(buffer::StringBuffer, name::Position, value::Position) =
    Attribute{Element}(buffer, name, value, nothing, 1)
Element(input::StringBuffer, name::Position) = begin
    element = Element(input, name, nothing, nothing, nothing, 1)
end

Element(
    input::StringBuffer,
    name::Position,
    value::TextElement,
    parent::Parent,
) = begin
    new_element = Element(input, name, nothing, value, parent, 1)
    return new_element
end

Element(input::StringBuffer, value::Element) = begin
    new_element = Element(input, 1:0, nothing, [value], nothing, 1)
    return new_element
end

"""
    Implementation of iterate interface for all AbstractElements, that implements
        getnext() interface
"""
iterate(node::AbstractElement, state::AbstractElement = node) =
    (state, getnext(state))
iterate(node::AbstractElement, state::Nothing) = nothing

"Returns a child element that fits provided key(String) or index(Int)"
getindex(node::Element, key::AbstractString) = begin
    isnothing(node.value) && return throw(KeyError("no element with key: $key"))
    for i in eachindex(node.value)
        child = @inbounds node.value[i]
        if _equals(getname(child), key)
            return child
        end
    end
    return throw(KeyError("no element with key: $key"))
end

getindex(node::Element, key::Int64) =
    try
        return node.value[key]
    catch e
        throw(KeyError("no element with key: $key"))
    end

"Returns attribute by key(String) or index(Int)"
getattribute(node::Element, name::AbstractString) = begin
    if !isnothing(node.attributes)
        for i in eachindex(node.attributes)
            attr = @inbounds node.attributes[i]
            if _equals(getname(attr), name)
                return attr
            end
        end
    end
    return throw(KeyError("no attribute with key: $key"))
end

getattribute(node::Element, idx::Int64) = begin
    try
        return node.attributes[idx]
    catch e
        return throw(KeyError("no attribute with key: $idx"))
    end
end

"""
    Returns range(start index, final index) of element in string that represents
    xml document
"""
getposition(node::AbstractElement) =
    error("no position of element of type $(typeof(node))")
getposition(node::TextElement) = node.value
getposition(node::Attribute) = first(node.name):last(node.value)+1
getposition(node::Element) = begin
    namestartbound = first(node.name)
    valuebound = if isnothing(node.value)
        isnothing(node.attributes) ? last(node.name) :
        last(getposition(last(node.attributes)))
    else
        last(getposition(last(node.value)))
    end
    return findprev(
        node.input,
        "<",
        namestartbound - 1,
    ):findnext(node.input, ">", valuebound + 1)
end


"Returns a name of node"
getname(node::Nothing) = EMPRTSTRINGVEIW
getname(node::AbstractElement) = EMPRTSTRINGVEIW
getname(node::Attribute) = @inbounds node.input[node.name]
getname(node::Element) = @inbounds node.input[node.name]

"Returns the next node (siblings of attributes or elements)"
getnext(node::AbstractElement) = nothing
getnext(node::Attribute) =
    try
        getattribute(node.parent, node.index + 1)
    catch e
        return nothing
    end

getnext(node::Element) = begin
    if isnothing(node.parent)
        return nothing
    else
        try
            return node.parent[node.index+1]
        catch e
            return nothing
        end
    end
end

"Returns a child of node"
getvalue(node::AbstractElement) = nothing
getvalue(node::Attribute) = @inbounds node.input[node.value]
getvalue(node::TextElement) = @inbounds node.input[node.value]
getvalue(node::Element) = node.value

isroot(node::AbstractElement) = false
isroot(node::Element) = isnothing(getparent(node))

"Returns a child of node"
getparent(node::AbstractElement) = nothing
getparent(node::Attribute) = node.parent
getparent(node::Element) = node.parent

last(node::AbstractElement) = node

print(node::AbstractElement) =
    error("can't print element of type $(typeof(node))")
print(io::IO, node::TextElement) = print(io, getvalue(node))
print(io::IO, node::Attribute) = print(io, node.input, getposition(node))
print(io::IO, node::Element) =
    isroot(node) ? print(io, node.input) :
    print(io, node.input, getposition(node))

"Assigns a new child element or string value"
setvalue!(dest::Element, child::ChildElement) = dest.value = child
setvalue!(node::Attribute, value::String) = begin
    old_length = length(node.value)
    new_length = ncodeunits(value)
    offset = new_length - old_length
    replace!(node.input, value, node.value)
    node.value = first(node.value):first(node.value)+new_length-1
    _shift!(getnext(node), offset)
    _shift!(getparent(node), offset, Attribute)
    _alignattributes!(getparent(getparent(node)))
end

setparent!(dest::TextElement, parent::Parent) = dest.parent = parent
setparent!(dest::Element, parent::Parent) = dest.parent = parent
setparent!(dest::Attribute, parent::Parent) = dest.parent = parent

"Appends a sibling to last child node"
append!(node::AbstractElement) =
    error("can't append an element to an element of type $(typeof(node))")

append!(node::Element, name::String, value::String) = begin
    newnode = "<$name>$value</$name>"
    lastchild = last(node.value)
    offset =
        isnothing(lastchild) ? findnext(node.input, ">", last(node.name)) :
        last(getposition(lastchild))
    offset = offset + 1
    taglength = 1
    nameposition = offset+taglength:offset+ncodeunits(name)
    valuestart = last(nameposition) + taglength + 1
    valueposition = valuestart:valuestart+ncodeunits(value)-1
    if isnothing(lastchild)
        textvalue = TextElement{Element}(node.input, valueposition)
        newelmnt = Element(node.input, nameposition, textvalue, node)
        node.value = [newelmnt]
    else
        startelement = first(getposition(lastchild))
        indentstart = findprev(node.input, '\n', startelement)
        indentsize =
            isnothing(indentstart) ? 0 : startelement - 1 - indentstart
        indent = "\n" * " "^(indentsize)
        newnode = indent * newnode
        textvalue = TextElement{Element}(
            node.input,
            valueposition .+ (indentsize + 1),
        )
        newelmnt = Element(
            node.input,
            nameposition .+ (indentsize + 1),
            textvalue,
            node,
        )
        append!(node, newelmnt)
    end
    insert!(node.input, newnode, offset)
    _shift!(node, ncodeunits(newnode), ChildElement)
end

append!(parent_element::Element, element::Element) = begin
    parent_element.value = _getupdatedchild!(parent_element.value, element)
    element.parent = parent_element
end

_getupdatedchild!(value::Nothing, newchild::Element) = [newchild]
_getupdatedchild!(value::TextElement, newchild::Element) =
    isnothing(value) ? newchild :
    error("cannot add child to text with value: $(value.input[value.value])")

_getupdatedchild!(value::Vector{Element}, newchild::Element) = begin
    push!(value, newchild)
    newchild.index = length(value)
    return value
end

_getupdatedchild!(value::Vector{Element}, newchild::TextElement) =
    error("cannot add text")

"Appends a sibling attribute to last attribute"
_alignattributes!(node::Nothing) = nothing
_alignattributes!(node::AbstractElement) = nothing
addattribute!(element::Element, attribute::Attribute) = begin
    if isnothing(element.attributes)
        element.attributes = Vector{Attribute{Element}}()
    end
    push!(element.attributes, attribute)
    attribute.index = length(element.attributes)
    attribute.parent = element
end

_alignattributes!(node::Element) = begin
    maxbound = -1
    len = length(node.value)
    collected_values = resize!(CONTAINER_FOR_ATTRS, 0)
    if isnothing(node.value)
        return nothing
    end
    for i in eachindex(node.value)
        attrs = node.value[i].attributes
        if !isnothing(attrs)
            append!(collected_values, attrs)
        end
    end
    cumulativeoffset = _alignattributes!(collected_values, maxbound)
    cumulativeoffset == 0 && return nothing
    _shift!(node, cumulativeoffset, ChildElement)
end

_alignattributes!(allattrs::Vector{Attribute{Element}}, maxbound::Int64) = begin
    cumulativeoffset = 0
    groupped_attrs = _groupby(p -> getname(p), allattrs)
    for attributes in groupped_attrs
        attributes = _update_offsets(attributes)
        minoffset = _findmostleft(attributes)
        requiredoffset = minoffset > maxbound ? minoffset : maxbound + 1
        cumulativeoffset += _normalizeindents(attributes, requiredoffset)
        maxbound = requiredoffset + _findmaxlength(attributes)
    end
    return cumulativeoffset
end

_normalizeindents(
    attributes_with_offsets::Vector{Tuple{Attribute{Element},Int64}},
    requiredoffset::Int64,
) = begin
    cumulativeoffset = 0
    shift = 0
    for i in eachindex(attributes_with_offsets)
        a = @inbounds attributes_with_offsets[i]
        _shift!(a[1].parent, shift)
        buffer = a[1].input
        curoffset = a[2]
        shift = requiredoffset - curoffset
        shift == 0 && continue
        startposition = first(getposition(a[1]))
        shift > 0 ? insert!(buffer, ' '^shift, startposition) :
        delete!(buffer, startposition+shift:startposition-1)
        _shift!(a[1], shift)
        _shift!(a[1].parent.value, shift)
        cumulativeoffset += shift
    end
    return cumulativeoffset
end

_groupby(f, attrs::Vector{Attribute{Element}}) = begin
    sorteddtuple = resize!(CONTAINER_FOR_SORTED_ATTRS, 0)
    collection = _calculate_offsets(attrs)
    for attr_with_offset in collection
        found = false
        for group in sorteddtuple
            if _equals(getname(attr_with_offset[1]), getname(group[1][1]))
                push!(group, attr_with_offset)
                found = true
            end
        end
        if !found
            push!(sorteddtuple, [attr_with_offset])
        end
    end
    sorteddtuple = _sortbyoffset(sorteddtuple)
    return sorteddtuple
end

_sortbyoffset(collection::Vector{Vector{Tuple{Attribute{Element},Int64}}}) =
    sort!(collection, lt = _isless, alg = QuickSort)

_calculate_offsets(attributes::Vector{Attribute{Element}}) = begin
    resize!(ATTRS_WITH_OFFSETS, length(attributes))
    map!(
        a -> (
            a,
            first(getposition(a)) -
            findprev(a.input, '\n', first(getposition(a))),
        ),
        ATTRS_WITH_OFFSETS,
        attributes,
    )
end

_update_offsets(attributes::Vector{Tuple{Attribute{Element},Int64}}) = begin
    map!(
        a -> (
            a[1],
            first(getposition(a[1])) -
            findprev(a[1].input, '\n', first(getposition(a[1]))),
        ),
        attributes,
        attributes,
    )
end

_isless(
    a::Vector{Tuple{Attribute{Element},Int64}},
    b::Vector{Tuple{Attribute{Element},Int64}},
) = _findmostleft(a) < _findmostleft(b)

_findmostleft(
    attributes_with_offsets::Vector{Tuple{Attribute{Element},Int64}},
) = minimum(a -> a[2], attributes_with_offsets)

_findmaxlength(
    attributes_with_offsets::Vector{Tuple{Attribute{Element},Int64}},
) = maximum(a -> length(getposition(a[1])), attributes_with_offsets)

_shift!(node::Attribute, offset::Int64) = begin
    i = node.index
    attrs = node.parent.attributes
    len = length(attrs)
    while i <= len
        node = @inbounds attrs[i]
        node.name = node.name .+ offset
        node.value = node.value .+ offset
        i += 1
    end
end

_shift!(attrs::Vector{Attribute{Element}}, offset::Int64) = foreach(a -> begin
    a.name = a.name .+ offset
    a.value = a.value .+ offset
end, attrs)

_shift!(node::Element, offset::Int64, whocalled::Type{ChildElement}) = begin
    next = getnext(node)
    if !isnothing(next)
        _shift!(next, offset)
    end
    _shift!(node.parent, offset, ChildElement)
end

_shift!(elements::Vector{Element}, offset::Int64) = foreach(node -> begin
    node.name = node.name .+ offset
    _shift!(node.attributes, offset)
    _shift!(node.value, offset)
end, elements)

_shift!(node::Element, offset::Int64) = begin
    i = node.index
    elements = node.parent.value
    len = length(elements)
    while i <= len
        node = @inbounds elements[i]
        node.name = node.name .+ offset
        _shift!(node.attributes, offset)
        _shift!(node.value, offset)
        i += 1
    end
end

_shift!(node::Element, offset::Int64, whocalled::Type{Element}) = begin
    _shift!(node, offset)
    if !isnothing(node.parent)
        _shift!(node.parent, offset, ChildElement)
    end
end

_shift!(node::Element, offset::Int64, whocalled::Type{Attribute}) = begin
    _shift!(node.value, offset)
    next = getnext(node)
    if !isnothing(next)
        _shift!(next, offset)
    end
    if !isnothing(node.parent)
        _shift!(node.parent, offset, ChildElement)
    end
end

_shift!(node::TextElement, offset::Int64) = begin
    if !isnothing(node)
        node.value = node.value .+ offset
    end
end

_shift!(node::AbstractElement, offset::Int64, whocalled) = nothing
_shift!(node::Nothing, i::Int64, whocalled) = nothing
_shift!(node::Nothing, i::Int64) = nothing

"""
    Comparison implementation due to slow comparison of StringView with String
"""
_equals(a::StringView, b::AbstractString) = begin
    if ncodeunits(a) != ncodeunits(b)
        return false
    end
    _memcmp(pointer(b), pointer(a.data), length(a.data)) == 0
end
