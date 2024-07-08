
module TestStrings

import Typstry: context, show_typst
using .Meta: parse
using Test: @test, @testset
using Typstry

# TODO: test characters with multiple codeunits

struct X end

const default_context = Dict(
    :backticks => 3,
    :block => false,
    :depth => 0,
    :mode => markup,
    :parenthesize => true,
    :tab_size => 2
)
const typst_int = Typst(1)
const x = X()
const x_context = Dict(:x => 1)

context(::X) = x_context
show_typst(io, ::X) = print(io, 1)

const pairs = [
    typst"" => "",
    typst"x" => "x",
    typst"(x)" => "(x)",
    typst"a(x)b" => "a(x)b",
    typst"ab(x)cd" => "ab(x)cd",
    typst"\(x)" => "1",
    typst"a\(x)b" => "a1b",
    typst"ab\(x)cd" => "ab1cd",
    typst"\\(x)" => "\\(x)",
    typst"a\\(x)b" => "a\\(x)b",
    typst"ab\\(x)cd" => "ab\\(x)cd",
    typst"\\\(x)" => "\\1",
    typst"a\\\(x)b" => "a\\1b",
    typst"ab\\\(x)cd" => "ab\\1cd",
    typst"\\\\(x)" => "\\\\(x)",
    typst"a\\\\(x)b" => "a\\\\(x)b",
    typst"ab\\\\(x)cd" => "ab\\\\(x)cd",
    typst"\(x)\(x)" => "11",
    typst"a\(x)b\(x)c" => "a1b1c",
    typst"ab\(x)cd\(x)ef" => "ab1cd1ef",
    typst"\\(x)\(x)" => "\\(x)1",
    typst"a\\(x)b\(x)c" => "a\\(x)b1c",
    typst"ab\\(x)cd\(x)ef" => "ab\\(x)cd1ef",
    typst"\(x)\\(x)" => "1\\(x)",
    typst"a\(x)b\\(x)c" => "a1b\\(x)c",
    typst"ab\(x)cd\\(x)ef" => "ab1cd\\(x)ef"
]

test_pairs(f) = for pair in pairs
    @test f(pair...)
end

@testset "`Typstry`" begin
    @testset "`Mode`" begin
        @test Mode <: Enum
        @test instances(Mode) == map(Mode, (0, 1, 2)) == (code, markup, math)
    end

    @testset "`Typst`" begin
        @test typst_int == typst_int
        @test typst_int != Typst(1.0)
        @test typeof(typst_int) == Typst{Int}
        @test string(typst_int) == "Typst{Int64}(1)"
    end

    @testset "`TypstString`" begin end

    @testset "`TypstText`" begin end

    @testset "`@typst_str`" begin test_pairs((ts, s) -> ts == sprint(print, ts) == s) end

    @testset "`context`" begin
        @test context(1) == Dict{Symbol, Union{}}()
        @test context(X()) == x_context
        @test context(typst_int) == default_context
        @test context(Typst(x)) == merge(default_context, x_context)
    end

    @testset "`show_typst`" begin end
end

@testset "`Base`" begin
    @testset "`IOBuffer`" begin
        for pair in pairs
            ==(map(read ∘ IOBuffer, pair)...)
        end
    end

    @testset "`codeunit`" begin test_pairs() do ts, s
        codeunit(ts) == codeunit(s) && all(i -> codeunit(ts, i) == codeunit(s, i), eachindex(ts))
    end end

    @testset "`isvalid`" begin end

    @testset "`iterate`" begin end

    @testset "`length`" begin test_pairs((ts, s) -> length(ts) == length(s)) end

    @testset "`ncodeunits`" begin end

    @testset "`pointer`" begin end

    @testset "`repr`" begin
        test_pairs((ts, s) -> repr(MIME"text/typst"(), ts) === eval(parse(repr(ts))) === ts)
    end

    @testset "`show`" begin end
end

end # TestStrings

