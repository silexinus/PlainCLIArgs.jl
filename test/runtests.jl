using PlainCLIArgs
using Test

@testset "PlainCLIArgs.jl" begin
    @test PlainCLIArgs.parseargs(["-f", "file1.txt", "-q", "--quiet"]) == PlainCLIArgs.ParsedArguments(["--quiet"], ["-f", "-q"], ["file1.txt"], ["-f", "file1.txt", "-q", "--quiet"])
    @test PlainCLIArgs.parseargs(["-lthr"]) == PlainCLIArgs.ParsedArguments(String[], ["-l", "-t", "-h", "-r"], String[], ["-lthr"])
    @test PlainCLIArgs.seekflag(["-f", "file1.txt", "-q", "--quiet"], "-q") == [PlainCLIArgs.FlagSearchResult(3, 1, "-q")]
    @test PlainCLIArgs.checkmutualexclusivity(["--mode1", "file.txt", "--quiet"], "Modes -0 and --mode1 and --mode2 are mutually exclusive!", "-0", "--mode1", "--mode2") == nothing
end

@testset "parseargs" begin
    pa = PlainCLIArgs.parseargs(["-f", "file1.txt", "-qt", "--quiet"])
    @test pa == PlainCLIArgs.ParsedArguments(["--quiet"], ["-f", "-q", "-t"], ["file1.txt"],
                                              ["-f", "file1.txt", "-qt", "--quiet"])
end

@testset "seekflag" begin
    args = ["-f", "file1.txt", "-q", "--quiet"]
    @test PlainCLIArgs.seekflag(args, "-q") == [PlainCLIArgs.FlagSearchResult(3, 1, "-q")]
    @test isempty(PlainCLIArgs.seekflag(args, "-v"))          # absent flag -> empty, not an error

    @test !isempty(PlainCLIArgs.seekflag(["-lthr"], "-t"))     # found inside a cluster
    @test !isempty(PlainCLIArgs.seekflag(["-lthr"], "-h"))
end

@testset "seekvalsof - normal use" begin
    args = ["-f", "file1.txt", "-b", "100"]
    fdata = PlainCLIArgs.seekvalsof(args, "-f")
    @test PlainCLIArgs.getvalue(fdata) == "file1.txt"

    bdata = PlainCLIArgs.seekvalsof(args, "-b")
    @test PlainCLIArgs.countvalues(bdata) == 1
    @test PlainCLIArgs.getvalue(bdata,Int) == 100
    @test parse(Int, PlainCLIArgs.getvalue(bdata)) == 100
end

@testset "seekvalsof - clustering a value-taker is forbidden" begin
    @test_throws ErrorException PlainCLIArgs.seekvalsof(["-qf", "file1.txt"], "-f")
end

@testset "checkgroupexclusivity" begin
    ex = "conflict"
    @test PlainCLIArgs.checkgroupexclusivity(["-q", "file.txt"], ex,
              ["-q","--quiet"], ["-v","--verbose"]) === nothing   # no conflict -> no error
    @test_throws ErrorException PlainCLIArgs.checkgroupexclusivity(["-q", "file.txt", "-v"], ex,
              ["-q","--quiet"], ["-v","--verbose"])                # conflict -> errors
end

@testset "findunclaimedtokens catches a typo" begin
    args = ["-q", "-w", "file.txt"]      # -w is not a real flag anywhere in this program
    claimed = PlainCLIArgs.FlagSearchResult[]
    append!(claimed, PlainCLIArgs.seekflag(args, "-q"))
    unclaimed = PlainCLIArgs.findunclaimedtokens(args, claimed)
    @test !isempty(unclaimed)             # "-w" should show up as unclaimed
end

@testset "seekallvalues - basic extraction" begin
    args = ["-f", "file1.txt", "-q", "file2.txt"]
    result = PlainCLIArgs.seekallvalues(args)
    @test length(result) == 2
    @test PlainCLIArgs.getvalues(result) == ["file1.txt", "file2.txt"]
end

@testset "seekallvalues - no values present" begin
    args = ["-q", "--verbose", "-lthr"]
    result = PlainCLIArgs.seekallvalues(args)
    @test isempty(result)
end

@testset "seekallvalues - all values, no flags" begin
    args = ["file1.txt", "file2.txt", "file3.txt"]
    result = PlainCLIArgs.seekallvalues(args)
    @test PlainCLIArgs.countvalues(result) == 3
    @test PlainCLIArgs.getvalues(result) == args
end

@testset "seekallvalues - ParsedArguments dispatch matches AbstractVector dispatch" begin
    args = ["-f", "file1.txt", "-q", "file2.txt"]
    pa = PlainCLIArgs.parseargs(args)
    @test PlainCLIArgs.seekallvalues(pa) == PlainCLIArgs.seekallvalues(args)
end

@testset "seekallvals is an alias of seekallvalues" begin
    args = ["-f", "file1.txt", "-q", "file2.txt"]
    @test PlainCLIArgs.seekallvals(args) == PlainCLIArgs.seekallvalues(args)
end
