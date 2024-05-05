
# Internals

"""
    TypstText, indent_width

Wraps a `String` to construct a [`TypstString`](@ref) instead of dispatching to [`print_typst`](@ref).
"""
struct TypstText
    text::String
end

"""
    join_with(f, io, xs, delimeter; settings...)
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
"""
function enclose(f, io, x, left, right = reverse(left); settings...)
    print(io, left)
    f(io, x; settings...)
    print(io, right)
end

"""
    pad_math(io, x, inline)
"""
pad_math(mode, inline) =
    if mode == markup inline ? "\$" : "\$ "
    else ""
    end

"""
    TypstString <: AbstractString
    TypstString(x; settings...)

Construct a string with [`print_typst`](@ref).
"""
struct TypstString <: AbstractString
    text::String

    TypstString(text::TypstText) = new(text.text)
end

function TypstString(x; settings...)
    buffer = IOBuffer()
    print_typst(buffer, x; settings...)
    TypstString(TypstText(String(take!(buffer))))
end

"""
    @typst_str(s)
    typst"s"

Construct a [`TypstString`](@ref).

Values can be interpolated by calling the `TypstString` constructor,
except with a backslash `\\` instead of the type name.

!!! tip
    Use [`print_typst`](@ref) to print directly to an `IO`.

    See also the performance tip to [avoid string interpolation for I/O]
    (https://docs.julialang.org/en/v1/manual/performance-tips/#Avoid-string-interpolation-for-I/O).

# Examples
```jldoctest
julia> x = 1;

julia> typst"\$ \\(x) / \\(x + 1) \$"
typst"\\\$ 1 / 2 \\\$"

julia> typst"\\(x // 2)"
typst"\\\$ 1 / 2 \\\$"

julia> typst"\\(x // 2; mode = math)"
typst"1 / 2"

julia> typst"\\\\(x)"
typst"\\\\\\\\(x)"
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

"""
    format(io, x; settings...)

Write `x` to `io` as Typst code with the given `settings`.

Should be implemented for types passed to [`print_typst`](@ref).

!!! warning
    The methods of this function are incomplete.
    Please file an issue or create a pull-request for missing methods.
    It is safe to implement missing methods (via type-piracy) until
    it has been released in a new minor version of Typstry.jl.
"""
format(io, x::AbstractChar; mode, settings...) =
    enclose(show, io, x, mode == markup ? "\"" : "")
format(io, x::Complex; mode, inline, settings...) =
    enclose((io, x) -> print(io, sprint(print, x)[begin:end - 1]), io, x, pad_math(mode, inline))
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
format(io, x::AbstractMatrix; mode, inline, settings...) =
    enclose((io, x; indent, depth, settings...) -> begin
        print(io, "mat(\n")

        join_with((io, x; indent, depth, settings...) -> begin
            print(io, indent ^ depth)
            join_with((io, x; settings...) ->
                format(io, x; mode = math, settings...),
            io, x, ", "; indent, depth, settings...)
        end, io, eachrow(x), ";\n"; depth = depth + 1, indent, settings...)

        print(io, "\n", indent ^ depth, ")")
    end, io, x, pad_math(mode, inline); inline, settings...)
format(io, x::AbstractString; mode, settings...) =
    mode == markup ? show(io, x) : show(io, repr(x))
format(io, x::AbstractVector; mode, inline, settings...) =
    enclose((io, x; settings...) ->
        enclose((io, x; settings...) ->
            join_with((io, x; settings...) ->
                format(io, x; settings...),
            io, x, ", "; settings...),
        io, x, "vec(", ")"; settings...),
    io, x, pad_math(mode, inline); mode = math, inline, settings...)
format(io, x::Bool; mode, settings...) =
    if mode == math enclose(print, io, x, "\"")
    else
        mode == markup && print(io, "#")
        print(io, x)
    end
format(io, x::Irrational; mode, settings...) =
    mode == code ? enclose(print, io, x, "\"") : print(io, x)
format(io, x::Rational; mode, inline, settings...) =
    enclose((io, x; settings...) -> begin
      format(io, numerator(x); settings...)
      print(io, " / ")
      format(io, denominator(x); settings...)
    end, io, x, pad_math(mode, inline); mode = math, inline, settings...)
function format(io, x::Regex; mode, settings...)
    mode == code || print(io, "#")
    enclose((io, x) -> print(io, sprint(print, x)[begin + 1:end]), io, x, "regex(", ")")
end
format(io, x::Union{AbstractFloat, Signed, Text}; settings...) = print(io, x)
function format(io, x::OrdinalRange{<:Integer, <:Integer}; mode, settings...)
    mode == code || print(io, "#")

    enclose((io, x; settings...) -> begin
        format(io, first(x); settings...)
        print(io, ", ")
        format(io, last(x); settings...)
        print(io, ", step: ")
        format(io, step(x); settings...)
    end, io, x, "range(", ")"; mode = code, settings...)
end
#=
AbstractIrrational
AbstractRange
Symbol
Unsigned
Enum
=#

"""
    print_typst(io = stdout, x;
        mode = markup,
        inline = false,
        indent = ' ' ^ 4,
        depth = 0,
    settings...)

Write `x` to `io` as Typst code with default `settings`.

This function calls [`format`](@ref), which should be implemented for each type.

| Setting | Description |
|:--------|:------------|
| mode    | The Typst [`Mode`](@ref) in the current context, where `code` follows the number sign `#`, `math` is enclosed in dollar signs `\$`, and `markup` is at the top-level and enclosed in square brackets `[]`. |
| inline  | When `mode = math`, specifies whether the enclosing dollar signs `\$` are padded with a space to render the element inline or its own block. |
| indent  | The string used for horizontal spacing by some elements with multi-line Typst code. |
| depth   | Indicates the current level of nesting within container types. |
"""
print_typst(io, x; mode = markup, inline = false, indent = "    ", depth = 0, settings...) =
    format(io, x; mode, inline, indent, depth, settings...)
print_typst(x; settings...) = format(stdout, x; settings...)

# Interface

"""
    *(::TypstString, ::TypstString)
"""
x::TypstString * y::TypstString = TypstString(x.text * y.text)

"""
    show(::IO, ::TypstString)
"""
function show(io::IO, ts::TypstString)
    print(io, "typst")
    show(io, ts.text)
end

for f in (:IOBuffer, :codeunit, :iterate, :ncodeunits, :pointer)
    @eval begin
        "\t$($f)(::TypstString)"
        Base.$f(ts::TypstString) = $f(ts.text)
    end
end

for f in (:codeunit, :isvalid, :iterate)
    @eval begin
        "\t$($f)(::TypstString, ::Integer)"
        Base.$f(ts::TypstString, i::Integer) = $f(ts.text, i)
    end
end
