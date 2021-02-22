using Test
include("../src/string_buffer.jl")

@testset "index interface test" begin
    buffer = StringBuffer("a<c")
    @test buffer[1] == 'a'
    @test buffer[2] == '<'
    @test buffer[3] == 'c'
    @test_throws BoundsError buffer[10]
    buffer[1] = 'v'
    buffer[3] = 'f'
    @test buffer[1] == 'v'
    @test buffer[3] == 'f'
    buffer[2:2] = "x"
    @test buffer[2] == 'x'
    buffer[1:3] = "xac"
    @test buffer[1:3] == "xac"

end

@testset "length/capacity test" begin
    buffer = StringBuffer("abc")
    @test length(buffer) == 3
    @test capacity(buffer) == 3
    buffer = StringBuffer(4)
    @test length(buffer) == 0
    @test capacity(buffer) == 4

end

@testset "print test" begin
    buffer = StringBuffer("abc")
    @test string(buffer) == "abc"
end

@testset "buffer editing test" begin
    buffer = StringBuffer("abc")
    push!(buffer, 'c')
    push!(buffer, 'z')
    @test buffer[4] == 'c'
    @test buffer[5] == 'z'
    append!(buffer, "xx")
    @test buffer[6:7] == "xx"
    insert!(buffer, "tt", 1)
    @test buffer[1:2] == "tt"
    insert!(buffer, "tt", 2)
    @test buffer[2:3] == "tt"
    insert!(buffer, "ll", buffer.size)
    @test buffer[buffer.size - 2:buffer.size-1] == "ll"
    buffer = StringBuffer("abc")
    replace!(buffer, "def", 1:3)
    @test buffer[1:3] == "def"
    replace!(buffer, "abc", 1:2)
    @test buffer[1:4] == "abcf"
    replace!(buffer, "j", 1:3)
    @test buffer[1:2] == "jf"
end

@testset "findprev/findnext" begin
    buffer = StringBuffer("abcde")
    @test Base.findnext(buffer, "bc", UInt32(1)) == 2
    @test Base.findnext(buffer,"vvvvvvv", UInt32(1)) == nothing
    @test Base.findprev(buffer, "bc", UInt32(5)) == 2
    @test Base.findprev(buffer, "vvvvv", UInt32(5)) == nothing
end
