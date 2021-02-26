#module Parser
using DataStructures
export parse_xml
include("lexer.jl")
include("xml_dom.jl")

struct XmlException <: Exception
    var::String
end

Base.showerror(io::IO, e::XmlException) = print(io, "Invalid xml ", e.var, "!")

function parse_xml(input::String)::Document
    lexer = Lexer(input)
    return parse_xml(lexer)
end

function parse_xml(lexer::Lexer)::Document
    buffer = StringBuffer(lexer.input)
    element = _parse_element(lexer, buffer, 1)
    document = Document(buffer, element)
    return document
end

"""
    Parses all elements, returns root element
"""
function _parse_element(lexer::Lexer, buffer::StringBuffer, state::Int)
    stack = Stack{Element}()
    while (next = iterate(lexer, state)) != nothing
        (lexeme, nextstate) = next
        if getlexemetype(lexeme) == START_TAG
            state = _parsestartelement(lexer, buffer, lexeme, nextstate, stack)
        elseif getlexemetype(lexeme) == START_CLOSE_TAG ||
               getlexemetype(lexeme) == CLOSE_START_TAG
            (element, state) =
                _parsecloseelement(lexer, buffer, lexeme, nextstate, stack)
            if !isnothing(element)
                next = iterate(lexer, state)
                if !isnothing(next)
                    throw(
                        XmlException("can't parse element at position $state"),
                    )
                end
                return element
            end
        elseif getlexemetype(lexeme) == IDENTIFIER
            state = _parseattributes(lexer, buffer, lexeme, nextstate, stack)
        elseif getlexemetype(lexeme) == TEXT
            state = _parsetext(lexer, buffer, lexeme, nextstate, stack)
        elseif getlexemetype(lexeme) == ERROR
            throw(XmlException("can't parse xml at position $state"))
        elseif getlexemetype(lexeme) == CLOSE_TAG
            state = nextstate
        end
    end
    if !isempty(stack)
        throw(XmlException("can't parse xml at position $state"))
    end
end

_parsestartelement(
    lexer::Lexer,
    buffer::StringBuffer,
    Lexeme::Lexeme,
    nextstate::Int64,
    stack::Stack,
) = begin
    (lexeme, nextstate) = _getnext(lexer, nextstate)
    if getlexemetype(lexeme) == IDENTIFIER
        element = Element(buffer, getposition(lexeme))
        push!(stack, element)
    else
        throw(XmlException("can't parse xml at position $nextstate"))
    end
    try
        return _skipcloselexeme(lexer, nextstate)
    catch e
        return nextstate
    end
end

_parsecloseelement(
    lexer::Lexer,
    buffer::StringBuffer,
    lexeme::Lexeme,
    nextstate::Int64,
    stack::Stack,
) = begin
    element = pop!(stack)
    if getlexemetype(lexeme) == CLOSE_START_TAG
    elseif getlexemetype(lexeme) == START_CLOSE_TAG
        (lexeme, nextstate) = _getnext(lexer, nextstate)
        if getlexemetype(lexeme) != IDENTIFIER ||
           getname(element) != buffer[getposition(lexeme)]
            throw(XmlException("can't parse xml at position $nextstate"))
        end
    end

    if !isempty(stack)
        parent_element = first(stack)
        try
            addchild!(parent_element, element)
        catch e
            throw(XmlException("can't parse xml at position $nextstate"))
        end
        if getlexemetype(lexeme) == CLOSE_START_TAG
            return (nothing, nextstate)
        end
        return (nothing, _skipcloselexeme(lexer, nextstate))
    else
        if getlexemetype(lexeme) == CLOSE_START_TAG
            return (element, nextstate)
        end
        return (element, _skipcloselexeme(lexer, nextstate))
    end
end

_parseattributes(
    lexer::Lexer,
    buffer::StringBuffer,
    lexeme::Lexeme,
    nextstate::Int64,
    stack::Stack,
) = begin
    next = (lexeme, nextstate)
    while next != nothing
        (lexeme, nextstate) = next
        if getlexemetype(lexeme) == CLOSE_TAG ||
           getlexemetype(lexeme) == CLOSE_START_TAG
            return first(getposition(lexeme))
        end
        (attribute, nextstate) =
            _parseattribute(lexer, buffer, lexeme, nextstate)
        element = first(stack)
        addattribute!(element, attribute)
        next = _getnext(lexer, nextstate)
    end
end

_parseattribute(lexer, buffer, lexeme, nextstate) = begin
    name = lexeme
    (lexeme, nextstate) = _getnext(lexer, nextstate)
    if getlexemetype(lexeme) != OPERATOR
        throw(XmlException("can't parse xml at position $nextstate"))
    end
    (attrval, nextstate) = _getnext(lexer, nextstate)
    if getlexemetype(attrval) != ATTRIBUTEVALUE
        throw(XmlException("can't parse xml at position $nextstate"))
    end
    return (
        Attribute(
            buffer,
            getposition(name),
            first(getposition(attrval))+1:last(getposition(attrval))-1,
        ),
        nextstate,
    )
end

_parsetext(
    lexer::Lexer,
    buffer::StringBuffer,
    lexeme::Lexeme,
    nextstate::Int64,
    stack::Stack,
) = begin
    text = TextElement(buffer, getposition(lexeme))
    element = first(stack)
    if isnothing(element)
        throw(XmlException("can't parse xml at position $nextstate"))
    end
    value = getvalue(element)
    if isnothing(value)
        setvalue!(element, text)
    else
        throw(XmlException("can't parse xml at position $nextstate"))
    end
    return nextstate
end

_skipcloselexeme(lexer, state) = begin
    (lexeme, nextstate) = _getnext(lexer, state)
    if getlexemetype(lexeme) != CLOSE_TAG
        throw(XmlException("can't parse xml at position $state"))
    end
    return nextstate
end

_getnext(lexer, nextstate) = begin
    next = iterate(lexer, nextstate)
    if isnothing(next)
        throw(XmlException("can't parse xml at position $nextstate"))
    end
    return next
end
#end # module
