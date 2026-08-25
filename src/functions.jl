
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

function getvalue(sr :: FlagSearchResult)
    return getvalues(sr)
end

function getvalue(vectorwithonesearchresult :: AbstractVector{<:FlagSearchResult})
    vw1sr_noflag = filter( sr -> !startswith(getfield(sr,:value), '-'), vectorwithonesearchresult)
    if length(vw1sr_noflag) != 1
        nep = min(length(vw1sr_noflag),5) # n(elements to print)
        error("You passed a vector with $(length(vw1sr_noflag)) values to getvalue. This function only accepts vectors of length 1.\nHere's the first $nep elements:\n$(join(vw1sr_noflag,'\n'))")
    else
        return only(getvalues(vw1sr_noflag))
    end
end

# Return an empty string if sr is a flag. Its struct's value field is nonempty,
#   but in the context of the flag-value dichotomy, FlagSearchResult for flags
#   have no value
function getvalues(sr :: FlagSearchResult)
    if startswith(sr.value,'-')
        return ""
    else
        return sr.value
    end
end

# Drops any FlagSearchResult struct for a flag, since those don't
#   have a meaningful value (unlike, say, "file1.txt")
function getvalues(srs :: AbstractVector{<:FlagSearchResult})
    srs_noflag = filter( sr -> !startswith(getfield(sr,:value), '-'), srs)
    return getfield.(srs_noflag,:value)
end

function countvalues(srs :: AbstractVector{<:FlagSearchResult})
    srs_noflag = filter( sr -> !startswith(getfield(sr,:value), '-'), srs)
    return length(getfield.(srs_noflag,:value))
end

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

function ischarflag(instring :: AbstractString)
    if startswith(instring,"--")
        return false
    elseif startswith(instring,"-")
        return true
    else
        return false
    end
end

function isstringflag(instring :: AbstractString)
    if startswith(instring,"--")
        return true
    else#if startswith(instring,"-") # Return false for charflags and values
        return false
    end
end

function isvalue(instring :: AbstractString)
    if startswith(instring,"-")
        return false
    else
        return true
    end
end

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
                    # Note the j-1 below, since the dash in, say, "-lthr" isn't counted
                    #   so in that example, the 'l' is considered to be token 1, and the
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
