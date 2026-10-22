using Test
using PlainCLIArgs: FlagSearchResult, parseargs,
                    seekNvaluesof, seekNvalsof, seekvaluesof,
                    findunclaimedtokens, countvalues, getvalue, getvalues

const FSR = FlagSearchResult

@testset "getvalue/getvalues: scalar and vector forms agree for every replacedata form" begin
    sr  = FSR(2,1,"min5")
    vec = [FSR(1,1,"--n"), sr]

    @test getvalue(sr) == getvalue(vec) == "min5"
    @test getvalue(sr, String) == getvalue(vec, String) == "min5"

    # Single Pair, then a vector of Pair
    for rules in (r"^min" => "-", [r"^min" => "-"])
        @test getvalue(sr, rules)       == getvalue(vec, rules)       == "-5"
        @test getvalue(sr, Int, rules)  == getvalue(vec, Int, rules)  == -5
        @test getvalues(sr, rules)      == only(getvalues(vec, rules))      == "-5"
        @test getvalues(sr, Int, rules) == only(getvalues(vec, Int, rules)) == -5
    end
end
