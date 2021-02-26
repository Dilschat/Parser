using Test
include("../src/parser.jl")

# @testset "empty node test without attributes" begin
#     xml  = """
#     <name></name>
#     """
#     doc = parse_xml(xml)
#     @test typeof(doc["name"]) == Element
#     @test getvalue(doc["name"]) == nothing
# end

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
println(doc.input)
    Base.append!(doc["name"], "new", "new")
println(doc.input)
    xml_set_attribute  = """
    <name>
        <name1  />
        <name2  a="abc"  b    = "c"/>
        <name3  a="ad"   b    = "c"/>
        <name4  a="abcd" b    = "new"/>
        <new>new</new>
    </name>
    """

    setattributevalue!(getattribute(doc["name"]["name4"] , "b"), "new")
    setattributevalue!(getattribute(doc["name"]["name2"] , "a"), "abc")
    setattributevalue!(getattribute(doc["name"]["name4"] , "a"), "abcd")
    setattributevalue!(getattribute(doc["name"]["name3"] , "a"), "ad")
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
    Base.append!(doc["cfg"]["AAA"], "new", "new")
    setattributevalue!(getattribute(doc["cfg"]["AAA"][2] , "F"), "222220000")
    println(doc)
    @test string(doc) == expected

end
