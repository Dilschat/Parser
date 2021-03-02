using Test

import Base.collect
import Base.iterate

include("../src/lexer.jl")

function collect(lexer::Lexer)
    lexems = Vector{Lexeme}()
    for i in lexer
        push!(lexems, i)
    end
    return lexems
end

@testset "lex opentag test" begin
    xml = "<</"
    lexer = Lexer(xml)
    @test collect(lexer) == [Lexeme(START_TAG, 1:1), Lexeme(START_CLOSE_TAG, 2:3)]
end

@testset "lex closetag test" begin
    xml = ">/>"
    lexer = Lexer(xml)
    @test collect(lexer) == [Lexeme(CLOSE_TAG, 1:1), Lexeme(CLOSE_START_TAG, 2:3)]
end

@testset "lex identifier test" begin
    xml = "_lfkajlkas-jasfsa q"
    lexer = Lexer(xml)
    @test collect(lexer) == [Lexeme(IDENTIFIER, 1:17), Lexeme(IDENTIFIER, 19:19)]
end

@testset "lex attrvalue test" begin
    xml = "\"asfasfasf\"  \"a\""
    lexer = Lexer(xml)
    @test collect(lexer) == [Lexeme(ATTRIBUTEVALUE, 1:11), Lexeme(ATTRIBUTEVALUE, 14:16)]
end

@testset "lex text test" begin
    xml = "> asadsadsa-re\"fsdf  \n<"
    lexer = Lexer(xml)
    @test collect(lexer) == [Lexeme(CLOSE_TAG, 1:1), Lexeme(TEXT, 3:19), Lexeme(START_TAG, 23:23)]
end

@testset "operator test" begin
    xml = "= ="
    lexer = Lexer(xml)
    @test collect(lexer) == [Lexeme(OPERATOR, 1:1), Lexeme(OPERATOR, 3:3)]
end

@testset "xml lex test" begin
    xml = "<!-- ewfwe --> <asdasd asdasd \"w\"/>"
    lexer = Lexer(xml)
    @test collect(lexer) == [Lexeme(START_TAG, 16:16),
                            Lexeme(IDENTIFIER, 17:22), Lexeme(IDENTIFIER, 24:29),
                            Lexeme(ATTRIBUTEVALUE, 31:33), Lexeme(CLOSE_START_TAG, 34:35)]
end

@testset "error test" begin
    xml = "\"<<><sa"
    lexer = Lexer(xml)
    @test collect(lexer) == [Lexeme(ERROR, 1:7 )]
end
