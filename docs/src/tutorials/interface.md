
# Interface

This tutorial illustrates the Julia to Typst interface.

## Setup

```jldoctest 1
julia> import Base: show

julia> import Typstry: context, show_typst

julia> using Base: Docs.Text

julia> using Typstry
```

## Implementation

Consider this new type.

```jldoctest 1
julia> struct Reciprocal{N <: Number}
           n::N
       end
```

Implement the [`show_typst`](@ref) function to specify its Typst formatting.
Remember to [Annotate values taken from untyped locations](https://docs.julialang.org/en/v1/manual/performance-tips/#Annotate-values-taken-from-untyped-locations).

```jldoctest 1
julia> show_typst(io, r::Reciprocal) =
           if io[:mode]::Mode == markup
               print(io, "#let reciprocal(n) = \$1 / #n\$")
           else
               print(io, "reciprocal(")
               show_typst(io, round(r.n; digits = io[:digits]::Int))
               print(io, ")")
           end;
```

Although custom formatting may be handled in `show_typst` with `get(io, key, default)`,
this may be repetitive when specifying defaults for multiple methods.
There is also no way to tell if the value has been
specified by the user or if it is a default.
Instead, implement a custom [`context`](@ref) which overrides default,
but not user specifications.

```jldoctest 1
julia> context(::Reciprocal) = Dict(:digits => 2);
```

Now that the interface has been implemented, it is fully supported by Typstry.jl.

```jldoctest 1
julia> r = Reciprocal(π);

julia> println(TypstString(r))
#let reciprocal(n) = $1 / #n$

julia> println(TypstString(r; mode = math))
reciprocal(3.14)

julia> println(TypstString(r; mode = math, digits = 4))
reciprocal(3.1416)
```

## Guidelines

While implementing the interface only requires implementing two methods,
it may be more challenging to determine how a Julia value should be
represented in a Typst source file and its corresponding rendered document.
Julia and Typst are distinct languages that differ in both syntax and semantics,
so there may be multiple meaningful formats to choose from.

### Make the obvious choice, if available

- There is a clear correspondence between these Julia and Typst values

```jldoctest 1
julia> println(TypstString(1))
1

julia> println(TypstString(nothing))
#none

julia> println(TypstString(r"[a-z]"))
#regex("[a-z]")
```

### Choose the most meaningful and semantically rich representation

- This may vary across `Mode`s and domains
- Both Julia and Typst support Unicode characters, except unknown variables in Typst's `code` mode

```jldoctest 1
julia> println(TypstString(π; mode = code))
3.141592653589793

julia> println(TypstString(π; mode = math))
π

julia> println(TypstString(π; mode = markup))
π
```

### Consider both the Typst source text and rendered document formatting

- A `String` is meaningful in different ways for each Typst `Mode`
- A `Text` is documented to "render [its value] as plain text", and therefore corresponds to text in a rendered Typst document
- A `TypstString` represents Typst source text, and is printed directly

```jldoctest 1
julia> println(TypstString("[\"a\"]"))
"[\"a\"]"

julia> println(TypstString(text"[\"a\"]"))
#"[\"a\"]"

julia> println(TypstString(typst"[\"a\"]"))
["a"]
```

### Try to ensure that the formatting is valid Typst source text

- A `TypstString` represents Typst source text, which may be invalid
- A `UnitRange{Int}` is formatted differently for each `Mode`, but is always valid

```jldoctest 1
julia> println(TypstString(1:4; mode = code))
range(1, 5)

julia> println(TypstString(1:4; mode = math))
vec(
    1, 2, 3, 4
)

julia> println(TypstString(1:4; mode = markup))
$vec(
    1, 2, 3, 4
)$
```

### Consider edge cases

- `#1 / 2` is valid Typst source text, but is parsed partially in `code` `Mode` as `(#1) / 2`
- `1 / 2` may be ambiguous in a `math` `Mode` expression
- `$1 / 2$` is not ambiguous in `markup` `Mode`

```jldoctest 1
julia> println(TypstString(1 // 2; mode = code))
(1 / 2)

julia> println(TypstString(1 // 2; mode = math))
(1 / 2)

julia> println(TypstString(1 // 2; mode = markup))
$1 / 2$
```

### Format values in containers using `show` with the `text/typst` MIME type

- Values may require some of their `context`
- The `AbstractVector` method changes its `Mode` to `math` and increments its `depth`

```jldoctest 1
julia> println(TypstString([true, 1, Any[1.2, 1 // 2]]))
$vec(
    "true", 1, vec(
        1.2, 1 / 2
    )
)$
```

### Check parametric and abstract types

- Related Julia types may not be representable in the same Typst format

```jldoctest 1
julia> println(TypstString(1:2:6; mode = code))
range(1, 6, step: 2)

julia> println(TypstString(1:2.0:6; mode = code))
(1.0, 3.0, 5.0)
```
