export judir="$(readlink -f $(dirname "${BASH_SOURCE[0]}")/../../julia-*/)"
export prepareJITPath="$(readlink -f $(dirname "${BASH_SOURCE[0]}"))"
if test -d $judir
then
    echo "$judir is set to be the root path of julia excutable (released mode)"
else
    export judir="$(readlink -f $(dirname "${BASH_SOURCE[0]}")/../../julia*/)"
    if test -d $judir
    then
        echo "$judir is set to be the root path of julia excutable (debug mode)" 
    else
        echo "$judir is not a dir, julia executable should be placed at this path"
        return 0
    fi
fi
# echo "$judir is set to be the root path of julia excutable"
export ju18exe=$judir/usr/bin/julia
if test -f $ju18exe
then
    echo "$ju18exe is set to be the root path of julia excutable (debug mode)"
else
    export ju18exe=$judir/bin/julia
    if test -f $ju18exe
    then
        echo "$ju18exe is set to be the root path of julia excutable (release mode)"
    else
        echo "Julia binary executeable is not found."
        return 0
    fi
fi
alias ju18="$ju18exe -O2 -t 1 --compile=all --image-codegen -L \"${prepareJITPath}/prepareJIT.jl\""
alias jbuild="$ju18exe -O2 -t 1 --"
echo $(alias ju18)
echo $(alias jbuild)
echo "XXX$ju18exe"