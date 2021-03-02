using Test
include("../src/xml_dom.jl")

@testset "TextElement get value test" begin
    buffer = StringBuffer("abcde")
    text = TextElement{Element}(buffer, 1:3)
    @test getvalue(text) == "abc"
    text = TextElement{Element}(buffer, 1:5)
    @test getvalue(text) == "abcde"
    text = TextElement{Element}(buffer, -1:5)
    @test_throws BoundsError getvalue(text)
    text = TextElement{Element}(buffer, 1:125)
    @test_throws BoundsError getvalue(text)
end

#TODO add bounds check to constructor
@testset "TextElement get position test" begin
    buffer = StringBuffer("abcde")
    text = TextElement{Element}(buffer, 1:3)
    @test getposition(text) == 1:3
end

#TODO add check on shift on not bound range
@testset "TextElement shift test" begin
    buffer = StringBuffer("abcde")
    text = TextElement{Element}(buffer, 1:3)
    @test getvalue(text) == "abc"
    _shift!(text, 2)
    @test getvalue(text) == "cde"
    _shift!(text, -2)
    @test getvalue(text) == "abc"
end

@testset "TextElement print test" begin
    buffer = StringBuffer("abcde")
    text = TextElement{Element}(buffer, 1:3)
    @test string(text) == "abc"
end
#TODO rewrite all xmldom on string view
@testset "Attribute get name" begin
    buffer = StringBuffer("abc=\"cde\"")
    attr = Attribute{Element}(buffer, 1:3, 6:8)
    @test getname(attr) == "abc"
end

@testset "Attribute get next" begin
    buffer = StringBuffer("abc=\"cde\"aaaa")
    attr1 = Attribute{Element}(buffer, 1:3, 6:8)
    @test getname(attr1) == "abc"
    attr2 = Attribute{Element}(buffer, 1:3, 6:8)
    element = Element(buffer, 1:1, [attr1, attr2], nothing, nothing, 1)
    attr1.parent = element
    attr1.index = 1
    attr2.parent = element
    attr2.index = 2
    getnext(attr1) == attr2
    @test getnext(attr1) == attr2
    @test getnext(attr2) == nothing
end

@testset "Attribute get position" begin
    buffer = StringBuffer("abc=\"cde\"aaaa")
    attr = Attribute{Element}(buffer, 1:3, 6:8)
    @test getposition(attr) == 1:9
end

@testset "Attribute get value" begin
    buffer = StringBuffer("abc=\"cde\"")
    attr = Attribute{Element}(buffer, 1:3, 6:8)
    @test getvalue(attr) == "cde"
end

#TODO ращобраться с propagate bounds
#TODO добавить контракты к функциям
@testset "Attribute print" begin
    buffer = StringBuffer("abc=\"cde\"")
    attr = Attribute{Element}(buffer, 1:3, 6:8)
    @test string(attr) == "abc=\"cde\""
end

@testset "Attribute shift" begin
    buffer = StringBuffer("abc=\"cde\"aaaaa")
    attr = Attribute{Element}(buffer, 1:3, 6:8)
    element = Element(buffer, 1:1)
    element.attributes = [attr]
    attr.parent = element
    @test getname(attr) == "abc"
    @test getvalue(attr) == "cde"
    _shift!(attr, 2)
    @test getname(attr) == "c=\""
    @test getvalue(attr) == "e\"a"
    _shift!(attr, -2)
    @test getname(attr) == "abc"
    @test getvalue(attr) == "cde"
end

@testset "Attribute setattributevalue" begin
    buffer = StringBuffer("abc=\"cde\"")
    attr = Attribute{Element}(buffer, 1:3, 6:8)
    element = Element(buffer, 2:5, [attr], nothing, nothing, 1)
    attr.parent = element
    attr.index = 1
    @test getvalue(attr) == "cde"
    setvalue!(attr, "p")
    @test getvalue(attr) == "p"
    setvalue!(attr, "abc")
    @test getvalue(attr) == "abc"
    @test string(attr) == "abc=\"abc\""
end

@testset "Element get next" begin
    buffer = StringBuffer("<name abc=\"cde\">value</name>")
    elmnt1 = Element(buffer, 2:5)
    elmnt2 = Element(buffer, 2:5)
    parent_element = Element(buffer, 2:5)
    append!(parent_element, elmnt1)
    append!(parent_element, elmnt2)
    @test getnext(elmnt1) == elmnt2
end

@testset "Element get name" begin
    buffer = StringBuffer("<name abc=\"cde\">value</name>")
    txt = TextElement{Element}(buffer, 22:26)
    elmnt = Element(buffer, 2:5, txt, nothing)
    @test getname(elmnt) == "name"
end

@testset "Element get value" begin
    buffer = StringBuffer("<name abc=\"cde\">value</name>")
    txt = TextElement{Element}(buffer, 22:26)
    elmnt = Element(buffer, 2:5, txt, nothing)
    @test getvalue(elmnt) == txt
end

@testset "Element get position" begin
    buffer = StringBuffer("<name abc=\"cde\">value</name>")
    txt = TextElement{Element}(buffer, 22:26)
    elmnt = Element(buffer, 2:5, txt, nothing)
    @test getposition(elmnt) == 1:28
end

@testset "Element get" begin
    buffer = StringBuffer("<name><name1>value</name1></name>")
    txt = TextElement{Element}(buffer, 14:18)
    childelmnt = Element(buffer, 8:12, txt, nothing)
    new_element = Element(buffer, 2:5, nothing, [childelmnt], nothing, 1)
    setparent!(childelmnt, new_element)
    @test Base.getindex(new_element, "name1") == childelmnt
    @test Base.getindex(new_element, 1) == childelmnt
    @test_throws Exception Base.getindex(new_element, "name1123")
    @test_throws Exception Base.getindex(new_element, 10000)
end

@testset "Element print" begin
    buffer = StringBuffer("<name><name1>value</name1></name>")
    txt = TextElement{Element}(buffer, 14:18)
    childelmnt = Element(buffer, 8:12, txt, nothing)
    new_element = Element(buffer, 2:5, nothing, [childelmnt], nothing, 1)
    childelmnt.parent = new_element
    @test string(childelmnt) == "<name1>value</name1>"
    @test string(new_element) == "<name><name1>value</name1></name>"
end

@testset "Element shift" begin
    buffer = StringBuffer(
        "<name abc=\"cde\"aaaa ><name>value</name></name>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    )
    attr = Attribute{Element}(buffer, 7:9, 11:15)
    txt = TextElement{Element}(buffer, 30:34)
    next_element = Element(buffer, 2:5, nothing, nothing, nothing, 2)
    new_element = Element(buffer, 2:5, [attr], txt, nothing, 1)
    parent_element =
        Element(buffer, 2:5, nothing, [new_element, next_element], nothing, 1)
    setparent!(new_element, parent_element)
    setparent!(next_element, parent_element)
    parent_next_element = Element(buffer, 2:5, nothing, nothing, nothing, 2)
    doc = Element(
        buffer,
        1:0,
        nothing,
        [parent_element, parent_next_element],
        nothing,
        1,
    )
    parent_element.parent = doc
    parent_next_element.parent = doc
    _shift!(new_element, 1, Attribute)
    @test getposition(attr) == 7:16
    @test getposition(txt) == 31:35
    @test next_element.name == 3:6
    @test parent_next_element.name == 3:6
    _shift!(new_element, -1, Attribute)
    @test getposition(attr) == 7:16
    @test getposition(txt) == 30:34
    @test next_element.name == 2:5
    @test parent_next_element.name == 2:5

    _shift!(new_element, 1, Element)
    @test getposition(attr) == 8:17
    @test getposition(txt) == 31:35
    @test next_element.name == 3:6
    @test parent_next_element.name == 3:6
    _shift!(new_element, -1, Element)
    @test getposition(attr) == 7:16
    @test getposition(txt) == 30:34
    @test next_element.name == 2:5
    @test parent_next_element.name == 2:5

    _shift!(parent_element, 1, ChildElement)
    @test getposition(attr) == 7:16
    @test getposition(txt) == 30:34
    @test next_element.name == 2:5
    @test parent_next_element.name == 3:6
    _shift!(parent_element, -1, ChildElement)
    @test getposition(attr) == 7:16
    @test getposition(txt) == 30:34
    @test next_element.name == 2:5
    @test parent_next_element.name == 2:5
end

@testset "Element append" begin
    buffer = StringBuffer("<name><name1>value</name1></name>")
    txt = TextElement{Element}(buffer, 14:18)
    childelmnt = Element(buffer, 8:12, txt, nothing)
    element = Element(buffer, 2:5, nothing, [childelmnt], nothing, 1)
    childelmnt.parent = element
    Base.append!(element, "new", "newvalue")
    @test getname(getnext(childelmnt)) == "new"
    @test string(getvalue(getnext(childelmnt))) == "newvalue"
end
#
# @testset "Document test" begin
#     buffer = StringBuffer("<name><name1>value</name1></name><!--Your comment-->")
#     txt = TextElement{Element}(buffer, 14:18)
#     childelmnt = Element(buffer, 8:12, txt, nothing)
#     element = Element(buffer, 2:5, nothing, childelmnt, nothing, nothing)
#     doc = Document{Element}(buffer, element)
#     element.parent = doc
#     @test doc["name"] == element
#     @test string(doc) == "<name><name1>value</name1></name><!--Your comment-->"
# end
#

@testset "add attribute test" begin
    buffer = StringBuffer("<name><name1>value</name1></name>")
    txt = TextElement{Element}(buffer, 14:18)
    childelmnt = Element(buffer, 8:12, txt, nothing)
    element = Element(buffer, 2:5, nothing, [childelmnt], nothing, 1)
    attr1 = Attribute{Element}(buffer, 1:2, 3:4)
    attr2 = Attribute{Element}(buffer, 1:2, 3:4)
    addattribute!(element, attr1)
    @test element.attributes == [attr1]
    addattribute!(element, attr2)
    @test element.attributes == [attr1, attr2]
end

@testset "add child test" begin
    buffer = StringBuffer("<name><name1>value</name1></name>")
    txt = TextElement{Element}(buffer, 14:18)
    element = Element(buffer, 2:5, nothing, nothing, nothing, 1)
    childelmnt1 = Element(buffer, 8:12, txt, nothing)
    childelmnt2 = Element(buffer, 8:12, txt, nothing)
    Base.append!(element, childelmnt1)
    @test element.value == [childelmnt1]
    Base.append!(element, childelmnt2)
    @test element.value == [childelmnt1, childelmnt2]
end
