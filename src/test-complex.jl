
# Example calls:
# $:julia test-complex.jl -f file1.txt
# $:julia test-complex.jl --file file1.txt file2.txt
# $:julia test-complex.jl --help
# $:julia test-complex.jl -v -b 75 -f file1.txt

include("functions.jl")

struct MyComplexProgramBehavior
    filenames :: Vector{String}
    nbins :: Int
    modequiet :: Bool
    modehelp :: Bool
end

function loadMyComplexProgramBehavior(args :: AbstractVector{<:AbstractString})
    # Set default values
    nbins = 50
    modequiet = true
    modehelp  = false

    # Check for mutual exclusivity
    ex = "Modes `quiet' and `verbose' are incompatible!"
    checkgroupexclusivity(args, ex, ["-q","--quiet"], ["-v","--verbose"])

    # This helps us detect stray flags or typos
    claimedtokens = FlagSearchResult[]

    # Resolve modehelp value
    helpdata = FlagSearchResult[]
    append!(helpdata, seekflag(args,"-h"))
    append!(helpdata, seekflag(args,"--help"))

    if !isempty(helpdata)
        modehelp = true
    end

    # Bookkeeping for stray-token detection
    append!(claimedtokens, helpdata)

    # Resolve modequiet value
    vd_quiet = FlagSearchResult[] # vd: verbosity data
    append!(vd_quiet, seekflag(args,"-q"))
    append!(vd_quiet, seekflag(args,"--quiet"))
    vd_verbose = FlagSearchResult[] # vd: verbosity data
    append!(vd_verbose, seekflag(args,"-v"))
    append!(vd_verbose, seekflag(args,"--verbose"))
    if !isempty(vd_quiet)
        modequiet = true
    elseif !isempty(vd_verbose)
        modequiet = false
    end

    # Bookkeeping for stray-token detection
    append!(claimedtokens, vd_quiet, vd_verbose)

    # Parse the requested filenames
    filenamesdata = FlagSearchResult[]
    append!(filenamesdata, seekvalsof(args,"-f"))
    append!(filenamesdata, seekvalsof(args,"--file"))

    if countvalues(filenamesdata) == 0 && !modehelp
        error("Pass a nonzero amount of filenames to analyze.\n")
    else
        filenames = getvalues(filenamesdata)
        # Here you can check that all the requested filenames exist
    end

    # Bookkeeping for stray-token detection
    append!(claimedtokens, filenamesdata)

    # See if the user passed an explicit nbins number
    binsdata = FlagSearchResult[]
    append!(binsdata, seekvalsof(args,"-b"))
    append!(binsdata, seekvalsof(args,"--nbins"))

    if countvalues(binsdata) > 1
        error("Pass only one bincount value! You passed the values $(join(getvalues.(binsdata),' '))\n")
    elseif countvalues(binsdata) == 1
        nbins = parse(Int, getvalue(binsdata))
    end

    # Final bookkeeping step
    append!(claimedtokens, binsdata)
    unclaimed = findunclaimedtokens(args,claimedtokens)
    if !isempty(unclaimed)
        error("Error in ARGS! You passed some stray options. Run \n  \$:julia myprogram.jl -h\nto see the valid options.\n\n== Stray tokens:\n"*join(writetokens(args,unclaimed),'\n'))
    end

    return MyComplexProgramBehavior(filenames,nbins,modequiet,modehelp)
end 

progbehavior = loadMyComplexProgramBehavior(ARGS)
@show progbehavior.filenames
@show progbehavior.nbins
@show progbehavior.modequiet
@show progbehavior.modehelp
