# Run the test program like this:
# $:julia test-seekNvaluesof.jl points1.dat --temp 300
# $:julia test-seekNvaluesof.jl --temp 300 points1.dat
# $:julia test-seekNvaluesof.jl --niter 500 --temp 300 points1.dat
# $:julia test-seekNvaluesof.jl --temp 300 points1.dat --niter 500 

include("functions.jl") # An actual program would substitute this line for `using PlainCLIArgs` or `import PlainCLIArgs`

struct BehaviorSeekNvaluesof
    filename :: String
    temp :: Float64
    niter :: Int
end

function parseargs(args :: AbstractVector{<:AbstractString})
    # Set defaults
    temp = 273.15
    niter = 1000

    claimedtokens = FlagSearchResult[]

    # Scan the args for a temperature value, and overwrite the default if one is found
    tempdata = FlagSearchResult[]
    append!(tempdata, seekNvaluesof(args,"-t",1))
    append!(tempdata, seekNvaluesof(args,"--temp",1))
    countvalues(tempdata) == 1 ? temp = getvalue(tempdata,Float64) : nothing

    append!(claimedtokens,tempdata) # For detecting unclaimed tokens

    # Scan the args for a niterations value, and overwrite the default if one is found
    niterdata = FlagSearchResult[]
    append!(niterdata, seekNvaluesof(args,"-n",1))
    append!(niterdata, seekNvaluesof(args,"--niter",1))
    countvalues(niterdata) == 1 ? niter = getvalue(niterdata,Int) : nothing

    append!(claimedtokens,niterdata) # For detecting unclaimed tokens

    # There should be exactly one unclaimed token containing the filename
    unclaimed = findunclaimedtokens(args,claimedtokens)

    # Do a final check and hopefully return the struct; we're finally done parsing the input
    if countvalues(unclaimed) != 1
        error("It's mandatory that you pass exactly one filename containing a data cloud!")
    elseif length(unclaimed) != 1
        error("It's mandatory that you pass exactly one filename containing a data cloud! Or maybe, did you pass a typo flag?")
    else
        filename = getvalue(unclaimed)

        # In a real program this block wouldn't exist, but I moved the
        #   return statement earlier so that this demonstration runs
        #   correctly
        return BehaviorSeekNvaluesof(filename,temp,niter)

        if !isfile(filename)
            error("The filename $filename does not exist! Or perhaps you passed an undefined flag and I thought it was a filename.")
        else
            return BehaviorSeekNvaluesof(filename,temp,niter)
        end
    end
end

# ==========

bhv = parseargs(ARGS)
println(bhv)
# Pretend the rest of the program goes here
