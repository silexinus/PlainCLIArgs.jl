using Test
using PlainCLIArgs: FlagSearchResult, parseargs,
                    seekNvaluesof, seekNvalsof, seekvaluesof,
                    findunclaimedtokens, countvalues, getvalue, getvalues

const FSR = FlagSearchResult

@testset "seekNvaluesof" begin
    @testset "takes exactly N values and leaves the rest" begin
        args = ["-f", "a", "b", "c"]
        @test seekNvaluesof(args, "-f", 2) == [FSR(1,1,"-f"), FSR(2,1,"a"), FSR(3,1,"b")]
        @test length(seekvaluesof(args, "-f")) == 4   # contrast: seekvaluesof is greedy
    end

    @testset "values before the flag are not taken" begin
        args = ["points1.dat", "--temp", "300"]
        @test seekNvaluesof(args, "--temp", 1) == [FSR(2,1,"--temp"), FSR(3,1,"300")]
        args = ["--temp", "300", "points1.dat"]
        @test seekNvaluesof(args, "--temp", 1) == [FSR(1,1,"--temp"), FSR(2,1,"300")]
    end

    @testset "fewer values than requested" begin
        # Stops at the next flag; the caller detects the shortfall with countvalues
        r = seekNvaluesof(["--range", "5", "-f", "x.dat"], "--range", 2)
        @test r == [FSR(1,1,"--range"), FSR(2,1,"5")]
        @test countvalues(r) == 1
        # Flag with no value at all (last arg)
        @test countvalues(seekNvaluesof(["-t"], "-t", 1)) == 0
    end

    @testset "absent flag" begin
        @test isempty(seekNvaluesof(["a.dat"], "-t", 1))
        @test isempty(seekNvaluesof(String[], "--temp", 1))
    end

    @testset "dash-leading tokens are flags, never values" begin
        # This is why negative numbers need a dash-free spelling (axiom 1)
        # In this test, the -5 is assumed to be a flag, so --range has no values after it
        @test seekNvaluesof(["--range", "-5", "5"], "--range", 2) == [FSR(1,1,"--range")]
    end

    @testset "value-taking charflags can't be clustered" begin
        @test_throws ErrorException seekNvaluesof(["-qt", "300"], "-t", 1)
    end

    @testset "ParsedArguments method and alias agree with the AbstractVector method" begin
        args = ["--temp", "300", "points1.dat", "-q"]
        expected = seekNvaluesof(args, "--temp", 1)
        @test seekNvaluesof(parseargs(args), "--temp", 1) == expected
        @test seekNvalsof(args, "--temp", 1) == expected
    end

    @testset "leftover-value pattern from the docstring" begin
        args = ["--temp", "300", "points1.dat"]
        unclaimed = findunclaimedtokens(args, seekNvaluesof(args, "--temp", 1))
        @test getvalue(unclaimed) == "points1.dat"

        # Pitfall: a stray flag does NOT change countvalues(unclaimed),
        #   so `countvalues(unclaimed) != 1` alone misses typo flags (in this example, -z)
        args = ["--temp", "300", "points1.dat", "-z"]
        unclaimed = findunclaimedtokens(args, seekNvaluesof(args, "--temp", 1))
        @test countvalues(unclaimed) == 1
        @test length(unclaimed) == 2
    end

    @testset "nseek must be positive" begin
        # Well it could be zero, but come on. Use seekflag for that instead
        @test_throws ErrorException seekNvaluesof(["-t", "1"], "-t", 0)
        @test_throws ErrorException seekNvaluesof(["-t", "1"], "-t", -1)
    end

    @testset "nseek is a shared budget across repeated flags" begin
        args = split("-t a b -t c")   # Vector{SubString{String}}
        found = seekNvaluesof(args, "-t", 3)
        @test found == [FSR(1,1,"-t"), FSR(2,1,"a"), FSR(3,1,"b"),
                        FSR(4,1,"-t"), FSR(5,1,"c")]
        @test countvalues(found) == 3
        @test getvalues(found) == ["a", "b", "c"]

        # The budget runs out before the second -t, so it's not collected
        @test seekNvaluesof(args, "-t", 2) == [FSR(1,1,"-t"), FSR(2,1,"a"), FSR(3,1,"b")]
    end
end
