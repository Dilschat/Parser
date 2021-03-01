using Test
include("../src/parser.jl")

@testset "empty node test without attributes" begin
    xml = "< name />"
    element = parse_xml(xml)
    @test getname(element[1]) == "name"
end

@testset "empty node test with attributes" begin
    xml = "< name a = \"a\" b = \"b\" />"
    element = parse_xml(xml)
    @test getname(element[1]) == "name"
    @test getname(element[1].attributes[1]) == "a"
    @test getvalue(element[1].attributes[1]) == "a"
    @test getname(element[1].attributes[2]) == "b"
end

@testset "text node test without attributes" begin
    xml = "< name >    asfasfasf    </name>"
    element = parse_xml(xml)
    @test getname(element[1]) == "name"
    @test getvalue(element[1].value) == "asfasfasf"
end

@testset "child nodes test with attributes" begin
    xml = "< name B=\"A\"> <   asfasfasf   /> </name>"
    element = parse_xml(xml)
    @test getname(element[1]) == "name"
    @test getname(element[1].value[1]) == "asfasfasf"
end

@testset "error test" begin
    xml = "< name B=\"A> <   asfasfasf   /> </name>"
    @test_throws XmlException parse_xml(xml)
    xml = "< name B\"A\"> <   asfasfasf   /> </name>"
    @test_throws XmlException parse_xml(xml)
    xml = "< name B=\"A\"> <   asfasfasf   /> </na>"
    @test_throws XmlException parse_xml(xml)
end
