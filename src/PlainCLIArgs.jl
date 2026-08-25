module PlainCLIArgs

export ParsedArguments, FlagSearchResult,
       parseargs, seekflag, seekvalsof,
       checkmutualexclusivity, checkgroupexclusivity,
       findunclaimedtokens, writetokens,
       getvalue, getvalues, countvalues

include("functions.jl")

end
