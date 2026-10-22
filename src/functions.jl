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
- `values::Vector{String}`: A list of all args that don't start
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
filename = only(parsedargs.values)
```
"""
struct ParsedArguments
    strings :: Vector{String} # Such as "--file", "--verbose", ...
    chars   :: Vector{String} # Such as "-f", "-v", "-q", ... . Note that an input arg "-ab" will get split into "-a" and "-b"
    values  :: Vector{String} # The arguments that don't start with dashes
    args    :: Vector{String} # The full list of arguments
end

function Base.getproperty(pa :: ParsedArguments, fld :: Symbol)
    if fld == :vals
        return getfield(pa,:values)
    else
        return getfield(pa,fld)
    end
end

function Base.:(==)(pa1 :: ParsedArguments, pa2 :: ParsedArguments)
    return pa1.strings == pa2.strings &&
           pa1.chars == pa2.chars &&
           pa1.values == pa2.values &&
           pa1.args == pa2.args
end

function Base.isempty(pa :: ParsedArguments)
    if isempty(pa.args)
        return true
    else
        return false
    end
end

"""
    FlagSearchResult

Return type of the toggle-detector [`seekflag`](@ref) and
the value-fetching [`seekvaluesof`](@ref). Crucial part of
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
bincountdata = seekvaluesof(ARGS,"--nbins")
if countvalues(bincountdata) == 1
    nbins = getvalue(bincountdata,Int)
elseif countvalues(bincountdata) > 1
    error("You can pass a maximum of one bincount value!")
end
# The line below evaluates to `true`
# bincountdata == FlagSearchResult(4,1,"80")
```
"""
struct FlagSearchResult
    whicharg :: Int
    whichtoken :: Int
    value :: String
end

function Base.getproperty(sr :: FlagSearchResult, fld :: Symbol)
    if fld == :val
        return getfield(sr,:value)
    else
        return getfield(sr,fld)
    end
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
    getvalue(sr::FlagSearchResult,replacedata::Pair)::String
    getvalue(sr::FlagSearchResult,vecreplacedata::AbstractVector{<:Pair})::String
    getvalue(sr::FlagSearchResult,targettype::DataType,replacedata::Pair)::targettype
    getvalue(sr::FlagSearchResult,targettype::DataType,vecreplacedata::AbstractVector{<:Pair})::targettype

Return the field `value` contained in a `FlagSearchResult`. If `targettype`
is not provided, return a `String`. Otherwise, attempt to convert the `String`
value in `sr.value` to type `targettype` using `parse`.

This function returns a scalar, and errors out if the vector contains
more than one value. For extracting values from a vector with many elements,
see [`getvalues`](@ref).

If a `Pair` element or vector is passed, the function `replace` is called to
substitute substrings within the extracted values, such as `"min3"` representing
the `Int` value `-3` (this lets you pass negative values via `ARGS` without having
them being treated as flags).

Users would normally use
[`getvalue(vectorwithonesearchresult::AbstractVector{<:FlagSearchResult})`](@ref)
rather than this function.

`getval` is an alias of this function.
"""
function getvalue(sr :: FlagSearchResult)
    return getvalues(sr,String)
end

function getvalue(sr :: FlagSearchResult, targettype :: DataType)
    return getvalues(sr,targettype)
end

function getvalue(sr :: FlagSearchResult, replacedata :: Pair)
    return getvalues(sr,String,replacedata)
end

function getvalue(sr :: FlagSearchResult, vecreplacedata :: AbstractVector{<:Pair})
    return getvalues(sr,String,vecreplacedata)
end

function getvalue(sr :: FlagSearchResult, targettype :: DataType, replacedata :: Pair)
    return getvalues(sr,targettype,replacedata)
end

function getvalue(sr :: FlagSearchResult, targettype :: DataType, vecreplacedata :: AbstractVector{<:Pair})
    return getvalues(sr,targettype,vecreplacedata)
end

function applyreplacedataonvalue(fsr :: FlagSearchResult, replacedata :: Pair)
    return FlagSearchResult(fsr.whicharg, fsr.whichtoken, replace(fsr.value,replacedata) )
end

function applyreplacedataonvalue(fsr :: FlagSearchResult, vecreplacedata :: AbstractVector{<:Pair})
    return FlagSearchResult(fsr.whicharg, fsr.whichtoken, replace(fsr.value,vecreplacedata...) )
end

# Aux fun: drop flags, require exactly one value, and return that single
#   `FlagSearchResult`. Flags are excluded before any substring replacement
#   is done. Otherwise args like "min5" would become "-5", then treated as
#   a flag, and dropped 🫠
function _onlyvalueresult(srs :: AbstractVector{<:FlagSearchResult})
    srs_noflag = filter( sr -> !startswith(getfield(sr,:value), '-'), srs)
    if length(srs_noflag) != 1
        nep = min(length(srs_noflag),5) # n(elements to print)
        error("You passed a vector with $(length(srs_noflag)) values to getvalue. This function only accepts vectors of length 1.\nHere's the first $nep elements:\n$(join(first(srs_noflag,nep),'\n'))")
    end
    return only(srs_noflag)
end

"""
    getvalue(vecsr::AbstractVector{<:FlagSearchResult})::String
    getvalue(vecsr::AbstractVector{<:FlagSearchResult},targettype::DataType)::targettype
    getvalue(vecsr::AbstractVector{<:FlagSearchResult},replacedata::Pair)::String
    getvalue(vecsr::AbstractVector{<:FlagSearchResult},targettype::DataType,replacedata::Pair)::targettype
    getvalue(vecsr::AbstractVector{<:FlagSearchResult},vecreplacedata::AbstractVector{<:Pair})::String
    getvalue(vecsr::AbstractVector{<:FlagSearchResult},targettype::DataType,vecreplacedata::AbstractVector{<:Pair})::targettype

Return the field `value` contained in a `Vector{FlagSearchResult}`. If
`targettype` is not provided, return a `String`. Otherwise, attempt to
convert the `String` value to type `targettype` using `parse`.

If a `Pair` element or vector is passed, the function `replace` is called to
substitute substrings within the extracted values, such as `"min3"` representing
the `Int` value `-3` (this lets you pass negative values via `ARGS` without having
them being treated as flags).

This function returns a scalar, and errors out if the vector contains
more than one value. For extracting values from a vector with many elements,
see [`getvalues`](@ref).

`getval` is an alias of this function.

# Example
```julia
# \$:julia script.jl -f file1.txt --nbins 80
nbins = 50 # Default value
bincountdata = seekvaluesof(ARGS,"--nbins")
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
    return getvalue(vectorwithonesearchresult, String)
end

function getvalue(vectorwithonesearchresult :: AbstractVector{<:FlagSearchResult}, targettype :: DataType)
    sr = _onlyvalueresult(vectorwithonesearchresult)
    return maybeparse(targettype, sr.value)
end

function getvalue(vectorwithonesearchresult :: AbstractVector{<:FlagSearchResult}, replacedata :: Pair)
    return getvalue(vectorwithonesearchresult, String, replacedata)
end

function getvalue(vectorwithonesearchresult :: AbstractVector{<:FlagSearchResult}, targettype :: DataType, replacedata :: Pair)
    sr = _onlyvalueresult(vectorwithonesearchresult)
    return maybeparse(targettype, applyreplacedataonvalue(sr, replacedata).value)
end

function getvalue(vectorwithonesearchresult :: AbstractVector{<:FlagSearchResult}, vecreplacedata :: AbstractVector{<:Pair})
    return getvalue(vectorwithonesearchresult, String, vecreplacedata)
end

function getvalue(vectorwithonesearchresult :: AbstractVector{<:FlagSearchResult}, targettype :: DataType, vecreplacedata :: AbstractVector{<:Pair})
    sr = _onlyvalueresult(vectorwithonesearchresult)
    return maybeparse(targettype, applyreplacedataonvalue(sr, vecreplacedata).value)
end

"""
    getvalues(sr::FlagSearchResult)::String
    getvalues(sr::FlagSearchResult,targettype::DataType)::targettype
    getvalues(sr::FlagSearchResult,replacedata::Pair)::String
    getvalues(sr::FlagSearchResult,vecreplacedata::AbstractVector{<:Pair})::String
    getvalues(sr::FlagSearchResult,targettype::DataType,replacedata::Pair)::targettype
    getvalues(sr::FlagSearchResult,targettype::DataType,vecreplacedata::AbstractVector{<:Pair})::targettype

Return the field `value` contained in the `FlagSearchResult` of a value argument
from `ARGS`; if this `FlagSearchResult` corresponds to a flag, return an empty
string. If `targettype` is not provided, return a `String`.
Otherwise, attempt to convert the `String` value to type `targettype`
using `parse`.

If a `Pair` element or vector is passed, the function `replace` is called to
substitute substrings within the extracted values, such as `"min3"` representing
the `Int` value `-3` (this lets you pass negative values via `ARGS` without having
them being treated as flags).

Users would normally use the versions of `getvalues` that take a `Vector{FlagSearchResult}`
rather than these (the scalar-taking versions).

`getvals` is an alias of this function.
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

function getvalues(sr :: FlagSearchResult, replacedata :: Pair)
    if startswith(sr.value,'-')
        return ""
    else
        return replace(sr.value,replacedata)
    end
end

function getvalues(sr :: FlagSearchResult, vecreplacedata :: AbstractVector{<:Pair})
    if startswith(sr.value,'-')
        return ""
    else
        return replace(sr.value,vecreplacedata...)
    end
end

function getvalues(sr :: FlagSearchResult, targettype :: DataType, replacedata :: Pair)
    if startswith(sr.value,'-')
        return ""
    else
        return maybeparse(targettype, replace(sr.value,replacedata) )
    end
end

function getvalues(sr :: FlagSearchResult, targettype :: DataType, vecreplacedata :: AbstractVector{<:Pair})
    if startswith(sr.value,'-')
        return ""
    else
        return maybeparse(targettype, replace(sr.value,vecreplacedata...) )
    end
end

"""
    getvalues(srs::AbstractVector{<:FlagSearchResult})::Vector{String}
    getvalues(srs::AbstractVector{<:FlagSearchResult},targettype::DataType)::Vector{targettype}
    getvalues(srs::AbstractVector{<:FlagSearchResult},replacedata::Pair)::Vector{String}
    getvalues(srs::AbstractVector{<:FlagSearchResult},vecreplacedata::AbstractVector{<:Pair})::Vector{String}
    getvalues(srs::AbstractVector{<:FlagSearchResult},targettype::DataType,replacedata::Pair)::Vector{targettype}
    getvalues(srs::AbstractVector{<:FlagSearchResult},targettype::DataType,vecreplacedata::AbstractVector{<:Pair})::Vector{targettype}

Return a vector with the fields `value` from a vector of `FlagSearchResult`s.
If `targettype` is not provided, return a `Vector{String}`.
Otherwise, attempt to convert the `String` values to type `targettype`
using `parse`.

If a `Pair` element or vector is passed, the function `replace` is called to
substitute substrings within the extracted values, such as `"min3"` representing
the `Int` value `-3` (this lets you pass negative values via `ARGS` without having
them being treated as flags).

`getvals` is an alias of this function.

# Examples
```julia
# \$:julia script.jl -f file1.txt file2.txt --nbins 80
filenamesdata = seekvaluesof(ARGS,"-f")
# filenamesdata is a `Vector{FlagSearchResult}` with 3 elements (one for
#   the "-f", two for the values that go after)
filenames = getvalues(filenamesdata)
println(filenames == ["file1.txt", "file2.txt"]) # Prints `true`
```

```julia
# \$:julia script.jl -f file1.txt file2.txt --temperature 200 500
temperaturedata = seekvaluesof(ARGS,"--temperature")
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

# Aux fun: discard flags while keeping the values, and THEN apply the
#   replacedata, and finally parse.
# `replacedata` can be a `Pair` or a vector of `Pair`.
function _getvalues_replaced(srs :: AbstractVector{<:FlagSearchResult}, targettype :: DataType, replacedata)
    srs_noflag = filter( sr -> !startswith(getfield(sr,:value), '-'), srs)
    replaced   = applyreplacedataonvalue.(srs_noflag, Ref(replacedata))
    return maybeparse.(targettype, getfield.(replaced,:value) )
end

function getvalues(srs :: AbstractVector{<:FlagSearchResult}, replacedata :: Pair)
    return _getvalues_replaced(srs, String, replacedata)
end

function getvalues(srs :: AbstractVector{<:FlagSearchResult}, targettype :: DataType, replacedata :: Pair)
    return _getvalues_replaced(srs, targettype, replacedata)
end

function getvalues(srs :: AbstractVector{<:FlagSearchResult}, vecreplacedata :: AbstractVector{<:Pair})
    return _getvalues_replaced(srs, String, vecreplacedata)
end

function getvalues(srs :: AbstractVector{<:FlagSearchResult}, targettype :: DataType, vecreplacedata :: AbstractVector{<:Pair})
    return _getvalues_replaced(srs, targettype, vecreplacedata)
end

"""
    getval(arguments...)

Alias for [`getvalue`](@ref).
"""
getval(arguments...) = getvalue(arguments...)

"""
    getvals(arguments...)

Alias for [`getvalues`](@ref).
"""
getvals(arguments...) = getvalues(arguments...)

"""
    countvalues(srs::AbstractVector{<:FlagSearchResult})::Int

Counts the amount of elements in a `Vector{FlagSearchResult}` that hold
a value (so, the flags are discarded). Use this instead of `length`, since
that'll include elements derived from, say, "--file", "-f", and such.

`countvals` is an alias of this function.

```julia
# \$:julia script.jl -f file1.txt file2.txt --nbins 80 --file file3.txt
filenamesdata = FlagSearchResult[]
append!(filenamesdata, seekvaluesof(ARGS,"-f"))
append!(filenamesdata, seekvaluesof(ARGS,"--file"))
println(countvalues(filenamesdata)) # prints 3, since 3 files were listed
println(length(filenamesdata)) # prints 5, since the vector has 5 elements
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
    countvals(arguments...)

Alias for [`countvalues`](@ref).
"""
countvals(arguments...) = countvalues(arguments...)

"""
    gettoken(parsedargs::ParsedArguments,thisarg::Integer,thistoken::Integer)::String
    gettoken(args::AbstractVector{<:AbstractString},thisarg::Integer,thistoken::Integer)::String

Internal-use function. Fetch a specific 'token' from an argument. Values and
stringflags only have one token (themselves) while charflag clusters have several
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

`isval` is an alias of this function.

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
    isval(arguments...)

Alias for [`isvalue`](@ref).
"""
isval(arguments...) = isvalue(arguments...)

"""
    parseargs(args::AbstractVector{<:AbstractString})::ParsedArguments

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
    values = String[]

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

    # All args that start neither with "--" or "-" are appended to values
    for i in 1:nargs
        if !logargs[i]
            push!(values, args[i])
        end
    end

    return ParsedArguments(
               strings,
               chars,
               values,
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

See also [`seekNvaluesof`](@ref), [`seekvaluesof`](@ref), [`seekallvalues`](@ref).

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
    seekNvaluesof(parsedargs::ParsedArguments,flag::AbstractString,nseek::Integer)::Vector{FlagSearchResult}
    seekNvaluesof(args::AbstractVector{<:AbstractString},flag::AbstractString,nseek::Int)::Vector{FlagSearchResult}

If `flag` doesn't exist in `ARGS`, return an empty `Vector{FlagSearchResult}`.
Otherwise, return a `Vector{FlagSearchResult}` with the requested flag plus
a maximum of `nseek` values.
They can be extracted and converted using [`getvalues`](@ref), or counted with
[`countvalues`](@ref).

Note that applying `getvalues` on the output of `seekNvaluesof(args,"-t",2)
picks up both `a` and `b` whether the CLI arguments are `-t a b` or `-t a -f etc -t b`.

This is a variant of [`seekvaluesof`](@ref). Use this if you want to curtail
the amount of values that go with a flag.

`seekNvalsof` is an alias of this function.

See also [`seekflag`](@ref), [`seekallvalues`](@ref).

# Example

Suppose your program always takes one filename and has multiple optional flags,
all of which take a fixed amount of arguments.

In this example, all of these calls are valid, and `points1.dat` is always
detected as the filename since all the argument-taking flags take a fixed
amount of arguments:
```
julia script.jl points1.dat --temp 300
julia script.jl --temp 300 points1.dat
julia script.jl --niter 500 --temp 300 points1.dat
julia script.jl --temp 300 points1.dat --niter 500
```

In that case, this snippet seeks the optional values, if any, and takes the sole
unclaimed value at the end and assumes it's the filename.

```julia
claimedtokens = FlagSearchResult[]

tempdata = FlagSearchResult[]
append!(tempdata, seekNvaluesof(ARGS,"-t",1))
append!(tempdata, seekNvaluesof(ARGS,"--temp",1))
temp = getvalue(tempdata,Float64)

append!(claimedtokens,tempdata) # For detecting unclaimed tokens

niterdata = FlagSearchResult[]
append!(niterdata, seekNvaluesof(ARGS,"-n",1))
append!(niterdata, seekNvaluesof(ARGS,"--niter",1))
niter = getvalue(niterdata,Int)

append!(claimedtokens,niterdata) # For detecting unclaimed tokens

# There should be exactly one unclaimed token containing the filename
unclaimed = findunclaimedtokens(ARGS,claimedtokens)

if countvalues(unclaimed) != 1
    error("It's mandatory that you pass exactly one filename containing a data cloud!")
elseif length(unclaimed) != 1
    error("It's mandatory that you pass exactly one filename containing a data cloud! Or maybe, did you pass a typo flag?")
else
    filename = getvalue(unclaimed)
    # Here you can check that the requested filename exists
end

# Save `temp`, `niter`, `filename` to a struct or Dict here
```
"""
function seekNvaluesof(parsedargs :: ParsedArguments, flag :: AbstractString, nseek :: Integer)
    return seekNvaluesof(parsedargs.args, flag, nseek)
end

function seekNvaluesof(args :: AbstractVector{<:AbstractString}, flag :: AbstractString, nseek :: Integer)
    if nseek < 1
        error("Pass a positive number to seekNvaluesof! You passed $nseek\nIf you want to test if a flag was passed, use seekflag")
    end

    # This function is only meant to be called for flags that take values
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

    # If we reach this point, then it's certain that the requested
    #   value-taking charflag aren't written in clusters, while string-flags
    #   are always written separately
    nargs = length(args)
    searchresults = FlagSearchResult[]
    foundtheflag = false
    for i in 1:nargs
        # This is the only part that differs from seekvaluesof
        # Stop the scan if we have reached the requested amount of values
        if countvalues(searchresults) >= nseek
            return searchresults
        end

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
                foundtheflag = false
            end
        end
    end

    return searchresults
end

"""
    seekNvalsof(arguments...)

Alias for [`seekNvaluesof`](@ref).
"""
seekNvalsof(arguments...) = seekNvaluesof(arguments...)

"""
    seekvaluesof(parsedargs::ParsedArguments,flag::AbstractString)::Vector{FlagSearchResult}
    seekvaluesof(args::AbstractVector{<:AbstractString},flag::AbstractString)::Vector{FlagSearchResult}

If `flag` doesn't exist in `ARGS`, return an empty `Vector{FlagSearchResult}`.
Otherwise, return a `Vector{FlagSearchResult}` with the flag and any subsequent
values. They can be extracted and converted using [`getvalues`](@ref).

`seekvalsof` is an alias of this function.

See also [`seekflag`](@ref), [`seekNvaluesof`](@ref), [`seekallvalues`](@ref).

# Example
```julia
filenamesdata = FlagSearchResult[]
append!(filenamesdata, seekvaluesof(ARGS,"-f"))
append!(filenamesdata, seekvaluesof(ARGS,"--file"))

if countvalues(filenamesdata) == 0
    error("Pass a nonzero amount of filenames to analyze.")
else
    filenames = getvalues(filenamesdata)
    # Here you can check that all the requested filenames exist
end
```
"""
function seekvaluesof(parsedargs :: ParsedArguments, flag :: AbstractString)
    return seekvaluesof(parsedargs.args, flag)
end

function seekvaluesof(args :: AbstractVector{<:AbstractString}, flag :: AbstractString)
    # This function is only meant to be called for flags that take values
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

    # If we reach this point, then it's certain that the requested
    #   value-taking charflag aren't written in clusters, while string-flags
    #   are always written separately
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
                foundtheflag = false
            end
        end
    end

    return searchresults
end

"""
    seekvalsof(arguments...)

Alias for [`seekvaluesof`](@ref).
"""
seekvalsof(arguments...) = seekvaluesof(arguments...)

"""
    seekallvalues(parsedargs::ParsedArguments)::Vector{FlagSearchResult}
    seekallvalues(args::AbstractVector{<:AbstractString})::Vector{FlagSearchResult}

Return all values in `ARGS`. Some uses of this function include: counting
the total amount of values, gathering all values passed to a program that
only takes one type of value (hence, it doesn't need a flag marking the
values).

`seekallvals` is an alias of this function.

See also [`seekflag`](@ref), [`seekNvaluesof`](@ref), [`seekvaluesof`](@ref).

# Example
```
# Example calls:
# \$:julia script.sh -h
# \$:julia script.sh --help
# \$:julia script.sh file1.txt
# \$:julia script.sh file1.txt file2.txt

using PlainCLIArgs

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
    # This program doesn't take a flag like -f or --file to indicate
    #   which values are filenames. Because every value is a filename.
    filenamesdata = seekallvalues(args)

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
        error("Error in ARGS! You passed some stray options. Run \\n  \$:julia myprogram.jl -h\\nto see the valid options.\\n\\n== Stray tokens:\\n"*join(writetokens(args,unclaimed),'\n'))
    end

    return MyProgramBehavior(filenames,modehelp)
end
```
"""
function seekallvalues(args :: AbstractVector{<:AbstractString})
    nargs = length(args)
    searchresults = FlagSearchResult[]
    for i in 1:nargs
        if isvalue(args[i])
            push!(searchresults, FlagSearchResult(i,1,args[i]))
        end
    end

    return searchresults
end

function seekallvalues(parsedargs :: ParsedArguments)
    return seekallvalues(parsedargs.args)
end

"""
    seekallvals(arguments...)

Alias for [`seekallvalues`](@ref).
"""
seekallvals(arguments...) = seekallvalues(arguments...)

"""
    findunclaimedtokens(parsedargs::ParsedArguments,searchresults::AbstractVector{<:FlagSearchResult})::Vector{FlagSearchResult}
    findunclaimedtokens(args::AbstractVector{<:AbstractString},searchresults::AbstractVector{<:FlagSearchResult})::Vector{FlagSearchResult}

Scan all the args in `ARGS` using the claimed-tokens list `searchresults`,
and return a `Vector{FlagSearchResult}` with any stringflag or charflag
or value in `ARGS` not listed in `searchresults`.

Using this function requires saving the output of all [`seekflag`](@ref) and
[`seekvaluesof`](@ref) calls, and lets you detect any stray/typo flag in the
user's input.

# Example
```
# Example calls:
# \$:julia script.sh -h
# \$:julia script.sh --help
# \$:julia script.sh -f file1.txt
# \$:julia script.sh -f file1.txt file2.txt
# \$:julia script.sh --file file1.txt file2.txt

using PlainCLIArgs

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
    append!(filenamesdata, seekvaluesof(args,"-f"))
    append!(filenamesdata, seekvaluesof(args,"--file"))

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
        error("Error in ARGS! You passed some stray options. Run \\n  \$:julia myprogram.jl -h\\nto see the valid options.\\n\\n== Stray tokens:\\n"*join(writetokens(args,unclaimed),'\n'))
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
