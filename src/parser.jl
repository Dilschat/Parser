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
    lexer = PreprocessLexer(input)
    return parse_xml(lexer)
end

function parse_xml(lexer::PreprocessLexer)::Document
    buffer = StringBuffer(lexer.input)
    element = _parse_element(lexer, buffer, 1)
    document = Document(buffer, element)
    return document
end

function _parse_element(lexer::PreprocessLexer, buffer::StringBuffer,  state::Int)
    stack = Stack{Element}()
    while (next = iterate(lexer, state)) != nothing
        (lexeme, next_state) = next
        if gettokentype(lexeme) == START_TAG
            state = _parsestartelement(lexer, buffer, lexeme, next_state, stack)
        elseif gettokentype(lexeme) == START_CLOSE_TAG ||
                gettokentype(lexeme) == CLOSE_START_TAG
            (element, state) = _parsecloseelement(lexer,buffer, lexeme, next_state, stack)
            if !isnothing(element)
                next = iterate(lexer, state)
                if !isnothing(next)
                    throw(XmlException("can't parse element at position $state"))
                end
                return element
            end
        elseif gettokentype(lexeme) == IDENTIFIER
            state = _parseattributes(lexer, buffer, lexeme, next_state, stack)
        elseif gettokentype(lexeme) == TEXT
            state = _parsetext(lexer, buffer, lexeme, next_state, stack)
        elseif gettokentype(lexeme) == ERROR
            throw(XmlException("can't parse xml at position $state"))
        elseif gettokentype(lexeme) == CLOSE_TAG
            state = next_state
        end
    end
    if !isempty(stack) throw(XmlException("can't parse xml at position $state")) end
end

_parsestartelement(lexer::PreprocessLexer, buffer::StringBuffer, Lexeme::Lexeme, next_state::Int64, stack::Stack) = begin
    (lexeme, next_state) = _getnext(lexer, next_state)
    if gettokentype(lexeme) == IDENTIFIER
        element = Element(buffer, getposition(lexeme))
        push!(stack, element)
    else
        throw(XmlException("can't parse xml at position $next_state"))
    end
    try
        return _skipcloselexeme(lexer, next_state)
    catch e
        return next_state
    end
end

_parsecloseelement(lexer::PreprocessLexer, buffer::StringBuffer, lexeme::Lexeme, next_state::Int64, stack::Stack) = begin
    element = pop!(stack)
    if gettokentype(lexeme) == CLOSE_START_TAG
    elseif gettokentype(lexeme) == START_CLOSE_TAG
        (lexeme, next_state) = _getnext(lexer, next_state)
        if gettokentype(lexeme) != IDENTIFIER || getname(element) != buffer[getposition(lexeme)]
            throw(XmlException("can't parse xml at position $next_state"))
        end
    end

    if !isempty(stack)
        parent_element = first(stack)
        try
            addchild!(parent_element, element)
        catch e
            throw(XmlException("can't parse xml at position $next_state"))
        end
        if gettokentype(lexeme) == CLOSE_START_TAG
            return (nothing, next_state)
        end
        return (nothing, _skipcloselexeme(lexer, next_state))
    else
        if gettokentype(lexeme) == CLOSE_START_TAG
            return (element, next_state)
        end
        return (element, _skipcloselexeme(lexer, next_state))
    end
end

_parseattributes(lexer::PreprocessLexer, buffer::StringBuffer, lexeme::Lexeme, next_state::Int64, stack::Stack) = begin
    next = (lexeme, next_state)
    while next != nothing
        (lexeme, next_state) = next
        if gettokentype(lexeme) == CLOSE_TAG || gettokentype(lexeme) == CLOSE_START_TAG
            return first(getposition(lexeme))
        end
        (attribute, next_state) = _parseattribute(lexer, buffer, lexeme, next_state)
        element = first(stack)
        addattribute!(element, attribute)
        next = _getnext(lexer, next_state)
    end
end

_parseattribute(lexer, buffer, lexeme, next_state) = begin
    name = lexeme
    (lexeme, next_state) = _getnext(lexer, next_state)
    if gettokentype(lexeme) != OPERATOR
        throw(XmlException("can't parse xml at position $next_state"))
    end
    (attrval, next_state) = _getnext(lexer, next_state)
    if gettokentype(attrval) != ATTRIBUTEVALUE
        throw(XmlException("can't parse xml at position $next_state"))
    end
    return (Attribute(buffer, getposition(name), first(getposition(attrval))+1:last(getposition(attrval))-1), next_state)
end

_parsetext(lexer::PreprocessLexer, buffer::StringBuffer, lexeme::Lexeme, next_state::Int64, stack::Stack) = begin
    text = TextElement(buffer, getposition(lexeme))
    element = first(stack)
    if isnothing(element)
        throw(XmlException("can't parse xml at position $next_state"))
    end
    value = getvalue(element)
    if isnothing(value)
        setvalue!(element, text)
    else
        throw(XmlException("can't parse xml at position $next_state"))
    end
    return next_state
end

_skipcloselexeme(lexer, state) = begin
    (lexeme, nextstate) = _getnext(lexer, state)
    if gettokentype(lexeme) != CLOSE_TAG
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
