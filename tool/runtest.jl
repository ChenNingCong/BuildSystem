root = abspath("../../test")
f = joinpath.(root, filter(x -> endswith(x, ".jl"), collect(walkdir(root))[1][3]))
sort!(f, by=x -> filesize(x))
succss = open("succ"; read=true) do f
    readlines(f)
end
blacklist = ["test_exec.jl", 
        "download.jl", 
        "test_sourcepath.jl", 
        "download_exec.jl", 
        "asyncmap.jl", 
        "threads.jl", 
        "backtrace.jl", 
        "stacktraces.jl",
        "staged.jl",
        # dyncall not supported
        "testdefs.jl",
        "worlds.jl",
        "spawn.jl",
        "ambiguous.jl",
        "specificity.jl",
        "llvmcall.jl", 
        "ccall.jl", 
        "opaque_closure.jl",
        "meta.jl",
        "precompile.jl",
        "runtests.jl",
        "threads_exec.jl",
        "cmdlineargs.jl",
        "subtype.jl",
        "core.jl",
        "corelogging.jl",
        "jithelper.jl"]
longtime = open("longtime"; read=true) do f
    readlines(f)
end
append!(blacklist, map(x -> splitdir(x)[2], longtime))
txt = open("succ"; append=true)
longtime = open("longtime"; append=true)
for i in f
    if i in succss || splitdir(i)[2] in blacklist
        continue
    end
    println("Starting $i")
    z = abspath("../usr/bin/julia-debug")
    succ = true
    io = IOBuffer()
    failFileName = splitdir(i)[2] * "-fail.txt"
    k = (splitdir(i)[2])
    t = run(pipeline(`$z -t 1 -O 2 --image-codegen -L newTest.jl -- runtest.jl $k`; stdout=io, stderr=io); wait=false)
    timedwait(() -> process_exited(t), 10 * 60)
    out = String(take!(io))
    println(out)
    if t.exitcode > 0 || Base.process_signaled(t)
        println("Fail: $i")
        open(failFileName; write=true) do f
            write(f, out)
        end
        succ = false
    elseif process_running(t)
        println("Unfinished: $i")
        kill(t)
        succ = false
        println(longtime, i)
        flush(longtime)
    else
        println("Succ: $i")
        if isfile(failFileName)
            rm(failFileName)
        end
        println(txt, i)
        flush(txt)
    end
    sleep(0.5)
end