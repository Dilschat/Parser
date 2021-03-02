import Base.print
include("string_buffer.jl")
using UnsafeArrays
const emptystringview = StringView(uview(unsafe_wrap(Vector{UInt8}, ""), 1:0))

Position = UnitRange{Int64}

abstract type AbstractElement end

"Text value of xml node : <name>TextElement</name>"
mutable struct TextElement{T<:AbstractElement} <: AbstractElement
    input::StringBuffer
    value::Position
    parent::Union{T, Nothing}
end

"Attribute of xml node"
mutable struct Attribute{T<:AbstractElement} <: AbstractElement
    input::StringBuffer
    name::Position
    value::Position
    parent::Union{T, Nothing}
    index::Int
end

"Wrapper for xml document, that contains a root node of xml"
# struct Document{T<:AbstractElement } <: AbstractElement
#     input::StringBuffer
#     root::T
# end

mutable struct Element <: AbstractElement
    input::StringBuffer
    name::UnitRange{Int64}
    attributes::Union{Nothing, Vector{Attribute{Element}}}
    value::Union{Vector{Element}, TextElement{Element}, Nothing}
    parent::Union{Element, Nothing}
    index::Int
end

Parent = Union{Element, Nothing}
ChildElement = Union{TextElement, Vector{Element}, Nothing}

"Outer constructors"
TextElement{Element}(input::StringBuffer, value::Position) = TextElement{Element}(input, value, nothing)
Attribute{Element}(buffer::StringBuffer, name::Position, value::Position) =
    Attribute{Element}(buffer, name, value, nothing, 1)
Element(input::StringBuffer, name::Position) = begin
        element = Element(input, name, nothing, nothing, nothing, 1)
    end
Element(input::StringBuffer, name::Position, value::TextElement, parent::Parent) = begin
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
Base.iterate(node::AbstractElement, state::AbstractElement = node) = (state, getnext(state))
Base.iterate(node::AbstractElement, state::Nothing) = nothing

"Returns a child element that fits provided key(String) or index(Int)"
#Base.getindex(node::Document, key::AbstractString, default = nothing)::Element = _equals(getname(node.root), key) ? node.root : nothing
Base.getindex(node::Element, key::AbstractString) = begin
    if isnothing(node.value) return throw(KeyError("no element with key: $key")) end
    i = 1
    stop = length(node.value)
    while i <= stop
        if _equals(getname(@inbounds node.value[i]), key) return @inbounds node.value[i] end
        i+=1
    end
    return throw(KeyError("no element with key: $key"))
end


Base.getindex(node::Element, key::Int64) = begin
    try
        if !(1<=key<=length(node.value))
            return throw(KeyError("no element with key: $key"))
        end
        return @inbounds node.value[key]
    catch e
        return throw(KeyError("no element with key: $key"))
    end
end

"""
    Returns range(start index, final index) of element in string that represents
    xml document
"""
getposition(node::AbstractElement) = error("no position of element of type $(typeof(node))")
getposition(node::TextElement) = node.value
getposition(node::Attribute) = first(node.name):last(node.value)+1
getposition(node::Element) = begin
    namestartbound = first(node.name)
    valuebound = if Base.isnothing(node.value)
                    isnothing(node.attributes) ?
                        last(node.name) :
                        last(getposition(last(node.attributes)))
                else
                    last(getposition(last(node.value)))
                end
    return findprev(node.input, "<", namestartbound - 1):findnext(node.input, ">", valuebound + 1)
end


"Returns a name of node"
getname(node::Nothing) = emptystringview
getname(node::AbstractElement) = emptystringview
getname(node::Attribute) = node.input[node.name]
getname(node::Element) = node.input[getfield(node, :name)]

"Returns the next node (siblings of attributes or elements)"
getnext(node::AbstractElement) = nothing
getnext(node::Attribute) = try getattribute(node.parent, node.index+1) catch e return nothing end
getnext(node::Element) = begin
    if isnothing(node.parent)
        return nothing
    else
        try
            return node.parent[node.index+1]
        catch
            return nothing
        end
    end
end

"Returns a child of node"
getvalue(node::AbstractElement) = nothing
getvalue(node::Attribute) = @inbounds node.input[node.value]
getvalue(node::TextElement) = @inbounds node.input[node.value]
getvalue(node::Element) = node.value
#getvalue(node::Document) = node.root

isroot(node::AbstractElement) = false
isroot(node::Element) = isnothing(getparent(node))
"Returns a child of node"
getparent(node::AbstractElement) = nothing
getparent(node::Attribute) = node.parent
getparent(node::Element) = node.parent

Base.last(node::AbstractElement) = node



Base.print(node::AbstractElement) = error("can't print element of type $(typeof(node))")
Base.print(io::IO, node::TextElement) = Base.print(io, getvalue(node))
Base.print(io::IO, node::Attribute) = print(io, node.input, getposition(node))
Base.print(io::IO, node::Element) = isroot(node) ?
        print(io, node.input) :
        print(io, node.input, getposition(node))

"Returns attribute by key(String) or index(Int)"
getattribute(node::Element, name::AbstractString) = begin
    if !isnothing(node.attributes)
        i = 1
        stop = length(node.attributes)
        while i <= stop
            if _equals(getname( @inbounds node.attributes[i]), name) return  @inbounds node.attributes[i] end
            i += 1
        end
    end

    return throw(KeyError("no attribute with key: $key"))
end

getattribute(node::Element, idx::Int64) = begin
    try
        if !(1<=idx<=length(node.attributes)) return throw(KeyError("no attribute with key: $idx")) end
        return @inbounds node.attributes[idx]
    catch e
        return throw(KeyError("no attribute with key: $idx"))
    end
end

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
    # @code_warntype _alignattributes!(getparent(getparent(node)))
    _alignattributes!(getparent(getparent(node)))
end

setparent!(dest::TextElement, parent::Parent) = dest.parent = parent
setparent!(dest::Element, parent::Parent) = dest.parent = parent
setparent!(dest::Attribute, parent::Parent) = dest.parent = parent

"Appends a sibling to last child node"
Base.append!(node::AbstractElement) = error("can't append an element to an element of type $(typeof(node))")
Base.append!(node::Element, name::String, value::String) = begin
    newnode = "<$name>$value</$name>"
    lastchild = last(node.value)
    offset =  isnothing(lastchild) ? findnext(node.input, ">", last(node.name)) :
                                        last(getposition(lastchild))
    offset = offset + 1
    taglength = 1
    nameposition = offset + taglength:offset + ncodeunits(name)
    valuestart = last(nameposition) + taglength + 1
    valueposition =  valuestart:valuestart + ncodeunits(value) - 1
    if isnothing(lastchild)
        textvalue = TextElement{Element}(node.input, valueposition)
        newelmnt = Element(node.input, nameposition, textvalue, node)
        node.value = [newelmnt]
    else
        startelement = first(getposition(lastchild))
        indentstart = Base.findprev(node.input, "\n", startelement)
        indentsize = isnothing(indentstart) ? 0 : startelement - 1 - indentstart
        indent = "\n"*" "^(indentsize)
        newnode = indent*newnode
        textvalue = TextElement{Element}(node.input, valueposition .+ (indentsize+1))
        newelmnt = Element(node.input, nameposition .+ (indentsize+1), textvalue, node)
        append!(node, newelmnt)
    end
    insert!(node.input, newnode, offset)
    _shift!(node, ncodeunits(newnode), ChildElement)
end

Base.append!(parent_element::Element, element::Element) = begin
    parent_element.value = _getupdatedchild!(parent_element.value, element)
    element.parent = parent_element
end

_getupdatedchild!(value::Nothing, newchild::Element) = [newchild]
_getupdatedchild!(value::TextElement, newchild::Element) =
    Base.isnothing(value) ?
        newchild : error("cannot add child to text with value: $(value.input[value.value])")
_getupdatedchild!(value::Vector{Element}, newchild::Element) = begin
    push!(value, newchild)
    newchild.index = length(value)
    return value
end

_getupdatedchild!(value::Vector{Element}, newchild::TextElement) =
    error("cannot add text")

"Appends a sibling attribute to last attribute"
addattribute!(element::Element, attribute::Attribute) = begin
    if isnothing(element.attributes)
        element.attributes = Vector{Attribute{Element}}()
    end
    push!(element.attributes, attribute)
    attribute.index = length(element.attributes)
    attribute.parent = element
end

_alignattributes!(node::Nothing) = nothing
const container_for_attrs = Vector{Attribute{Element}}()
_alignattributes!(node::Element) = begin
    maxbound = -1
    len = length(node.value)
    collected_values = resize!(container_for_attrs, 0)
    if isnothing(node.value) return nothing end
    i = 1
    while i <= len
        attrs = node.value[i].attributes
        if !isnothing(attrs)
            append!(collected_values, attrs)
        end
        i += 1
    end
    cumulativeoffset = _alignattributes!(collected_values, maxbound)


    # @code_warntype _alignattributes!(collected_values, maxbound)
    cumulativeoffset == 0 && return nothing
    _shift!(node, cumulativeoffset, ChildElement)
    # @btime _shift!(node, cumulativeoffset, ChildElement)
end

#_alignattributes!(node::Document) = nothing
AttributesWithOffsets = Vector{Tuple{Attribute{Element}, Int64}}
_alignattributes!(allattrs::Vector{Attribute{Element}}, maxbound::Int64) = begin
    cumulativeoffset = 0
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

_normalizeindents(attributes_with_offsets::Vector{Tuple{Attribute{Element}, Int64}}, requiredoffset::Int64) = begin
    cumulativeoffset = 0
    shift = 0
    i = 1
    stop = length(attributes_with_offsets)
    while i<=stop
        a = @inbounds attributes_with_offsets[i]
        i+=1
        _shift!(a[1].parent, shift)

        buffer = a[1].input
        curoffset = a[2]
        shift = requiredoffset - curoffset
        shift == 0 && continue
        startposition = first(getposition(a[1]))
        shift > 0 ?
            insert!(buffer,' '^shift, startposition) :
            delete!(buffer, startposition+shift:startposition-1)
        _shift!(a[1], shift)
        _shift!(a[1].parent.value, shift)
        cumulativeoffset += shift
    end
    return cumulativeoffset
end

const container_for_sorted_attrs = Vector{Vector{Tuple{Attribute{Element}, Int64}}}()

_groupby(f, attrs::Vector{Attribute{Element}}) = begin
    sorteddtuple = resize!(container_for_sorted_attrs, 0)
    collection = _calculate_offsets(attrs)
    for attr_with_offset in collection
            found = false
            for group in sorteddtuple
                if _equals(getname(attr_with_offset[1]), getname(group[1][1]))
                    push!(group, attr_with_offset)
                    found = true
                end
            end
            if !found push!(sorteddtuple, [attr_with_offset]) end
    end
    sorteddtuple = _sortbyoffset(sorteddtuple)
    return sorteddtuple
end

_sortbyoffset(collection::Vector{Vector{Tuple{Attribute{Element}, Int64}}}) = begin
    sort!(collection, lt=_isless, alg=QuickSort)
end

const attr_with_offsets = Vector{Tuple{Attribute{Element}, Int64}}()

_calculate_offsets(attributes::Vector{Attribute{Element}}) = begin
    resize!(attr_with_offsets, length(attributes))
    map!(a -> (a, first(getposition(a)) - findprev(a.input, '\n', first(getposition(a)))), attr_with_offsets, attributes)
end
_update_offsets(attributes::Vector{Tuple{Attribute{Element}, Int64}}) = begin
    map!(a -> (a[1], first(getposition(a[1])) - findprev(a[1].input, '\n', first(getposition(a[1])))), attributes, attributes)
end
_isless(a::Vector{Tuple{Attribute{Element}, Int64}}, b::Vector{Tuple{Attribute{Element}, Int64}}) = _findmostleft(a) < _findmostleft(b)
_findmostleft(attributes_with_offsets::Vector{Tuple{Attribute{Element}, Int64}}) = minimum(a -> a[2], attributes_with_offsets)
_findmaxlength(attributes_with_offsets::Vector{Tuple{Attribute{Element}, Int64}}) = maximum(a -> length(getposition(a[1])), attributes_with_offsets)

_shift!(node::Attribute, offset::Int64) = begin
    i = node.index
    attrs = node.parent.attributes
    len = length(attrs)
    while i<=len
        node = @inbounds attrs[i]
        node.name = node.name .+ offset
        node.value = node.value .+ offset
        i+=1
    end
end

_shift!(attrs::Vector{Attribute{Element}}, offset::Int64) = begin
    foreach(a -> begin
        a.name = a.name .+ offset
        a.value = a.value .+ offset
    end, attrs)
    # i = 1
    # len = length(attrs)
    # while i <= len
    #     a = @inbounds attrs[i]
    #     a.name = a.name .+ offset
    #     a.value = a.value .+ offset
    #     i+=1
    # end
end

_shift!(node::Element, offset::Int64, whocalled::Type{ChildElement}) = begin
    next = getnext(node)
    if !isnothing(next)
        _shift!(next, offset)
    end
    _shift!(node.parent, offset, ChildElement)
end

_shift!(elements::Vector{Element}, offset::Int64) = begin
    foreach(node -> begin
        node.name = node.name .+ offset
        _shift!(node.attributes, offset)
        _shift!(node.value, offset)
    end, elements)
    # i = 1
    # len = length(elements)
    # while i <= len
    #     node = @inbounds elements[i]
    #     node.name = node.name .+ offset
    #     _shift!(node.attributes, offset)
    #     _shift!(node.value, offset)
    #     i+=1
    # end
end

_shift!(node::Element, offset::Int64) = begin
    i = node.index
    elements = node.parent.value
    len = length(elements)
    while i<=len
        node = @inbounds elements[i]
        node.name = node.name .+ offset
        _shift!(node.attributes, offset)
        _shift!(node.value, offset)
        i+=1
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
#_shift!(node::Document, offset::Int64, whocalled::Type) = nothing
_shift!(node::AbstractElement, offset::Int64, whocalled) = nothing
_shift!(node::Nothing, i::Int64, whocalled) = nothing
_shift!(node::Nothing, i::Int64) = nothing

"""
    Comparison implementation due to slow comparison of StringView with String
"""
_equals(a::StringView, b::AbstractString) = begin
    if ncodeunits(a) != ncodeunits(b) return false end
    _memcmp(pointer(b), pointer(a.data), length(a.data)) == 0
end
_memcmp(a::Ptr{UInt8}, b::Ptr{UInt8}, len::Int64) =
    ccall(:memcmp, Cint, (Ptr{UInt8}, Ptr{UInt8}, Csize_t), a, b, len % Csize_t) % Int
