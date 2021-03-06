import Base: getindex, setindex!, findprev, findnext, length, print, append!,
    insert!, push!, delete!, replace!, checkbounds

using DataStructures
using StringViews
using UnsafeArrays
include("utils.jl")


const RESIZE_COEF = 1.5
"""
    Simple string buffer, that supports only 1byte chars of UTF8
"""
mutable struct StringBuffer
    value::Vector{UInt8}
    size::UInt32
end

StringBuffer(size::Int) = StringBuffer(Vector{UInt8}(undef, size), 0)

function StringBuffer(input::String)
    size = ncodeunits(input)
    container = unsafe_wrap(Vector{UInt8}, input)
    StringBuffer(container, size)
end

function getindex(buffer::StringBuffer, i::Integer)
    @boundscheck checkbounds(buffer, i)
    Char(@inbounds buffer.value[i])
end

function getindex(buffer::StringBuffer, range::UnitRange{Int64})
    @boundscheck checkbounds(buffer, range)
    StringView(@inbounds uview(buffer.value, range))
end

function setindex!(buffer::StringBuffer, char::Char, i::Integer)
    @boundscheck checkbounds(buffer, i)
    buffer.value[i] = char
end

function setindex!(
    buffer::StringBuffer,
    str::String,
    range::UnitRange{Int64},
)
    @boundscheck checkbounds(buffer, range)
    ncodeunits(str) != length(range) &&
        throw(BoundsError("Incompatable sizes str: $str range: $range"))
    unsafe_copyto!(
        buffer.value,
        first(range),
        unsafe_wrap(Vector{UInt8}, str),
        1,
        length(range),
    )
end

findprev(buffer::StringBuffer, val::String, startidx::Int64) = begin
    valuelength = ncodeunits(val)
    endidx = valuelength + startidx - 1
    if endidx > length(buffer.value)
        offset = endidx - length(buffer.value)
        startidx = startidx - offset
        endidx = endidx - offset
    end
    while startidx > 0
        if _equals(val, view(buffer.value, startidx:endidx))
            return startidx
        end
        startidx = startidx - 1
        endidx = valuelength + startidx - 1
    end
    return nothing
end

findprev(buffer::StringBuffer, val::Char, startidx::Int64) = begin
    ptr = pointer(buffer.value)
    while startidx > 0
        if UInt8(val) == unsafe_load(ptr, startidx)
            return startidx
        end
        startidx = startidx - 1
    end
    return nothing
end

findnext(buffer::StringBuffer, val::String, startidx::Int64) = begin
    length = ncodeunits(val)
    endidx = length + startidx - 1
    while endidx <= buffer.size
        if _equals(val, view(buffer.value, startidx:endidx))
            return startidx
        end
        startidx = startidx + 1
        endidx = length + startidx - 1
    end
    return nothing
end

length(buffer::StringBuffer) = buffer.size
capacity(buffer::StringBuffer) = length(buffer.value)

#reinterpret?
print(io::IO, buffer::StringBuffer) =
    unsafe_write(io, pointer(buffer.value), buffer.size)
print(io::IO, buffer::StringBuffer, range::UnitRange) =
    unsafe_write(io, pointer(buffer.value) + first(range) - 1, length(range))

function push!(buffer::StringBuffer, char::Char)
    required_size = buffer.size + UInt32(1)
    capacity(buffer) < required_size && _resize!(buffer, required_size)
    buffer.value[required_size] = char
    buffer.size = required_size
end

function append!(buffer::StringBuffer, str::String)
    required_size = buffer.size + UInt32(ncodeunits(str))
    required_size > capacity(buffer) && _resize!(buffer, required_size)
    unsafe_copyto!(
        pointer(buffer.value, buffer.size + 1),
        pointer(str),
        ncodeunits(str),
    )
    buffer.size = required_size
end

function insert!(buffer::StringBuffer, str::String, i::Integer)
    @boundscheck checkbounds(buffer, i)
    required_capacity = buffer.size + ncodeunits(str)
    required_capacity > capacity(buffer) && _resize!(buffer, required_capacity)
    #shift
    unsafe_copyto!(
        buffer.value,
        i + ncodeunits(str),
        buffer.value,
        i,
        buffer.size - i + 1,
    )
    #insert
    unsafe_copyto!(
        buffer.value,
        i,
        unsafe_wrap(Vector{UInt8}, str),
        1,
        ncodeunits(str),
    )
    buffer.size = required_capacity
end

function delete!(buffer::StringBuffer, range::UnitRange)
    @boundscheck checkbounds(buffer, range)
    unsafe_copyto!(
        buffer.value,
        first(range),
        buffer.value,
        last(range) + 1,
        buffer.size - last(range),
    )
    buffer.size = buffer.size - length(range)
end

function replace!(buffer::StringBuffer, new_val::String, range::UnitRange)
    old_length = length(range)
    new_length = ncodeunits(new_val)
    offset = old_length - new_length
    if offset == 0
        buffer[range] = new_val
    elseif offset < 0
        buffer[range] = new_val[1:old_length]
        insert!(buffer, new_val[old_length+1:new_length], last(range) + 1)
    elseif offset > 0
        buffer[first(range):first(range)+new_length-1] = new_val
        delete!(buffer, first(range)+new_length:last(range))
    end
end

function _resize!(buffer::StringBuffer, required_size::Integer)
    calculated_size = Int(floor(buffer.size * RESIZE_COEF))
    newsize = calculated_size > required_size ? calculated_size : required_size
    resize!(buffer.value, newsize)
end

checkbounds(buffer::StringBuffer, i::Integer) =
    (i >= 1 && i <= buffer.size) ? true :
    throw(BoundsError("Bound error size: $size index: $i"))

checkbounds(buffer::StringBuffer, i::UnitRange{Int64}) =
    (first(i) >= 1 && last(i) <= buffer.size) ? true :
    throw(BoundsError("Bound error size: $size range: $i"))

_equals(a::AbstractString, b::AbstractVector{UInt8}) = begin
    if sizeof(a) != length(b)
        return false
    end
    _memcmp(pointer(b), pointer(a), length(b)) == 0
end
