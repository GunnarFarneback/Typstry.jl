
module LaTeXStringsExtension

import Typstry: show_typst
using LaTeXStrings: LaTeXString, @L_str
using PrecompileTools: @compile_workload
using Typstry: show_raw, workload

# Strings

"""
    show_typst(io, ::LaTeXString)

Print in Typst format for LaTeXStrings.jl.

| Type          | Settings | Parameters |
|:--------------|:---------|:-----------|
| `LaTeXString` | `:mode`  | `:block`   |
"""
show_typst(io, x::LaTeXString) = show_raw(print, io, x, "latex")

# Internals

const examples = [L"a" => LaTeXString]

@compile_workload workload(examples)

end # module
