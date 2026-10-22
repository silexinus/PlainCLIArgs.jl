using Test
using PlainCLIArgs: FlagSearchResult, getvalue, getvalues, _onlyvalueresult

const FSR = FlagSearchResult

@testset "getvalues (vector) with replacedata" begin
    srs = [FSR(3,1,"--range"), FSR(4,1,"min5"), FSR(5,1,"5")]
    srs_backup = copy(srs)

    # Regression: "min5" -> "-5" must NOT be dropped as a flag after replacing
    @testset "regex Pair, flags filtered before replacement" begin
        @test getvalues(srs, Float64, r"^min" => "-") == [-5.0, 5.0]
        @test getvalues(srs, Int,     r"^min" => "-") == [-5, 5]
        @test getvalues(srs,          r"^min" => "-") == ["-5", "5"]  # String default
    end

    @testset "plain-string Pair" begin
        @test getvalues(srs, Int, "min" => "-") == [-5, 5]
        @test getvalues(srs, "min" => "-") == ["-5", "5"]
    end

    @testset "anchor ^ only replaces at the beginning" begin
        srs2 = [FSR(1,1,"admin5"), FSR(1,2,"min5")]
        @test getvalues(srs2, r"^min" => "-") == ["admin5", "-5"]
        # Without the anchor, "min" is replaced anywhere:
        @test getvalues(srs2, "min" => "-") == ["ad-5", "-5"]
    end

    @testset "vector of Pairs" begin
        srs3 = [FSR(1,1,"min5"), FSR(1,2,"pls3")]
        pairs = [r"^min" => "-", r"^pls" => "+"]
        @test getvalues(srs3, Int, pairs) == [-5, 3]
        @test getvalues(srs3, pairs) == ["-5", "+3"]
        # Mixed regex / plain-string patterns
        @test getvalues([FSR(1,1,"min1,5")], Float64, [r"^min" => "-", "," => "."]) == [-1.5]
    end

    @testset "edge cases" begin
        # No pattern matches -> values unchanged
        @test getvalues(srs, "zzz" => "y") == ["min5", "5"]
        # Only flags -> nothing left
        @test isempty(getvalues([FSR(1,1,"--a"), FSR(1,2,"-b")], Int, r"^min" => "-"))
        # Real flags are identified on the ORIGINAL values
        @test getvalues([FSR(1,1,"-x"), FSR(1,2,"min2")], Int, r"^min" => "-") == [-2]
        # Input is not mutated
        @test srs == srs_backup
    end

    @testset "unreplaced versions still behave" begin
        @test getvalues(srs) == ["min5", "5"]
        @test getvalues(srs, String) == ["min5", "5"]
        @test getvalues([FSR(1,1,"1"), FSR(1,2,"2")], Float64) == [1.0, 2.0]
    end
end

@testset "getvalue (vector of length 1 after filtering) with replacedata" begin
    one = [FSR(3,1,"--nbins"), FSR(4,1,"min5")]
    one_backup = copy(one)

    @testset "helper" begin
        @test _onlyvalueresult(one) == FSR(4,1,"min5")
        @test_throws ErrorException _onlyvalueresult([FSR(1,1,"--a")])                 # zero values
        @test_throws ErrorException _onlyvalueresult([FSR(1,1,"1"), FSR(1,2,"2")])     # two values
    end

    @testset "Pair" begin
        @test getvalue(one, Float64, r"^min" => "-") == -5.0
        @test getvalue(one, Int,     r"^min" => "-") == -5
        @test getvalue(one,          r"^min" => "-") == "-5"
        @test getvalue(one, Int, "min" => "-") == -5
    end

    @testset "vector of Pairs" begin
        @test getvalue(one, Int, [r"^min" => "-"]) == -5
        @test getvalue(one,      [r"^min" => "-"]) == "-5"
        @test getvalue(one, Int, [r"^min" => "-", r"^pls" => "+"]) == -5
        @test getvalue([FSR(1,1,"pls3")], Int, [r"^min" => "-", r"^pls" => "+"]) == 3
    end

    @testset "error when not exactly one value" begin
        @test_throws ErrorException getvalue([FSR(1,1,"1"), FSR(1,2,"2")], Int, r"^min" => "-")
        @test_throws ErrorException getvalue([FSR(1,1,"--a")], Int, r"^min" => "-")
        @test_throws ErrorException getvalue([FSR(1,1,"min1"), FSR(1,2,"min2")], Int, [r"^min" => "-"])
    end

    @testset "unreplaced versions still behave" begin
        two = [FSR(1,1,"--n"), FSR(2,1,"80")]
        @test getvalue(two) == "80"
        @test getvalue(two, Int) == 80
        @test getvalue(two, Float64) == 80.0
    end

    @test one == one_backup  # input not mutated
end
