
# Example calls:
# $:julia test-simple.jl -q file1.txt
# $:julia test-simple.jl file1.txt --quiet
# $:julia test-simple.jl file1.txt --verbose

include("functions.jl")

struct MySimpleProgramBehavior
    filename  :: String
    modequiet :: Bool
end
function loadMySimpleProgramBehavior(args :: AbstractVector{<:AbstractString})
    # Set default values
    modequiet = true

    parsedargs = parseargs(args)
    if "-v" in parsedargs.chars || "--verbose" in parsedargs.strings
        modequiet = false
    end

    filename = only(parsedargs.vals)

    return MySimpleProgramBehavior(filename,modequiet)
end

progbehavior = loadMySimpleProgramBehavior(ARGS)
@show progbehavior.filename
@show progbehavior.modequiet
