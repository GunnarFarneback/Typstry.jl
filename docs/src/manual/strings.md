
# Strings

## `Typstry`

```@docs
Mode
Typst
TypstString
TypstText
@typst_str
code
markup
math
context
show_typst
```

## `Base`

```@docs
IOBuffer
codeunit
isvalid
iterate(::TypstString)
ncodeunits
pointer
repr
show(::IO, ::TypstString)
show(::IOContext, ::MIME"text/typst", ::Typst)
show(::IO, ::Union{MIME"application/pdf", MIME"image/png", MIME"image/svg+xml"}, ::TypstString)
```
