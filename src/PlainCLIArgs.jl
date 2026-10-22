module PlainCLIArgs

export ParsedArguments, FlagSearchResult,
       parseargs, seekflag, seekNvaluesof, seekvaluesof, seekallvalues,
       checkmutualexclusivity, checkgroupexclusivity,
       findunclaimedtokens, writetokens,
       isvalue, getvalue, getvalues,
       countvalues,
       # Now the aliases
       seekvalsof, seekNvalsof, seekallvals,
       isval, getval, getvals,
       countvals

include("functions.jl")

end
