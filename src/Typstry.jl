
module Typstry

import Base: *, addenv, detach, ignorestatus, run, setcpuaffinity, setenv, show
using Base: Docs.Text, Iterators.Stateful, Meta.parse, escape_string, isexpr
using Typst_jll: typst

include("commands.jl")

export TypstCommand, @typst_cmd, render

include("strings.jl")

export Mode, TypstString, @typst_str, code, markup, math, _typstify

end # module
