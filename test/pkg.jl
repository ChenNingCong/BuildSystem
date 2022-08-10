import Pkg
Pkg.status()
Pkg.add("Example")
Pkg.test("Example")
Pkg.rm("Example")
Pkg.gc()