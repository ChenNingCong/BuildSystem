const LOG_FLAG = Ref{Int}(1)
function logMsg(msg)
    i = LOG_FLAG[]
    if i == 1
        println(stdout, msg)
    end
end
function setLogLevel!(i::Int)
    LOG_FLAG[] = i
end