
"""
    print_parameters(io, f, keys)

Print the name of a Typst function,
an opening parenthesis,
the parameters to a Typst function,
and a newline.

Skip `keys` that are not in the `IOContext`.

# Examples
```jldoctest
julia> Typstry.print_parameters(IOContext(stdout, :delim => "\\\"(\\\""), "vec", [:delim, :gap])
vec(delim: "(",
```
"""
function print_parameters(io, f, keys)
    print(io, f, "(")
    
    for key in keys
        value = get(io, key, "")::String
        isempty(value) || print(io, key, ": ", value, ", ")
    end

    println(io)
end

"""
    code_mode(io)

Print the number sign `#` unless `mode(io) == code`.

See also [`mode`](@ref Typstry.mode).

# Examples
```jldoctest
julia> Typstry.code_mode(IOContext(stdout, :mode => code))

julia> Typstry.code_mode(IOContext(stdout, :mode => markup))
#

julia> Typstry.code_mode(IOContext(stdout, :mode => math))
#
```
"""
code_mode(io) = if mode(io) != code print(io, "#") end

"""
    escape_quote(io, s)

Print the string, with quotes `"` escaped.

# Examples
```jldoctest
julia> Typstry.escape_quote(stdout, TypstString("a"))
"\\\"a\\\""
```
"""
escape_quote(io, s) = enclose(io, s, "\"") do io, s
    for c in s
        c == '"' && print(io, "\\")
        print(io, c)
    end
end

"""
    typst_mime

A constant equal to `MIME"text/typst"()`.

# Examples
```jldoctest
julia> Typstry.typst_mime
MIME type text/typst

julia> show(stdout, Typstry.typst_mime, 1//2)
\$1 / 2\$
```
"""
const typst_mime = MIME"text/typst"()

"""
    join_with(f, io, xs, delimeter; settings...)

Similar to `join`, but printing with `f(io, x; settings...)`.

# Examples
```jldoctest
julia> Typstry.join_with((io, i; x) -> print(io, -i, x), stdout, 1:4, ", "; x = "x")
-1x, -2x, -3x, -4x
```
"""
function join_with(f, io, xs, delimeter; settings...)
    _xs = Stateful(xs)

    for x in _xs
        f(io, x; settings...)
        isempty(_xs) || print(io, delimeter)
    end
end

"""
    enclose(f, io, x, left, right = reverse(left); settings...)

Call `f(io, x; settings...)` in between printing `left` and `right`, respectfully.

# Examples
```jldoctest
julia> Typstry.enclose((io, i; x) -> print(io, i, x), stdout, 1, "\\\$ "; x = "x")
\$ 1x \$
```
"""
function enclose(f, io, x, left, right = reverse(left); settings...)
    print(io, left)
    f(io, x; settings...)
    print(io, right)
end

"""
    math_pad(io, x)

Return `""`, `"\\\$"`, or `"\\\$ "` depending on whether `mode(io) == math` and `inline(io)`.

See also [`mode`](@ref Typstry.mode) and [`inline`](@ref Typstry.inline).

# Examples
```jldoctest
julia> Typstry.math_pad(IOContext(stdout, :mode => math))
""

julia> Typstry.math_pad(IOContext(stdout, :mode => markup, :inline => true))
"\\\$"

julia> Typstry.math_pad(IOContext(stdout, :mode => markup, :inline => false))
"\\\$ "
```
"""
math_pad(io) =
    if mode(io) == math ""
    else inline(io) ? "\$" : "\$ "
    end

"""
    TypstText(::Any)

A wrapper to construct a [`TypstString`](@ref) using `print`
instead of `show` with the `"text/typst"` MIME type.

!!! info
    Use `TypstText` to insert text into a `TypstString`
    and by extension a Typst source file.
    Use `Text` to directly insert text into a Typst document.

    Note that unescaped control characters, such as `"\n"`,
    in `TypstString`s are not escaped when being printed with `show`.
    This may break formatting in some environments such as the REPL.
"""
struct TypstText
    text::String

    TypstText(x) = new(string(x))
end

"""
    TypstString <: AbstractString
    TypstString(x, ::Pair{Symbol}...)

Construct a string from [`show`](@ref) with `MIME"text/typst"`.
"""
struct TypstString <: AbstractString
    text::String

    TypstString(text::TypstText) = new(text.text)
end

function TypstString(x, settings...)
    buffer = IOBuffer()
    show(IOContext(buffer, settings...), typst_mime, x)
    TypstString(TypstText(String(take!(buffer))))
end

"""
    @typst_str(s)
    typst"s"

Construct a [`TypstString`](@ref).

Values can be interpolated by calling the `TypstString` constructor,
except with a backslash `\\` instead of the type name.

!!! tip
    Use [`show`](@ref) with `MIME"text/typst"` to print directly to an `IO`.

    See also the performance tip to [avoid string interpolation for I/O]
    (https://docs.julialang.org/en/v1/manual/performance-tips/#Avoid-string-interpolation-for-I/O).

# Examples
```jldoctest
julia> x = 1;

julia> typst"\$\\(x) / \\(x + 1)\$"
typst"\$1 / 2\$"

julia> typst"\\(x // 2)"
typst"\$1 / 2\$"

julia> typst"\\(x // 2, :mode => math)"
typst"1 / 2"

julia> typst"\\\\(x)"
typst"\\\\(x)"
```
"""
macro typst_str(s)
    _s = Expr(:string)
    args = _s.args
    filename = string(__source__.file)
    previous = current = firstindex(s)
    last = lastindex(s)

    while (regex_match = match(r"(?<!\\)\\\(", s, current)) !== nothing
        current = prevind(s, regex_match.offset)
        start = current + 2
        previous <= current && push!(args, s[previous:current])
        _, current = parse(s, start; filename, greedy = false)
        previous = current
        push!(args, esc(parse("TypstString" * s[start:current - 1]; filename)))
    end

    previous <= last && push!(args, s[previous:last])
    :(TypstString(TypstText($_s)))
end

"""
    Mode

An `Enum`erated type to indicate whether the current context
is in `code`, `markup`, or `math` mode.

```jldoctest
julia> Mode
Enum Mode:
code = 0
markup = 1
math = 2
```
"""
@enum Mode code markup math

for (setting, type) in [:mode => Mode, :inline => Bool, :indent => String, :depth => Int]
    @eval begin
        "\t$($setting)(io)\nReturn `io[$($(QuoteNode(setting)))]::$($type)`."
        $setting(io) = io[$(QuoteNode(setting))]::$type
    end
end

"""
    settings

A constant `NamedTuple` containing the default `IOContext` settings
for `show` with the `"text/typst"` MIME type.
"""
const settings = (
    mode = markup,
    inline = true,
    indent = "    ",
    depth = 0
)

"""
    show(::IO, ::MIME"text/typst", x)

Write `x` to `io` as Typst code.

Provides default settings for [`show_typst`](@ref).

| Setting   | Default   | Type           | Description |
|:----------|:----------|:---------------|:------------|
| `:mode`   | `markup`  | [`Mode`](@ref) | The current Typst context where `code` follows the number sign `#`, `markup` is at the top-level and enclosed in square brackets `[]`, and `math` is enclosed in dollar signs `\$`. |
| `:inline` | `true`    | `Bool`         | When `mode = math`, specifies whether the enclosing dollar signs `\$` are padded with a space to render the element inline or its own block. |
| `:indent` | `' ' ^ 4` | `String`       | The string used for horizontal spacing by some elements with multi-line Typst code. |
| `:depth`  | `0`       | `Int`          | The current level of nesting within container types to specify the degree of indentation. |
"""
show(io::IO, ::MIME"text/typst", x) =
    show_typst(IOContext(io, map(key -> key => get(io, key, settings[key]), keys(settings))...), x)

"""
    show_typst(io, x)

Settings are used in Julia to format the [`TypstString`](@ref) and can be any type.
Parameters are passed to a Typst function and must be a `String`.

| Type                                 | Settings                                | Parameters |
|:-------------------------------------|:----------------------------------------|:-----------|
| `AbstractChar`                       | `:mode`                                 |            |
| `AbstractFloat`                      |                                         |            |
| `AbstractMatrix`                     | `:mode`, `:inline`, `:indent`, `:depth` | `:delim`, `:augment`, `:gap`, `:row_gap`, `:column_gap` |
| `AbstractString`                     | `:mode`                                 |            |
| `AbstractVector`                     | `:mode`, `:inline`, `:indent`, `:depth` | `:delim`, `:gap` |
| `Bool`                               | `:mode`                                 |            |
| `Complex`                            | `:mode`, `:inline`                      |            |
| `Irrational`                         | `:mode`                                 |            |
| `Nothing`                            | `:mode`                                 |            |
| `OrdinalRange{<:Integer, <:Integer}` | `:mode`                                 |            |
| `Rational`                           | `:mode`, `:inline`                      |            |
| `Regex`                              | `:mode`                                 |            |
| `Signed`                             |                                         |            |
| `Text`                               | `:mode`                                 |            |
| `TypstText`                          |                                         |            |

!!! warning
    This function's methods are incomplete.
    Please file an issue or create a pull-request for missing methods.
    It is safe to implement missing methods (via type-piracy) until
    it has been released in a new minor version of Typstry.jl.
"""
show_typst(io, x::AbstractChar) =
    enclose(show, io, x, mode(io) == code ? "\"" : "")
# function format(io, x::AbstractDict{<:AbstractString}; mode, settings...)
#     mode == code || print(io, "#")

#     enclose(io, "(", ")") do
#         map_join(io, pairs(x), ", ") do (key, value)
#             # ?
#             print(io, ": ")
#             typstify(io, value; mode = code, settings)
#         end
#     end
# end
show_typst(io, x::AbstractFloat) = print(io, x)
show_typst(io, x::AbstractMatrix) =
    enclose((io, x; indent, depth) -> begin
        _depth = depth + 1

        print_parameters(io, "mat", [:delim, :augment, :gap, :row_gap, :column_gap])
        join_with((io, x; indent) -> begin
            print(io, indent ^ _depth)
            join_with((io, x) -> show_typst(io, x), io, x, ", ")
        end, IOContext(io, :mode => math, :depth => _depth), eachrow(x), ";\n"; indent)
        print(io, "\n", indent ^ depth, ")")
    end, io, x, math_pad(io); indent = indent(io), depth = depth(io))
show_typst(io, x::AbstractString) = enclose(io, x, "\"") do io, x
    s = mode(io) == markup ? "" : "\\\""
    enclose(io, x, s, s) do io, x
        for c in x
            c == '"' && print(io, "\\\\\\")
            print(io, c)
        end
    end
end
show_typst(io, x::AbstractVector) = enclose(IOContext(io, :mode => math), x, math_pad(io)) do io, x
    _depth, _indent = depth(io), indent(io)
    __depth = _depth + 1
    print_parameters(io, "vec", [:delim, :gap])
    print(io, _indent ^ __depth)
    join_with(show_typst, IOContext(io, :depth => __depth), x, ", "),
    print(io, "\n", _indent ^ _depth, ")")
end
function show_typst(io, x::Bool)
    _mode = mode(io)

    if _mode == math enclose(print, io, x, "\"")
    elseif _mode == markup print(io, "#", x)
    else print(io, x)
    end
end
show_typst(io, x::Complex) =
    enclose((io, x) -> print(io, sprint(print, x)[begin:end - 1]), io, x, math_pad(io))
show_typst(io, x::Irrational) =
    mode(io) == code ? show_typst(io, Float64(x)) : print(io, x)
show_typst(io, ::Nothing) = if mode(io) != markup print(io, "\"\"") end
function show_typst(io, x::OrdinalRange{<:Integer, <:Integer})
    code_mode(io)

    enclose((io, x) -> begin
        show_typst(io, first(x))
        print(io, ", ")
        show_typst(io, last(x) + 1)
        print(io, ", step: ")
        show_typst(io, step(x))
    end, IOContext(io, :mode => code), x, "range(", ")")
end
function show_typst(io, x::Rational)
    _mode = mode(io)
    f = (io, x) -> begin
        show_typst(io, numerator(x))
        print(io, " / ")
        show_typst(io, denominator(x))
    end

    if _mode == code enclose(f, IOContext(io, :mode => code), x, "(", ")")
    elseif _mode == markup enclose(f, IOContext(io, :mode => math), x, inline(io) ? "\$" : "\$ ")
    else f(io, x)
    end
end
function show_typst(io, x::Regex)
    code_mode(io)
    enclose((io, x) -> print(io, sprint(print, x)[begin + 1:end]), io, x, "regex(", ")")
end
show_typst(io, x::Signed) = print(io, x)
function show_typst(io, x::Text)
    code_mode(io)
    escape_quote(io, repr(x))
end
show_typst(io, x::TypstText) = print(io, x.text)
#=
AbstractIrrational
AbstractRange
Symbol
Unsigned
Enum
=#
