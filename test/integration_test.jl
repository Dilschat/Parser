using Test
using BenchmarkTools
using UnsafeArrays
include("../src/parser.jl")

@testset "empty node test without attributes" begin
    xml  = """
    <name></name>
    """
    doc = parse_xml(xml)
    @test typeof(doc["name"]) == Element
    @test getvalue(doc["name"]) == nothing
end

@testset "empty node test with attributes" begin
    xml  = """
    <name>
        <name1  />
        <name2  a="a" b    = "c"/>
        <name3  a="a" b    = "c"/>
        <name4  a="a" b    = "c"/>
    </name>
    """
    doc = parse_xml(xml)
    @test getvalue(getattribute(doc["name"]["name2"] , "a")) == "a"
    @test getvalue(getattribute(doc["name"]["name4"] , "b")) == "c"

    xml_appended  = """
    <name>
        <name1  />
        <name2  a="a" b    = "c"/>
        <name3  a="a" b    = "c"/>
        <name4  a="a" b    = "c"/>
        <new>new</new>
    </name>
    """
    Base.append!(doc["name"], "new", "new")
    println(doc)
    xml_set_attribute  = """
    <name>
        <name1  />
        <name2  a="abc"  b    = "c"/>
        <name3  a="ad"   b    = "c"/>
        <name4  a="abcd" b    = "new"/>
        <new>new</new>
    </name>
    """

    setvalue!(getattribute(doc["name"]["name4"] , "b"), "new")

    println(doc)
    setvalue!(getattribute(doc["name"]["name2"] , "a"), "abc")
    println(doc)
    setvalue!(getattribute(doc["name"]["name4"] , "a"), "abcd")
    println(doc)
    setvalue!(getattribute(doc["name"]["name3"] , "a"), "ad")
    println(doc)
    @test string(doc) == xml_set_attribute
end


@testset "example test" begin
    example = """
<cfg>

  <C A="G" />

  <S AlwaysOn="true">
    <xE M="03:00:00"                   T="S" />
    <xE M="04:00:00" Date="2019:12:09" T="S" />
  </S>

  <AutoStart>false</AutoStart> <!-- DO NOT DELETE ME -->

  <E>
    <S1>s1</S1>
    <S2>s2</S2>
    <S3>s3</S3>
  </E>

  <AAA>
    <xB S="A"  B="C" D="E" F="22222.0" E="false" />
    <xB S="A"  B="C" D="E" F="22222"   E="false" />
  </AAA>

<!-- settings -->
  <Url u="url" Origin="url" />

  <P C="100" D="30" />

  <L A="true" O="0" />

  <MDDelayAlarm Threshold="3000" Duration="5000" MinReconnectInterval="15000"/>

  <!-- par par -->
  <PPP>0.001,  1,      0.0001,
                    1,      10,     0.001,
                    10,     100,    0.01,
                    100,    1000,   0.1,
                    1000,   5000,   1,
                    5000,   10000,  5,
                    10000,  50000,  10,
                    50000,  100000, 50,
                    100000, 500000, 100,
                    500000, 1000000, 500,
                    1000000, 10000000, 1000</PPP>

</cfg>
    """

    doc = parse_xml(example)
    @test string(doc) == example

    expected = """
<cfg>

  <C A="G" />

  <S AlwaysOn="true">
    <xE M="123"               T="S" />
    <xE M="04:00:00" Date="0" T="S" />
    <new>new</new>
  </S>

  <AutoStart>false</AutoStart> <!-- DO NOT DELETE ME -->

  <E>
    <S1>s1</S1>
    <S2>s2</S2>
    <S3>s3</S3>
  </E>

  <AAA>
    <xB S="A"  B="C" D="E" F="22222.0"   E="false" />
    <xB S="A"  B="C" D="E" F="222220000" E="false" />
    <new>new</new>
  </AAA>

<!-- settings -->
  <Url u="url" Origin="url" />

  <P C="100" D="30" />

  <L A="true" O="0" />

  <MDDelayAlarm Threshold="3000" Duration="5000" MinReconnectInterval="15000"/>

  <!-- par par -->
  <PPP>0.001,  1,      0.0001,
                    1,      10,     0.001,
                    10,     100,    0.01,
                    100,    1000,   0.1,
                    1000,   5000,   1,
                    5000,   10000,  5,
                    10000,  50000,  10,
                    50000,  100000, 50,
                    100000, 500000, 100,
                    500000, 1000000, 500,
                    1000000, 10000000, 1000</PPP>

</cfg>
    """
    @test string(getvalue(doc["cfg"]["E"]["S1"])) == "s1"
    @test getvalue(getattribute(doc["cfg"]["P"] , "C")) == "100"
    @test getvalue(getattribute(doc["cfg"]["Url"] , "u")) == "url"
    @test getvalue(getattribute(doc["cfg"]["L"] , "A")) == "true"
    Base.append!(doc["cfg"]["AAA"], "new", "new")
    setvalue!(getattribute(doc["cfg"]["AAA"][2] , "F"), "222220000")
    setvalue!(getattribute(doc["cfg"]["S"][2] , "Date"), "0")
    setvalue!(getattribute(doc["cfg"]["S"][1] , "M"), "123")
    @test getvalue(getattribute(doc["cfg"]["S"][1] , "M")) == "123"
    @test getvalue(getattribute(doc["cfg"]["AAA"][2] , "F")) == "222220000"
    @test getvalue(getattribute(doc["cfg"]["Url"] , "u")) == "url"
    Base.append!(doc["cfg"]["S"], "new", "new")
    @test string(getvalue(doc["cfg"]["E"]["S1"])) == "s1"
    @test getvalue(getattribute(doc["cfg"]["L"] , "A")) == "true"

    @test getvalue(getattribute(doc["cfg"]["P"] , "C")) == "100"
    @test string(doc) == expected
end

@testset "benchmark" begin
    example = """
    <cfg>

    <C A="G" />

    <S AlwaysOn="true">
    <xE M="03:00:00"                   T="S" />
    <xE M="04:00:00" Date="2019:12:09" T="S" />
    </S>

    <AutoStart>false</AutoStart> <!-- DO NOT DELETE ME -->

    <E>
    <S1>s1</S1>
    <S2>s2</S2>
    <S3>s3</S3>
    </E>

    <AAA>
    <xB S="A"  B="C" D="E" F="22222.0" E="false" />
    <xB S="A"  B="C" D="E" F="22222"   E="false" />
    </AAA>

    <!-- settings -->
    <Url u="url" Origin="url" />

    <P C="100" D="30" />

    <L A="true" O="0" />

    <MDDelayAlarm Threshold="3000" Duration="5000" MinReconnectInterval="15000"/>

    <!-- par par -->
    <PPP>0.001,  1,      0.0001,
                    1,      10,     0.001,
                    10,     100,    0.01,
                    100,    1000,   0.1,
                    1000,   5000,   1,
                    5000,   10000,  5,
                    10000,  50000,  10,
                    50000,  100000, 50,
                    100000, 500000, 100,
                    500000, 1000000, 500,
                    1000000, 10000000, 1000</PPP>

    </cfg>
    """

    doc = parse_xml(example)
    println("set attribute time1:")
    attr = getattribute(doc["cfg"]["S"][1] , "M")
    @btime setvalue!($attr, "123")
    println("set attribute time2:")
    attr = getattribute(doc["cfg"]["S"][1] , "M")
    @btime setvalue!($attr, "123")
    println("Parse time:")
    @btime parse_xml($example)
    println("Access element time:")
    @btime $doc["cfg"]["P"]
    println("Access element by idx:")
    @btime $doc[1][4]
    println("Access attribute time:")
    @btime getattribute($doc["cfg"]["S"][1] , "M")
    @btime $doc.input[$doc.name]
    next::Union{Element, Nothing} = doc
    @btime $next.name
end


# abstract type AbstractElement end
#
# mutable struct Text <: AbstractElement a::Int end
# mutable struct Element1<: AbstractElement
#     input::String
#     name::UnitRange{Int64}
#     attributes::Union{Nothing, Int}
#     value::Union{Vector{Element1}, Text, Nothing}
#     parent::Union{Element1, Nothing}
#     position::Int
# end
#
# getnext(e::Element1) = begin
#     if length(e.parent.value) == e.position return nothing end
#     e.parent.value[e.position+1]
# end
# example(node::Element1) = begin
#     while !isnothing(node)
#         if node.name == 1:1 return node end
#         node = getnext(node)
#     end
#     return error("error")
# end
#
#
# f = Element1("", 2:2, nothing, Vector{Element1}(), nothing, 1)
# second = Element1("", 1:1, nothing, Vector{Element1}(), f, 1)
# push!(f.value, second)
# third = Element1("", 1:1, nothing, Text(3), f, 2)
# push!(f.value, third)
# @btime getnext($second)
# @code_warntype getnext(second)
