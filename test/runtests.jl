using PlainCLIArgs
using Test

@testset "PlainCLIArgs.jl" begin
    @test PlainCLIArgs.parseargs(["-f", "file1.txt", "-q", "--quiet"]) == PlainCLIArgs.ParsedArguments(["--quiet"], ["-f", "-q"], ["file1.txt"], ["-f", "file1.txt", "-q", "--quiet"])
    @test PlainCLIArgs.parseargs(["-lthr"]) == PlainCLIArgs.ParsedArguments(String[], ["-l", "-t", "-h", "-r"], String[], ["-lthr"])
    @test PlainCLIArgs.seekflag(["-f", "file1.txt", "-q", "--quiet"], "-q") == [PlainCLIArgs.FlagSearchResult(3, 1, "-q")]
    @test PlainCLIArgs.checkmutualexclusivity(["--mode1", "file.txt", "--quiet"], "Modes -0 and --mode1 and --mode2 are mutually exclusive!", "-0", "--mode1", "--mode2") == nothing
end
