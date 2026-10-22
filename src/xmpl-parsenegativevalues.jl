# Run the test program like this:
# $:julia test-parsenegativevalues.jl -f series1.dat
# $:julia test-parsenegativevalues.jl -f series1.dat --range min5 5
# $:julia test-parsenegativevalues.jl --range min5 5 -f series1.dat
# $:julia test-parsenegativevalues.jl --range mininf inf -f series1.dat

include("functions.jl") # An actual program would substitute this line for `using PlainCLIArgs` or `import PlainCLIArgs`

struct BehaviorParsenegativevalues
    filename :: String
    leftbound :: Float64
    rightbound :: Float64
end

function parseargs(args :: AbstractVector{<:AbstractString})
    # Set defaults
    leftbound = -Inf
    rightbound = Inf
    # You can write just one replace-Pair, such as the line below:
    #replacerules = r"^min" => "-"
    # Note that the left side of the Pair uses a regex to ensure only "min" at
    #   the beginning of the string is being replaced. If you want to define
    #   many, use a vector and write them from longest to shortest:
    replacerules = [r"^minus" => "-", r"^min" => "-", r"^m" => "-"]

    # Scan the args for an input filename value
    filenamedata = FlagSearchResult[]
    append!(filenamedata, seekNvaluesof(args,"-f",1))
    append!(filenamedata, seekNvaluesof(args,"--file",1))
    filename = getvalue(filenamedata)

    # Scan the args for an explicit range, overwrite the defaults if the
    #   values are found, or do nothing if the user left them blank
    rangedata = FlagSearchResult[]
    append!(rangedata, seekNvaluesof(args,"-r",2))
    append!(rangedata, seekNvaluesof(args,"--range",2))
    if countvalues(rangedata) == 2
        rangevals = getvalues(rangedata,Float64,replacerules)
        leftbound = rangevals[1]
        rightbound = rangevals[2]
    # Error out if the user passed only 1 value
    elseif countvalues(rangedata) == 1
        error("You have to pass two values to a -r/--range flag! If you only want one bound, write \"minInf\" (no left bound) or \"Inf\" (no right bound)")
    end

    return BehaviorParsenegativevalues(filename,leftbound,rightbound)
end

# ==========

bhv = parseargs(ARGS)
println(bhv)
# Pretend the rest of the program goes here
