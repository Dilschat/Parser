using Test
include("../src/xml_dom.jl")

@testset "TextElement get value test" begin
    buffer = StringBuffer("abcde")
    text = TextElement(buffer, 1:3)
    @test getvalue(text) == "abc"
    text = TextElement(buffer, 1:5)
    @test getvalue(text) == "abcde"
    text = TextElement(buffer, -1:5)
    @test_throws BoundsError getvalue(text)
    text = TextElement(buffer, 1:125)
    @test_throws BoundsError getvalue(text)
end

#TODO add bounds check to constructor
@testset "TextElement get position test" begin
    buffer = StringBuffer("abcde")
    text = TextElement(buffer, 1:3)
    @test getposition(text) == 1:3
end

#TODO add check on shift on not bound range
@testset "TextElement shift test" begin
    buffer = StringBuffer("abcde")
    text = TextElement(buffer, 1:3)
    @test getvalue(text) == "abc"
    shift!(text, 2)
    @test getvalue(text) == "cde"
    shift!(text, -2)
    @test getvalue(text) == "abc"
end

@testset "TextElement print test" begin
    buffer = StringBuffer("abcde")
    text = TextElement(buffer, 1:3)
    @test string(text) == "abc"
end
#TODO rewrite all xmldom on string view
@testset "Attribute get name" begin
    buffer = StringBuffer("abc=\"cde\"")
    attr = Attribute(buffer, 1:3, 6:8)
    @test getname(attr) == "abc"
end

@testset "Attribute get/set next" begin
    buffer = StringBuffer("abc=\"cde\"aaaa")
    attr = Attribute(buffer, 1:3, 6:8)
    @test getname(attr) == "abc"
    @test getnext(attr) == nothing
    attr2 = Attribute(buffer, 1:3, 6:8)
    setnext!(attr, attr2)
    @test getnext(attr) == attr2
end

@testset "Attribute get position" begin
    buffer = StringBuffer("abc=\"cde\"aaaa")
    attr = Attribute(buffer, 1:3, 6:8)
    @test getposition(attr) == 1:9
end

@testset "Attribute get value" begin
    buffer = StringBuffer("abc=\"cde\"")
    attr = Attribute(buffer, 1:3, 6:8)
    @test getvalue(attr) == "cde"
end

#TODO ращобраться с propagate bounds
#TODO добавить контракты к функциям
@testset "Attribute print" begin
    buffer = StringBuffer("abc=\"cde\"")
    attr = Attribute(buffer, 1:3, 6:8)
    @test string(attr) == "abc=\"cde\""
end

@testset "Attribute shift" begin
    buffer = StringBuffer("abc=\"cde\"aaaaa")
    attr = Attribute(buffer, 1:3, 6:8)
    @test getname(attr) == "abc"
    @test getvalue(attr) == "cde"
    shift!(attr, 2)
    @test getname(attr) == "c=\""
    @test getvalue(attr) == "e\"a"
    shift!(attr, -2)
    @test getname(attr) == "abc"
    @test getvalue(attr) == "cde"
end

@testset "Attribute setattributevalue" begin
    buffer = StringBuffer("abc=\"cde\"")
    attr = Attribute(buffer, 1:3, 6:8)
    element = Element(buffer, 2:5, attr, nothing, nothing, nothing)
    attr.parent = element
    doc = Document(buffer, element)
    element.parent = doc
    @test getvalue(attr) == "cde"
    setattributevalue!(attr, "p")
    @test getvalue(attr) == "p"
    setattributevalue!(attr, "abc")
    @test getvalue(attr) == "abc"
    @test string(attr) == "abc=\"abc\""
end

@testset "Element get next" begin
    buffer = StringBuffer("<name abc=\"cde\">value</name>")
    txt = TextElement(buffer, 22:26)
    elmnt = Element(buffer, 2:5, txt, nothing)
    elmnt2 = Element(buffer, 2:5, txt, nothing)
    setnext!(elmnt, elmnt2)
    @test getnext(elmnt) == elmnt2
end

@testset "Element get name" begin
    buffer = StringBuffer("<name abc=\"cde\">value</name>")
    txt = TextElement(buffer, 22:26)
    elmnt = Element(buffer, 2:5, txt, nothing)
    @test getname(elmnt) == "name"
end

@testset "Element get value" begin
    buffer = StringBuffer("<name abc=\"cde\">value</name>")
    txt = TextElement(buffer, 22:26)
    elmnt = Element(buffer, 2:5, txt, nothing)
    @test getvalue(elmnt) == txt
end

@testset "Element get position" begin
    buffer = StringBuffer("<name abc=\"cde\">value</name>")
    txt = TextElement(buffer, 22:26)
    elmnt = Element(buffer, 2:5, txt, nothing)
    @test getposition(elmnt) == 1:28
end

@testset "Element get attribute" begin
    buffer = StringBuffer("<name abc=\"cde\"aaaa ><name>value</name></name>")
    attr = Attribute(buffer, 7:9, 11:15)
    new_element = Element(buffer, 2:5, nothing, nothing, nothing, nothing)
    @test getattribute(new_element, "abc") == nothing
    @test getattribute(new_element, 1) == nothing
    new_element = Element(buffer, 2:5, attr, nothing, nothing, nothing)
    @test getattribute(new_element, "abc") == attr
    @test getattribute(new_element, 1) == attr
end

@testset "Element get" begin
    buffer = StringBuffer("<name><name1>value</name1></name>")
    txt = TextElement(buffer, 14:18)
    childelmnt = Element(buffer, 8:12, txt, nothing)
    new_element = Element(buffer, 2:5, nothing, childelmnt, nothing, nothing)
    setparent!(childelmnt, new_element)
    @test Base.getindex(new_element, "name1") == childelmnt
    @test Base.getindex(new_element, 1) == childelmnt
    @test Base.getindex(new_element, "name1123") == nothing
    @test Base.getindex(new_element, 10000) == nothing
end

@testset "Element print" begin
    buffer = StringBuffer("<name><name1>value</name1></name>")
    txt = TextElement(buffer, 14:18)
    childelmnt = Element(buffer, 8:12, txt, nothing)
    new_element = Element(buffer, 2:5, nothing, childelmnt, nothing, nothing)
    @test string(childelmnt) == "<name1>value</name1>"
    @test string(new_element) == "<name><name1>value</name1></name>"
end
#TODO return string instead of text element
@testset "Element shift" begin
    buffer = StringBuffer("<name abc=\"cde\"aaaa ><name>value</name></name>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    attr = Attribute(buffer, 7:9, 11:15)
    txt = TextElement(buffer, 30:34)
    next_element = Element(buffer, 2:5, nothing, nothing, nothing, nothing)
    new_element = Element(buffer, 2:5, attr, txt, nothing, next_element)
    parent_element = Element(buffer, 2:5, nothing, nothing, nothing, nothing)
    setparent!(new_element, parent_element)
    setparent!(next_element, parent_element)
    parent_next_element = Element(buffer, 2:5, nothing, nothing, nothing, nothing)
    setnext!(parent_element, parent_next_element)
    doc = Document(buffer, next_element)
    parent_element.parent = doc
    parent_next_element.parent = doc
    shift!(new_element, 1, Attribute)
    @test getposition(attr) == 7:16
    @test getposition(txt) == 31:35
    @test next_element.name == 3:6
    @test parent_next_element.name == 3:6
    shift!(new_element, -1, Attribute)
    @test getposition(attr) == 7:16
    @test getposition(txt) == 30:34
    @test next_element.name == 2:5
    @test parent_next_element.name == 2:5

    shift!(new_element, 1, Element)
    @test getposition(attr) == 8:17
    @test getposition(txt) == 31:35
    @test next_element.name == 3:6
    @test parent_next_element.name == 3:6
    shift!(new_element, -1, Element)
    @test getposition(attr) == 7:16
    @test getposition(txt) == 30:34
    @test next_element.name == 2:5
    @test parent_next_element.name == 2:5

    shift!(parent_element, 1, ChildElement)
    @test getposition(attr) == 7:16
    @test getposition(txt) == 30:34
    @test next_element.name == 2:5
    @test parent_next_element.name == 3:6
    shift!(parent_element, -1, ChildElement)
    @test getposition(attr) == 7:16
    @test getposition(txt) == 30:34
    @test next_element.name == 2:5
    @test parent_next_element.name == 2:5
end

@testset "Element append" begin
    buffer = StringBuffer("<name><name1>value</name1></name>")
    txt = TextElement(buffer, 14:18)
    childelmnt = Element(buffer, 8:12, txt, nothing)
    element = Element(buffer, 2:5, nothing, childelmnt, nothing, nothing)
    Base.append!(element, "new", "newvalue")
    @test getname(childelmnt.next) == "new"
    @test string(getvalue(childelmnt.next)) == "newvalue"
end

@testset "Document test" begin
    buffer = StringBuffer("<name><name1>value</name1></name><!--Your comment-->")
    txt = TextElement(buffer, 14:18)
    childelmnt = Element(buffer, 8:12, txt, nothing)
    element = Element(buffer, 2:5, nothing, childelmnt, nothing, nothing)
    doc = Document(buffer, element)
    element.parent = doc
    @test doc["name"] == element
    @test string(doc) == "<name><name1>value</name1></name><!--Your comment-->"
end

@testset "Alignment test" begin
    buffer = StringBuffer("abc1_cde2_qwe3")
    attr1 = Attribute(buffer, 1:3, 5:10, nothing, nothing)
    attr2 = Attribute(buffer, 6:8, 3:4, nothing, attr1)
    attr3 = Attribute(buffer, 11:13, 3:4, nothing, attr2)
    attr4 = Attribute(buffer, 1:3, 5:10, nothing, attr3)
    attrs_with_offsets = ((attr2, 2), (attr1, 1), (attr3, 3), (attr4, 4))
    @test _findmaxlength(attrs_with_offsets) == 11
    @test _findmostleft(attrs_with_offsets) == 1
    @test _isless(attrs_with_offsets, ((attr1, 2),)) == true
    @test _isless(attrs_with_offsets, ((attr1, -1),)) == false
    @test _sortbyoffset((((attr3, 3),), ((attr1, 1), (attr2, 2)), ((attr4, 4),),)) == (((attr1, 1), (attr2, 2)), ((attr3, 3),), ((attr4, 4),), )
    @test map(p -> (getname(p[1][1]), length(p)), _groupby(p -> getname(p[1]), attrs_with_offsets)) == (("abc", 2), ("cde",1), ("qwe", 1), )
end
