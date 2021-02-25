import Base.iterate
include("position.jl")

@enum PreprocessToken begin
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
    token::PreprocessToken
    position::Position
end

gettokentype(lexeme::Lexeme) = lexeme.token
getposition(lexeme::Lexeme) = lexeme.position

struct PreprocessLexer
    input::String
end

getinput(lexer::PreprocessLexer) = lexer.input

iterate(lexer::PreprocessLexer, state::Int = 1) = begin
    input = lexer.input
    length = ncodeunits(input)
    if state > length
        return nothing
    end
    curpos = state
    while curpos <= length &&(input[curpos] == ' ' || input[curpos] == '\n')
        curpos += 1
    end
    if curpos > ncodeunits(input)
        return nothing
    elseif input[curpos] == '<'
        return _processopentag(lexer, curpos)
    elseif  input[curpos] == '>'
        return (Lexeme(CLOSE_TAG, curpos:curpos), curpos + 1)
    elseif input[curpos] == '/'
        _processclosetag(lexer, curpos)
    elseif input[curpos] == '='
        return (Lexeme(OPERATOR, curpos:curpos), curpos + 1)
    elseif input[curpos] == '"'
        return _processstringvalue(lexer, curpos)
    elseif state > 1 && input[state-1] == '>'
        _processtext(lexer, curpos)
    elseif input[curpos] == '_' || isletter(input[curpos])
        return _processidentifier(lexer, curpos)
    else
        return (Lexeme(ERROR, curpos:curpos), curpos)
    end
end

_processopentag(lexer::PreprocessLexer, i::Int64) = begin
    if i+1 > ncodeunits(lexer.input)
        return (Lexeme(START_TAG, i:i), i+1)
    elseif lexer.input[i+1] == '!'
        next = _skipcomment(lexer, i)
        if isnothing(next)
            return (Lexeme(ERROR, i:i), i+1)
        end
        return iterate(lexer, next)
    elseif lexer.input[i+1] == '/'
        return (Lexeme(START_CLOSE_TAG, i:i+1), i+2)
    elseif lexer.input[i+1] == '_' || isletter(lexer.input[i])
        return (Lexeme(START_TAG, i:i), i+1)
    else
        return (Lexeme(START_TAG, i:i), i+1)
    end
end

_skipcomment(lexer::PreprocessLexer, i::Int64) = begin
    c = _getchar(lexer, i)
    c != '<' && return nothing
    c = _getchar(lexer, i+1)
    c != '!' && return nothing
    c = _getchar(lexer, i+2)
    c != '-' && return nothing
    c = _getchar(lexer, i+3)
    c != '-' && return nothing
    i = i + 4
    while _getchar(lexer, i) != '>'
        i+=1
    end
    c = _getchar(lexer, i-1)
    c != '-' && return nothing
    c = _getchar(lexer, i-2)
    c != '-' && return nothing
    return i+1
end

_processclosetag(lexer, i) = begin
    if lexer.input[i+1] == '>'
        return (Lexeme(CLOSE_START_TAG, i:i+1), i+2)
    else
        return (Lexeme(ERROR, i:i), i+1)
    end
end

_processstringvalue(lexer, i) = begin
    length = ncodeunits(lexer.input)
    start = i
    i += 1
    while i <= length && lexer.input[i] != '"'
        i += 1
    end
    if i == length && lexer.input[i] != '"'
        return (Lexeme(ERROR, start:i), i+1)
    end
    return (Lexeme(ATTRIBUTEVALUE, start:i), i+1)
end

_processidentifier(lexer, i) = begin
    length = ncodeunits(lexer.input)
    input = lexer.input
    start = i
    i += 1
    while i <= length && (isletter(input[i]) || isdigit(input[i]) || input[i] == '_' ||
            input[i] == '.' || input[i] == '-' )
        i += 1
    end
    return (Lexeme(IDENTIFIER, start:i-1), i)

end

_processtext(lexer, i) = begin
    length = ncodeunits(lexer.input)
    input = lexer.input
    start = i
    i += 1
    lastnotwhitespace = i
    while i <= length && input[i] != '<' && input[i] != '>'
        if input[i] != ' ' && input[i] != '\n'
            lastnotwhitespace = i
        end
        i += 1
    end
    if i > length || input[i] == '>'
        return (Lexeme(ERROR, start:i-1), i)
    end
    return (Lexeme(TEXT, start:lastnotwhitespace), i)
end

_getchar(lexer::PreprocessLexer, i::Int64) = begin
    length = ncodeunits(lexer.input)
    if i > length
        return nothing
    end
    @inbounds lexer.input[i]
end
