
module TestAqua

using Aqua: test_all
using Typstry: Typstry

# TODO: test package extensions
redirect_stdout(() -> test_all(Typstry), devnull)

end # TestAqua
