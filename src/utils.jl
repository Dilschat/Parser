_memcmp(a::Ptr{UInt8}, b::Ptr{UInt8}, len::Int64) =
    ccall(
        :memcmp,
        Cint,
        (Ptr{UInt8}, Ptr{UInt8}, Csize_t),
        a,
        b,
        len % Csize_t,
    ) % Int
