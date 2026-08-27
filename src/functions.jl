
"""
    ParsedArguments

Classify the args within ARGS, hence you can use this struct directly
if you're only interested in the presence/absence of toggles such as
`-v` or `--quiet`.

The function [`parseargs`](@ref) takes `ARGS` and returns a `ParsedArguments` value.

# Fields
- `strings::Vector{String}`: A list of the double-dash flags such
    as `--quiet`.
- `chars::Vector{String}`: A list of the single-dash flags such
    as `-q`.
- `vals::Vector{String}`: A list of all args that don't start
    with a dash, such as `file1.txt`.
- `args::Vector{String}`: A copy of the original string-vector that
    generated this `ParsedArguments` value.

# Example
```julia
# Suppose your program only takes 1 filename and it only has two modes:
#   quiet and verbose. Then, all of these calls are correct:
# \$:julia script.jl file1.txt
# \$:julia script.jl file1.txt -q
# \$:julia script.jl --quiet file1.txt
# \$:julia script.jl file1.txt -v
# \$:julia script.jl -v file1.txt
# \$:julia script.jl file1.txt --verbose

# And the part of the script that reads the command-line arguments
#   looks like this:
modequiet = true
parsedargs = parseargs(ARGS)
if "-v" in parsedargs.chars || "--verbose" in parsedargs.strings
    modequiet = false
end
filename = only(parsedargs.vals)
```
"""
struct ParsedArguments
    strings :: Vector{String} # Such as "--file", "--verbose", ...
    chars   :: Vector{String} # Such as "-f", "-v", "-q", ... . Note that an input arg "-ab" will get split into "-a" and "-b"
    vals    :: Vector{String} # The arguments that don't start with dashes
    args    :: Vector{String} # The full list of arguments
end

function Base.:(==)(pa1 :: ParsedArguments, pa2 :: ParsedArguments)
    return pa1.strings == pa2.strings &&
           pa1.chars == pa2.chars &&
           pa1.vals == pa2.vals &&
           pa1.args == pa2.args
end

"""
    FlagSearchResult

Return type of the toggle-detector [`seekflag`](@ref) and
the value-fetching [`seekvalsof`](@ref). Crucial part of
the "detect any stray flags or args" machinery
(see [`findunclaimedtokens`](@ref)).

The user wouldn't interact with a `FlagSearchResult` value directly, but rather
through [`getvalue`](@ref), [`getvalues`](@ref), [`countvalues`](@ref),
or [`writetokens`](@ref).

# Fields
- `whicharg :: Int`: Index of this token in ARGS.
- `whichtoken :: Int`: Sub-index of this token within its arg.
    A string or value (`--quiet` or `file1.txt`) always has
    `whichtoken == 1`; this field is only meaningful for chars
    within a char-flag cluster: `-lthr` has tokens from 1 (`-l`)
    to 4 (`-r`).
- `value :: String`: The string that these `whicharg` and `whichtoken` values
    refer to. This field is only meaningful for values (strings not
    starting with dashes) in `ARGS`, such as `file1.txt`, `50`, `purple`.

# Example
```julia
# \$:julia script.jl -f file1.txt --nbins 80
nbins = 50 # Default value
bincountdata = seekvalsof(ARGS,"--nbins"))
if countvalues(bincountdata) == 1
    nbins = getvalue(bincountdata,Int)
elseif countvalues(bincountdata) > 1
    error("You can pass a maximum of one bincount value!")
end
# bincountdata == FlagSearchResult(4,1,"80")
```
"""
struct FlagSearchResult
    whicharg :: Int
    whichtoken :: Int
    value :: String
end

function Base.:(==)(sr1 :: FlagSearchResult, sr2 :: FlagSearchResult)
    return sr1.whicharg == sr2.whicharg &&
           sr1.whichtoken == sr2.whichtoken &&
           sr1.value == sr2.value
end

"""
    maybeparse(targettype::DataType,sval::AbstractString)::targettype

Auxiliary function for `getvalue` and `getvalues`. Attempt to convert the
`value` field of a `FlagSearchResult` to the user's requested datatype,
using the function `parse`.
"""
function maybeparse(targettype :: DataType, sval :: AbstractString)
    if targettype <: AbstractString
        # `parse` errors out for `String`->`String` conversion,
        #   hence this branch of the ifblock
        return sval
    else
        return parse(targettype, sval)
    end
end

"""
    getvalue(sr::FlagSearchResult)::String
    getvalue(sr::FlagSearchResult,targettype::DataType)::targettype

Return the field `value` contained in a `FlagSearchResult`. If `targettype`
is not provided, return a `String`. Otherwise, attempt to convert the `String`
value in `sr.value` to type `targettype` using `parse`.

Users would normally use
[`getvalue(vectorwithonesearchresult::AbstractVector{<:FlagSearchResult})`](@ref)
rather than this function.
"""
function getvalue(sr :: FlagSearchResult)
    return getvalues(sr,String)
end

function getvalue(sr :: FlagSearchResult, targettype :: DataType)
    return getvalues(sr,targettype)
end

"""
    getvalue(vecsr::AbstractVector{<:FlagSearchResult})::String
    getvalue(vecsr::AbstractVector{<:FlagSearchResult},targettype::DataType)::targettype

Return the field `value` contained in a `Vector{FlagSearchResult}`. If
`targettype` is not provided, return a `String`. Otherwise, attempt to
convert the `String` value to type `targettype` using `parse`.

This function returns a scalar, and errors out if the vector contains
more than one value. For extracting values from a vector with many elements,
see [`getvalues`](@ref).

# Example
```julia
# \$:julia script.jl -f file1.txt --nbins 80
nbins = 50 # Default value
bincountdata = seekvalsof(ARGS,"--nbins"))
# bincountdata is a `Vector{FlagSearchResult}` of length 2, but only 
#   the second element has a meaningful value (since the first `FlagSearchResult`
#   refers to the flag "--nbins", and only 1 value was passed
#   after it; hence `countvalues(bincountdata)==1`)
if countvalues(bincountdata) == 1
    nbins = getvalue(bincountdata,Int)
elseif countvalues(bincountdata) > 1
    error("You can pass a maximum of one bincount value!")
end
println(nbins) # Prints 80; nbins is an `Int`
```
"""
function getvalue(vectorwithonesearchresult :: AbstractVector{<:FlagSearchResult})
    return getvalue(vectorwithonesearchresult,String)
end
function getvalue(vectorwithonesearchresult :: AbstractVector{<:FlagSearchResult}, targettype :: DataType)
    vw1sr_noflag = filter( sr -> !startswith(getfield(sr,:value), '-'), vectorwithonesearchresult)
    if length(vw1sr_noflag) != 1
        nep = min(length(vw1sr_noflag),5) # n(elements to print)
        error("You passed a vector with $(length(vw1sr_noflag)) values to getvalue. This function only accepts vectors of length 1.\nHere's the first $nep elements:\n$(join(vw1sr_noflag,'\n'))")
    else
        return only(getvalues(vw1sr_noflag,targettype))
    end
end

"""
    getvalues(sr::FlagSearchResult)::String
    getvalues(sr::FlagSearchResult,targettype::DataType)::targettype

Return the field `value` contained in the `FlagSearchResult` of a value argument
from `ARGS`; if this `FlagSearchResult` corresponds to a flag, return an empty
string. If `targettype` is not provided, return a `String`.
Otherwise, attempt to convert the `String` value to type `targettype`
using `parse`.

Users would normally use
[`getvalues(srs::AbstractVector{<:FlagSearchResult})`](@ref)
or
[`getvalues(srs::AbstractVector{<:FlagSearchResult},targettype::DataType)`](@ref)
rather than this function.
"""
function getvalues(sr :: FlagSearchResult)
    if startswith(sr.value,'-')
        # In the context of the flag-value dichotomy,
        #   FlagSearchResult for flags have no value,
        #   so we return an empty string
        return ""
    else
        return sr.value # Return the string directly; no conversion was requested
    end
end

function getvalues(sr :: FlagSearchResult, targettype :: DataType)
    if startswith(sr.value,'-')
        return ""
    else
        return maybeparse(targettype, sr.value)
    end
end

"""
    getvalues(srs::AbstractVector{<:FlagSearchResult})::Vector{String}
    getvalues(srs::AbstractVector{<:FlagSearchResult},targettype::DataType)::Vector{targettype}

Return a vector with the fields `value` from a vector of `FlagSearchResult`s.
If `targettype` is not provided, return a `Vector{String}`.
Otherwise, attempt to convert the `String` values to type `targettype`
using `parse`.

# Examples
```julia
# \$:julia script.jl -f file1.txt file2.txt --nbins 80
filenamedata = seekvalsof(ARGS,"-f"))
# filenamedata is a `Vector{FlagSearchResult}` with 3 elements (one for
#   the "-f", two for the values that go after)
filenames = getvalues(filenamesdata)
println(filenames == ["file1.txt", "file2.txt"]) # Prints `true`
```

```julia
# \$:julia script.jl -f file1.txt file2.txt --temperature 200 500
temperaturedata = seekvalsof(ARGS,"--temperature"))
temperatures = getvalues(temperaturedata,Float64)
println(temperatures == [200.0,500.0]) # Prints `true`
```
"""
function getvalues(srs :: AbstractVector{<:FlagSearchResult})
    srs_noflag = filter( sr -> !startswith(getfield(sr,:value), '-'), srs)
    return getfield.(srs_noflag,:value)
end

function getvalues(srs :: AbstractVector{<:FlagSearchResult}, targettype :: DataType)
    srs_noflag = filter( sr -> !startswith(getfield(sr,:value), '-'), srs)
    return maybeparse.(targettype, getfield.(srs_noflag,:value) )
end

"""
    countvalues(srs::AbstractVector{<:FlagSearchResult})::Int

Counts the amount of elements in a `Vector{FlagSearchResult}` that hold
a value (so, the flags are discarded). Use this instead of `length`, since
that'll include elements derived from, say, "--file", "-f", and such.

```julia
# \$:julia script.jl -f file1.txt file2.txt --nbins 80 --file file3.txt
filenamedata = FlagSearchResult[]
append!(filenamedata, seekvalsof(ARGS,"-f"))
append!(filenamedata, seekvalsof(ARGS,"--file"))
println(countvalues(filenamedata)) # prints 3, since 3 files were listed
println(length(filenamedata)) # prints 5, since the vector has 5 elements
                              #   (3 values+2 flags; we care about
                              #   the amount of values rather than the 
                              #   values+flags count)
```
"""
function countvalues(srs :: AbstractVector{<:FlagSearchResult})
    srs_noflag = filter( sr -> !startswith(getfield(sr,:value), '-'), srs)
    return length(getfield.(srs_noflag,:value))
end

"""
    gettoken(parsedargs::ParsedArguments,thisarg::Integer,thistoken::Integer)::String
    gettoken(args::AbstractVector{<:AbstractString},thisarg::Integer,thistoken::Integer)::String

Internal-use function. Fetch a specific 'token' from an argument. Stringflags and
values only have one token (themselves) while charflag clusters have several
tokens.

# Examples
```jldoctest
julia> gettoken(["--verbose", "-f", "file1.txt", "-lthr"],2,1)
"-f"
```

```jldoctest
julia> gettoken(["--verbose", "-f", "file1.txt", "-lthr"],3,1)
"file1.txt"
```

```jldoctest
julia> gettoken(["--verbose", "-f", "file1.txt", "-lthr"],4,1)
"-l"
```

```jldoctest
julia> gettoken(["--verbose", "-f", "file1.txt", "-lthr"],4,2)
"-t"
```
"""
function gettoken(parsedargs :: ParsedArguments, thisarg :: Integer, thistoken :: Integer)
    return gettoken(parsedargs.args, thisarg, thistoken)
end

function gettoken(args :: AbstractVector{<:AbstractString}, thisarg :: Integer, thistoken :: Integer)
    thearg = args[thisarg]
    if isstringflag(thearg) || isvalue(thearg)
        if thistoken == 1
            return thearg
        else
            if isstringflag(thearg)
                error("You requested token $thistoken from \"$thearg\" (it's a string-flag, so it only has 1 token).")
            else
                error("You requested token $thistoken from \"$thearg\" (it's a value, so it only has 1 token).")
            end
        end
    else#if ischarflag(thearg)
        ntokens = length(thearg) - 1
        if thistoken > ntokens
            error("You requested token $thistoken from \"$thearg\", but it only has $ntokens tokens.")
        end
        # If the token is 't', this line returns "-t"
        return '-'*thearg[thistoken+1]
    end
end

"""
    ischarflag(arg::AbstractString)::Bool

Return `true` for elements of `ARGS` that are charflags (they start with
a dash), rather than values (don't start with a dash) or stringflags
(start with 2 dashes).

# Examples
```jldoctest
julia> ischarflag("file1.txt")
false
julia> ischarflag("50")
false
julia> ischarflag("-f")
true
julia> ischarflag("--file")
false
```
"""
function ischarflag(instring :: AbstractString)
    if startswith(instring,"--")
        return false
    elseif startswith(instring,"-")
        return true
    else
        return false
    end
end

"""
    isstringflag(arg::AbstractString)::Bool

Return `true` for elements of `ARGS` that are stringflags (they start with
2 dashes), rather than values (don't start with a dash) or charflags
(start with 1 dash).

# Examples
```jldoctest
julia> isstringflag("file1.txt")
false
julia> isstringflag("50")
false
julia> isstringflag("-f")
false
julia> isstringflag("--file")
true
```
"""
function isstringflag(instring :: AbstractString)
    if startswith(instring,"--")
        return true
    else#if startswith(instring,"-") # Return false for charflags and values
        return false
    end
end

"""
    isvalue(arg::AbstractString)::Bool

Return `true` for elements of `ARGS` that are values (these don't start
with a dash), rather than charflags (start with 1 dash) or stringflags
(start with 2 dashes).

# Examples
```jldoctest
julia> isvalue("file1.txt")
true
julia> isvalue("50")
true
julia> isvalue("-f")
false
julia> isvalue("--file")
false
```
"""
function isvalue(instring :: AbstractString)
    if startswith(instring,"-")
        return false
    else
        return true
    end
end

"""
    parseargs(args::AbstractVector{<:AbstractString})

Takes a `Vector{String}` and returns a [`ParsedArguments`](@ref).
This `struct` is mostly used for checking for the presence of
toggles in `ARGS`.

See [`ParsedArguments`](@ref) for examples.
"""
function parseargs(args :: AbstractVector{<:AbstractString})
    nargs = length(args)
    logargs = falses(nargs) # Keeps track of which args have been parsed (once parsed, their value is true)

    strings = String[]
    chars = String[]
    vals = String[]

    # If an argument starts with "--", drop the "--" and copy the remaining string to `strings'
    for i in 1:nargs
        if startswith(args[i],"--")
            push!(strings, args[i])
            logargs[i] = true
        end
    end

    # If an argument starts with "-", and it's not part of strings, drop the "-" and copy the remaining chars in the string to `chars'
    for i in 1:nargs
        thisarg = args[i]
        if startswith(thisarg,"-") && !logargs[i]
            for char in thisarg[2:end]
                push!(chars, '-'*char)
            end
            logargs[i] = true
        end
    end

    # All args that start neither with "--" or "-" are appended to vals
    for i in 1:nargs
        if !logargs[i]
            push!(vals, args[i])
        end
    end

    return ParsedArguments(
               strings,
               chars,
               vals,
               args
           )
end

"""
    checkmutualexclusivity(args::AbstractVector{<:AbstractString},explanation::AbstractString,meflags::AbstractString...)
    checkmutualexclusivity(parsedargs::ParsedArguments,explanation::AbstractString,meflags::AbstractString...)

Check if an `ARGS` list has two or more flags from a mutually-exclusive set.
Error out and print `explanation` if it does; otherwise return `nothing`.

# Example
```julia
# \$:julia script.jl --mode1 file.txt --quiet --mode2
ex = "Flags -0 and --mode1 and --mode2 are mutually exclusive!"
checkmutualexclusivity(ARGS, ex, "-0", "--mode1", "--mode2") # <- errors out because --mode1 and --mode2 were requested
```
"""
function checkmutualexclusivity(args :: AbstractVector{<:AbstractString}, explanation :: AbstractString, meflags :: AbstractString...)
    return checkmutualexclusivity(parseargs(args), explanation, meflags...)
end

function checkmutualexclusivity(parsedargs :: ParsedArguments, explanation :: AbstractString, meflags :: AbstractString...)
    # meflags: mutually exclusive flags
    nflags = length(meflags)
    if nflags == 1
        return nothing
    end

    # If we have at least 2 flags, count how many of these appear in args and
    #   error out if there's more than 1 (0 is allowed)
    nfoundflags = 0
    for i in 1:nflags
        thismef = meflags[i]
        if startswith(thismef,"--") # For flags like --verbose
            if thismef in parsedargs.strings
                nfoundflags += 1
            end
        else # For flags like -v
            if thismef in parsedargs.chars
                nfoundflags += 1
            end
        end
    end

    if nfoundflags <= 1
        return nothing
    else
        error(explanation)
    end
end

"""
    checkgroupexclusivity(args::AbstractVector{<:AbstractString},explanation::AbstractString,groups::AbstractVector{<:AbstractString}...)
    checkgroupexclusivity(parsedargs::ParsedArguments,explanation::AbstractString,groups::AbstractVector{<:AbstractString}...)

Check if an `ARGS` list has flags from two or more mutually-exclusive sets
Error out and print `explanation` if it does (this means a flag collision has
occured); otherwise return `nothing`.

Allows for comparing between mutually-exclusive behaviors rather than flags,
such as a quiet mode and a verbose mode.

# Example
```julia
# The next three program calls pass the `checkgroupexclusivity` below:
# \$:julia script.jl -q file.txt
# \$:julia script.jl file.txt -v
# \$:julia script.jl file.txt --quiet
# The next three program calls error out in the `checkgroupexclusivity` call:
# \$:julia script.jl -q file.txt -v
# \$:julia script.jl --verbose file.txt -q
# \$:julia script.jl -vq file.txt

ex = "Modes `quiet' and `verbose' are incompatible!"
checkgroupexclusivity(ARGS, ex, ["-q","--quiet"], ["-v","--verbose"])
```
"""
function checkgroupexclusivity(args :: AbstractVector{<:AbstractString}, explanation :: AbstractString, groups :: AbstractVector{<:AbstractString}...)
    return checkgroupexclusivity(parseargs(args), explanation, groups...)
end

function checkgroupexclusivity(parsedargs :: ParsedArguments, explanation :: AbstractString, groups :: AbstractVector{<:AbstractString}...)
    # meflags: mutually exclusive flags
    ngroups = length(groups)
    if ngroups == 1
        return nothing
    end
    logappearance = zeros(Int,ngroups)

    # If we have at least 2 groups, count how many flags of each group appear in args.
    #   Error out if at least 2 groups have their flags in args
    #   or return nothing if 0 or 1 of the groups have their flags in args
    #   (the fact that this function doesn't error out conveys the values in args look fine)
    for i in 1:ngroups
        # n(flags in group)
        nfig = length(groups[i])

        for j in 1:nfig
            thisflag = groups[i][j]
            if startswith(thisflag,"--") # For flags like --verbose
                if thisflag in parsedargs.strings
                    logappearance[i] += 1
                end
            else # For flags like -v
                if thisflag in parsedargs.chars
                    logappearance[i] += 1
                end
            end
        end
    end

    ngroupsfeatured = 0
    for i in 1:ngroups
        if logappearance[i] > 0
            ngroupsfeatured += 1
        end
    end
    if ngroupsfeatured <= 1
        return nothing
    else
        error(explanation)
    end
end

"""
    seekflag(parsedargs::ParsedArguments,flag::AbstractString)::Vector{FlagSearchResult}
    seekflag(args::AbstractVector{<:AbstractString},flag::AbstractString)::Vector{FlagSearchResult}

Detect if a given flag exists in `ARGS`. Mostly used for detecting toggles.

See also [`seekvalsof`](@ref).

# Example
```julia
modehelp = false
helpdata = FlagSearchResult[]
append!(helpdata, seekflag(ARGS,"-h"))
append!(helpdata, seekflag(ARGS,"--help"))

if !isempty(helpdata)
    modehelp = true
end
```
"""
function seekflag(parsedargs :: ParsedArguments, flag :: AbstractString)
    return seekflag(parsedargs.args, flag)
end

function seekflag(args :: AbstractVector{<:AbstractString}, flag :: AbstractString)
    isflagcf = ischarflag(flag)
    if isflagcf && length(flag) != 2
        error("seekflag only accepts charflags with two chars in total. So \"-v\" and \"--verbose\" are allowed, but \"-verbose\" is not.\nThe strings within args can have char-clusters like \"-lthr\", but the function seekflag can only search for individual flags (such as \"-v\" or \"--verbose\").")
    end

    searchresults = FlagSearchResult[]
    nargs = length(args)
    for i in 1:nargs
        # If the requested flag AND args[i] are charflags,
        #   compare the flag's non-char flag. Otherwise, do
        #   direct string-comparison
        if isflagcf && ischarflag(args[i])
            # Start with 2; skip the dash at position 1
            nchars = length(args[i])
            for j in 2:nchars
                if flag[2] == args[i][j]
                    # Note the j-1 below, since the dash in, say, "-lthr" isn't counted;
                    #   the 'l' is considered to be token 1, and the
                    #   entire char-cluster has 4 tokens rather than 5
                    push!(searchresults, FlagSearchResult(i,j-1,flag))
                end
            end
        else
            if args[i] == flag
                push!(searchresults, FlagSearchResult(i,1,args[i]))
            end
        end
    end
    return searchresults
end

"""
    seekvalsof(parsedargs::ParsedArguments,flag::AbstractString)::Vector{FlagSearchResult}
    seekvalsof(args::AbstractVector{<:AbstractString},flag::AbstractString)::Vector{FlagSearchResult}

If `flag` doesn't exist in `ARGS`, return an empty `Vector{FlagSearchResult}`.
Otherwise, return a `Vector{FlagSearchResult}` with the flag and any subsequent
values. They can be extracted and converted using [`getvalues`](@ref).

See also [`seekflag`](@ref).

# Example
```julia
filenamesdata = FlagSearchResult[]
append!(filenamesdata, seekvalsof(ARGS,"-f"))
append!(filenamesdata, seekvalsof(ARGS,"--file"))

if countvalues(filenamesdata) == 0
    error("Pass a nonzero amount of filenames to analyze.")
else
    filenames = getvalues(filenamesdata)
    # Here you can check that all the requested filenames exist
end
```
"""
function seekvalsof(parsedargs :: ParsedArguments, flag :: AbstractString)
    return seekvalsof(parsedargs.args, flag)
end

function seekvalsof(args :: AbstractVector{<:AbstractString}, flag :: AbstractString)
    # This function is only meant to be called for flags that take vals
    # Therefore, if the user passes a charflag, this block checks that this
    #   charflag isn't in a cluster
    if length(flag) == 2 && startswith(flag,'-')
        if flag == "--"
            error("Invalid flag passed: \"--\"")
        end
        for arg in args
            # If an arg is a char-flag cluster, AND the flag we're looking
            #   is in the cluster, error out. Acceptors are forbidden from being in char-flag clusters
            if ischarflag(arg) && length(arg) > 2 && flag[2] in arg
                error("The value-taking char-flag \"$flag\" is part of a cluster: \"$arg\" . Write it outside the cluster.")
            end
        end
    end

    # If we reach this point, then it's certain that charflags aren't written in clusters,
    #   while string-flags are always written separately
    nargs = length(args)
    searchresults = FlagSearchResult[]
    foundtheflag = false
    for i in 1:nargs
        if args[i] == flag
            foundtheflag = true
            push!(searchresults, FlagSearchResult(i,1,flag))
            continue
        end
        if foundtheflag
            if isvalue(args[i])
                push!(searchresults, FlagSearchResult(i,1,args[i]))
            else
                # If we reach the next flag, stop appending strings to searchresults
                break
            end
        end
    end

    return searchresults
end

"""
    findunclaimedtokens(parsedargs::ParsedArguments,searchresults::AbstractVector{<:FlagSearchResult})::Vector{FlagSearchResult}
    findunclaimedtokens(args::AbstractVector{<:AbstractString},searchresults::AbstractVector{<:FlagSearchResult})::Vector{FlagSearchResult}

Scan all the args in `ARGS` using the claimed-tokens list `searchresults`,
and return a `Vector{FlagSearchResult}` with any stringflag or charflag
or value in `ARGS` not listed in `searchresults`.

Using this function requires saving the output of all [`seekflag`](@ref) and
[`seekvalsof`](@ref) calls, and lets you detect any stray/typo flag in the
user's input.

# Example
```
struct MyProgramBehavior
    filenames :: Vector{String}
    modehelp :: Bool
end

function loadMyProgramBehavior(args :: AbstractVector{<:AbstractString})
    # Set default values
    modehelp = false

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

    # Parse the requested filenames
    filenamesdata = FlagSearchResult[]
    append!(filenamesdata, seekvalsof(args,"-f"))
    append!(filenamesdata, seekvalsof(args,"--file"))

    if countvalues(filenamesdata) == 0 && !modehelp
        error("Pass a nonzero amount of filenames to analyze.")
    else
        filenames = getvalues(filenamesdata)
        # Here you can check that all the requested filenames exist
    end

    # Bookkeeping for stray-token detection
    append!(claimedtokens, filenamesdata)

    # Final bookkeeping step
    unclaimed = findunclaimedtokens(args,claimedtokens)
    if !isempty(unclaimed)
        error("Error in ARGS! You passed some stray options. Run \\n  \$:julia myprogram.jl -h\\nto see the valid options.\\n\\n== Stray tokens:\\n"*join(writetokens(args,unclaimed),'\\n'))
    end

    return MyProgramBehavior(filenames,modehelp)
end
```
"""
function findunclaimedtokens(parsedargs :: ParsedArguments, searchresults :: AbstractVector{<:FlagSearchResult})
    return findunclaimedtokens(parsedargs.args, searchresults)
end

function findunclaimedtokens(args :: AbstractVector{<:AbstractString}, searchresults :: AbstractVector{<:FlagSearchResult})
    nargs = length(args)
    # ntokens per arg (the amount of tokens in every string in args)
    ntokens_pa = Array{Int}(undef,nargs)
    for i in 1:nargs
        # String-flags and values have just 1 token;
        #   char-flags have as many tokens as they have chars (not counting the dash at the beginning)
        if isstringflag(args[i]) || isvalue(args[i])
            ntokens_pa[i] = 1
        else
            ntokens_pa[i] = length(args[i]) - 1
        end
    end

    # The data on which tokens in args were claimed
    claimeddata = Array{BitVector}(undef,nargs)
    for i in 1:nargs
        claimeddata[i] = falses(ntokens_pa[i])
        # If any searchresult has the same whicharg value as i,
        #   then use its whichtoken value to mark a bit from
        #   claimeddata[i] as true
        for sr in searchresults
            if sr.whicharg == i
                claimeddata[i][sr.whichtoken] = true
            end
        end
    end

    # Now collect any false bit in claimeddata.
    #   Those are the values to return
    # Hence, if the returned vector has nonzero length, there are
    #   unclaimed tokens. They will be given energy drinks
    #   and taught to swear.
    unclaimedtokens = FlagSearchResult[]
    unclaimedtoken = FlagSearchResult(0,0,"") # Silly init for scoping reasons
    for i in 1:nargs
        for j in 1:ntokens_pa[i]
            if !claimeddata[i][j]
                # Find the searchresult value that corresponds to this unclaimed token
                tokenofarg = gettoken(args,i,j)
                push!(unclaimedtokens, FlagSearchResult(i,j,tokenofarg))
            end
        end
    end

    return unclaimedtokens
end

"""
    writetokens(parsedargs::ParsedArguments,tokens::AbstractVector{<:FlagSearchResult})
    writetokens(args::AbstractVector{<:AbstractString},tokens::AbstractVector{<:FlagSearchResult})

Mostly used to print any stray flags detected by [`findunclaimedtokens`](@ref).

Format `tokens`, a list of `Vector{FlagSearchResult}` as a `Vector{String}`
and return the string vector. These tokens can be printed as in
`println(join(writetokens(args,unclaimed),'\n'))`
where
`unclaimed = findunclaimedtokens(args,claimedtokens)`.

See [`findunclaimedtokens`](@ref) for a complete example of an
argument-parsing function.
"""
function writetokens(parsedargs :: ParsedArguments, tokens :: AbstractVector{<:FlagSearchResult})
    return writetokens(parsedargs.args, tokens)
end

function writetokens(args :: AbstractVector{<:AbstractString}, tokens :: AbstractVector{<:FlagSearchResult})
    output = String[]
    linetoken = ""
    ntokens = length(tokens)
    for i in 1:ntokens
        token = tokens[i]
        if i < ntokens
            linetoken = "Word $(token.whicharg) token $(token.whichtoken): $(token.value)\n"
        else
            linetoken = "Word $(token.whicharg) token $(token.whichtoken): $(token.value)"
        end
        push!(output, linetoken)
    end
    return output
end
