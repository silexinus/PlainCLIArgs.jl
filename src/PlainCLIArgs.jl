module PlainCLIArgs

export ParsedArguments, FlagSearchResult,
       parseargs, seekflag, seekvaluesof, seekallvalues,
       checkmutualexclusivity, checkgroupexclusivity,
       findunclaimedtokens, writetokens,
       isvalue, getvalue, getvalues,
       countvalues,
       # Now the aliases
       seekvalsof, seekallvals,
       isval, getval, getvals,
       countvals

include("functions.jl")

end
