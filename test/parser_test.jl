using Test
include("../src/parser.jl")

@testset "empty node test without attributes" begin
    xml = "< name />"
    element = parse_xml(xml)
    @test getname(element.root) == "name"
end

@testset "empty node test with attributes" begin
    xml = "< name a = \"a\" b = \"b\" />"
    element = parse_xml(xml)
    @test getname(element.root) == "name"
    @test getname(element.root.attributes) == "a"
    @test getvalue(element.root.attributes) == "a"
    @test getname(element.root.attributes.next) == "b"
end

@testset "text node test without attributes" begin
    xml = "< name >    asfasfasf    </name>"
    element = parse_xml(xml)
    @test getname(element.root) == "name"
    @test getvalue(element.root.value) == "asfasfasf"
end

@testset "child nodes test with attributes" begin
    xml = "< name B=\"A\"> <   asfasfasf   /> </name>"
    element = parse_xml(xml)
    @test getname(element.root) == "name"
    @test getname(element.root.value) == "asfasfasf"
end

@testset "error test" begin
    xml = "< name B=\"A> <   asfasfasf   /> </name>"
    @test_throws XmlException parse_xml(xml)
    xml = "< name B\"A\"> <   asfasfasf   /> </name>"
    @test_throws XmlException parse_xml(xml)
    xml = "< name =\"A\"> <   asfasfasf   /> </name>"
    @test_throws XmlException parse_xml(xml)
    # xml = "< name B=\"A\" <   asfasfasf   /> </name>"
    # @test_throws XmlException parse_xml(xml)
    xml = "< name B=\"A\"> <   asfasfasf   /> </na>"
    @test_throws XmlException parse_xml(xml)
end
