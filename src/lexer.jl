import Base.iterate

@enum LexemeType begin
    START_TAG       #<
    START_CLOSE_TAG #</
    CLOSE_TAG       #>
    CLOSE_START_TAG # />
    OPERATOR # =
    IDENTIFIER # tag name, attribute name
    ATTRIBUTEVALUE # "value"
    TEXT # any
    ERROR
end

struct Lexeme
    token::LexemeType
    position::UnitRange{Int64}
end

getlexemetype(lexeme::Lexeme) = lexeme.token
getposition(lexeme::Lexeme) = lexeme.position

#TODO input as string buffer
struct Lexer
    input::String
end

getinput(lexer::Lexer) = lexer.input

"""
    Iterates over all accessible lexemes presented in input from Lexer.
"""
iterate(lexer::Lexer, state::Int = 1) = begin
    input = lexer.input
    inputlength = ncodeunits(input)
    currentposition = state
    c = _getchar(lexer, currentposition, inputlength)
    while currentposition <= inputlength && (c == ' ' || c == '\n')
        currentposition += 1
        c = _getchar(lexer, currentposition, inputlength)
    end

    c = _getchar(lexer, currentposition, inputlength)
    if isnothing(c)
        return nothing
    elseif c == '<'
        return _processopentag(lexer, currentposition)
    elseif c == '>'
        return (
            Lexeme(CLOSE_TAG, currentposition:currentposition),
            currentposition + 1,
        )
    elseif c == '/'
        _processclosetag(lexer, currentposition)
    elseif c == '='
        return (
            Lexeme(OPERATOR, currentposition:currentposition),
            currentposition + 1,
        )
    elseif c == '"'
        return _processstringvalue(lexer, currentposition)
    elseif state > 1 && _getchar(lexer, state - 1, inputlength) == '>'
        _processtext(lexer, currentposition)
    elseif c == '_' || isletter(c)
        return _processidentifier(lexer, currentposition)
    else
        return (Lexeme(ERROR, currentposition:currentposition), currentposition)
    end
end

_processopentag(lexer::Lexer, i::Int64) = begin
    inputlength = ncodeunits(lexer.input)
    c = _getchar(lexer, i + 1, inputlength)
    if c == '!'
        next = _skipcomment(lexer, i)
        if isnothing(next)
            return (Lexeme(ERROR, i:i), i + 1)
        end
        return iterate(lexer, next)
    elseif c == '/'
        return (Lexeme(START_CLOSE_TAG, i:i+1), i + 2)
    elseif c == '_' || isletter(_getchar(lexer, i, inputlength))
        return (Lexeme(START_TAG, i:i), i + 1)
    else
        return (Lexeme(START_TAG, i:i), i + 1)
    end
end

_skipcomment(lexer::Lexer, i::Int64) = begin
    length = ncodeunits(lexer.input)
    c = _getchar(lexer, i, length)
    c != '<' && return nothing
    c = _getchar(lexer, i + 1, length)
    c != '!' && return nothing
    c = _getchar(lexer, i + 2, length)
    c != '-' && return nothing
    c = _getchar(lexer, i + 3, length)
    c != '-' && return nothing
    i = i + 4
    while _getchar(lexer, i, length) != '>'
        i += 1
    end
    c = _getchar(lexer, i - 1, length)
    c != '-' && return nothing
    c = _getchar(lexer, i - 2, length)
    c != '-' && return nothing
    return i + 1
end

_processclosetag(lexer, i) = begin
    inputlength = ncodeunits(lexer.input)
    if _getchar(lexer, i + 1, inputlength) == '>'
        return (Lexeme(CLOSE_START_TAG, i:i+1), i + 2)
    else
        return (Lexeme(ERROR, i:i), i + 1)
    end
end

_processstringvalue(lexer, i) = begin
    length = ncodeunits(lexer.input)
    start = i
    stop = i
    for j in Iterators.countfrom(start + 1, 1)
        if j >= length || _getchar(lexer, j, length) == '"'
            stop = j
            break
        end
    end
    if stop == length && _getchar(lexer, stop, length) != '"'
        return (Lexeme(ERROR, start:stop), stop + 1)
    elseif stop > length
        return (Lexeme(ERROR, start:stop), stop + 1)
    end
    return (Lexeme(ATTRIBUTEVALUE, start:stop), stop + 1)
end

_processidentifier(lexer, i) = begin
    length = ncodeunits(lexer.input)
    input = lexer.input
    start = i
    stop = i
    for j in Iterators.countfrom(start + 1, 1)
        c = _getchar(lexer, j, length)
        if isnothing(c) ||
           (!isletter(c) && !isdigit(c) && c != '_' && c != '.' && c != '-')
            stop = j
            break
        end
    end
    return (Lexeme(IDENTIFIER, start:stop-1), stop)
end

_processtext(lexer, i) = begin
    length = ncodeunits(lexer.input)
    input = lexer.input
    start = i
    stop = i
    lastnotwhitespace = i

    for j in Iterators.countfrom(start + 1, 1)
        c = _getchar(lexer, j, length)
        if isnothing(c) || c == '<' || c == '>'
            stop = j
            break
        end
        if c != ' ' && c != '\n'
            lastnotwhitespace = j
        end
    end
    next = _getchar(lexer, stop, length)
    if isnothing(next) || next == '>'
        return (Lexeme(ERROR, start:stop-1), stop)
    end
    return (Lexeme(TEXT, start:lastnotwhitespace), stop)
end

_getchar(lexer::Lexer, i::Int64, length::Int64) = begin
    if i > length || i < 1
        return nothing
    end
    @inbounds lexer.input[i]
end
