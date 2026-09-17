# PlainCLIArgs

[![Build Status](https://github.com/silexinus/PlainCLIArgs.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/silexinus/PlainCLIArgs.jl/actions/workflows/CI.yml?query=branch%3Amain)

<!-- Because there's more than one way to skin a cat. And maybe you're skinning an octocat, so none of the cat-skinning methods work anyway. -->
<!-- give the user complete freedom to work with the values directly and write the function that fully fits their situation. -->

<p align="center">
<strong>Everything in plain sight. Nothing behind the scenes.</strong>
</p>

`PlainCLIArgs.jl` is an unopinionated package for handling command-line arguments. You can use it to create `struct`s, `Dict`s, or any other type. Its functions are transparent and composable and pure (no side-effects); they handle the tedious low-level processing *and then get out of your way*. This leaves you unimpeded to write a custom argument-reading function that fits the specifics of your problem *using the `julia` you know*, rather than having to learn and remember package-specific rules, work around implicit constraints, or rely on convenient-but-opaque workflows where some of the processing is done behind the scenes.

`PlainCLIArgs.jl` can help you if you're writing a simple program that only needs a few flags, but also if you're working on a complex program with a constantly growing list of options, some of which have default values, others take a variable amount of arguments, others would ideally have multiple ways to call them (say, `-f` and `--file`), oh and there's so many flags a collision detector is warranted (say, `-q` and `--quiet` are incompatible with `-v` and `--verbose`). And there's so many flags, what if the user makes a typo and the program behaves unexpectedly without warning so now you have to make a detector for stray flags and *and* ***and***. `PlainCLIArgs.jl` can help you with all of that too!

`PlainCLIArgs.jl` is formulated over a minuscule set of axioms:
1. Flags start with either one dash (`-v`) or two (`--verbose`). All other strings are considered values.
2. Flags can be
    * toggles (their presence or absence modifies the program's behavior).
    * value-takers (they are followed by values, such as `--file list1.txt list2.txt`).
3. Toggle-flags can be written in a character-cluster: `-q -t` is equivalent to `-qt`.
4. Value-taker flags can't be written in clusters.

That's it. If you're familiar with the way `bash` manages flags you're also familiar with axioms 1–3; the only surprise is point 4.

# Examples of features

This section shows a few examples of the package's functions in action. In a real-world use-case, you'd include these snippets in an argument-parsing function. There are two example functions at the end of this page.

## Checking for mutual exclusivity

Suppose your program has two main modes, toggled by `--mode1` and `--mode2`, and a "delete checkpoints" mode toggled by `-0`. Only one of these modes can be run at a time, so you use `checkmutualexclusivity`: it will error out if any two of these modes are requested; otherwise it returns `nothing`:

```
# $:julia script.jl --mode1 file.txt --quiet --mode2
ex = "Flags -0 and --mode1 and --mode2 are mutually exclusive!"
checkmutualexclusivity(ARGS, ex, "-0", "--mode1", "--mode2")
```
where `ARGS` is what `julia` calls the string-vector containing the command-line arguments, `ex` is an explanation on why these modes are incompatible, and the next two, three, or however many arguments, are the mutually-exclusive flags.

## Checking for group exclusivity

What if you want to offer char-flags and string-flags that toggle the same behavior, the way real `bash` programs do? For example, the flags `-v` and `--verbose` and `-q` and `--quiet`. You can certainly define them, and then use `checkgroupexclusivity` to stop execution if the user requests options from different 'groups', such as `--verbose` and `-q`:

```
# The next three calls are valid:
# $:julia script.jl -q file.txt
# $:julia script.jl file.txt -v
# $:julia script.jl file.txt --quiet
# The next three lines make checkgroupexclusivity error out:
# $:julia script.jl -q file.txt -v
# $:julia script.jl --verbose file.txt -q
# $:julia script.jl -vq file.txt

ex = "Modes `quiet' and `verbose' are incompatible!"
checkgroupexclusivity(ARGS, ex, ["-q","--quiet"], ["-v","--verbose"])
```
once again, `ex` is an explanation on why these modes are incompatible, and the next two, three, or however many vectors go after, are the groups with mutually-exclusive flags.

## Fetching toggles from `ARGS`

Suppose your program has quiet and verbose modes. Here's some example calls where the user explicitly requests the quiet mode: the `-q` flag can optionally be part of a cluster:

* `$:julia script.jl -f file1.txt file2.txt -lqt --mode2`
* `$:julia script.jl -q -f file1.txt file2.txt -lt --mode2`

The function that scans whether the `-q` flag was passed is simply:

```
seekflag(ARGS,"-q")
```

## Fetching values from `ARGS`

Suppose you want a program that:
* analyzes an arbitrary amount of files, indicated by either `-f` or `--file`
* takes one bin count, indicated by either `-b` or `--nbins`. If this value isn't specified, the bin count takes the default value 50.
* accepts other optional toggles like `-q` or `-v`

Then you can use this to fetch the values from a call like this:
Using `PlainCLIArgs.jl`, your program will be able to fetch values and toggles from command-line, regardless of their order. Here's some example calls:
```
$:julia script.jl -q -f file1.txt file2.txt -b 100
$:julia script.jl -b 100 -f file1.txt file2.txt
$:julia script.jl -quiet --file file1.txt file2.txt --nbins 100
```

Here's what the value-fetching code looks like:

```
nbins = 50 # Default value, can be overriden by the user
bincountdata = FlagSearchResult[]
append!(bincountdata, seekvaluesof(ARGS,"-b"))
append!(bincountdata, seekvaluesof(ARGS,"--nbins"))

filenamesdata = FlagSearchResult[]
append!(filenamesdata, seekvaluesof(ARGS,"-f"))
append!(filenamesdata, seekvaluesof(ARGS,"--file"))
```

Afterwards, you can use `countvalues(filenamesdata)` to count the amount of filenames passed and error out if the user passed none, or use `getvalues(filenamesdata)` to extract the actual filenames. More on these later.

Also, `seekvalsof` is defined as an alias for `seekvaluesof`, in case you prefer that shorthand name.

# Example function: parsing the arguments of a simple program

For this example we'll use a program that takes a filename and optionally a verbosity toggle (the default mode is quiet). This program is simple, so it won't check for stray flags. The argument-parsing example shown here returns a `struct`, but note that *this is not mandatory*. If you prefer, you can instead write a function that returns a `Dict`, or even scalars and vectors. That said, `struct`s and `Dict`s are easier to manage if your option list starts growing; some do if you look at them funny.

Here's what the call looks like:

```
progbehavior = loadMySimpleProgramBehavior(ARGS)
```

This program's `struct` is just:

```
struct MySimpleProgramBehavior
    filename  :: String
    modequiet :: Bool
end
```

And the argument-parsing function is:

```
function loadMySimpleProgramBehavior(args :: AbstractVector{<:AbstractString})
    # Set default values
    modequiet = true

    parsedargs = parseargs(args)
    if "-v" in parsedargs.chars || "--verbose" in parsedargs.strings
        modequiet = false
    end

    filename = only(parsedargs.values) # only() takes a 1-element vector and returns the element as a scalar

    return MySimpleProgramBehavior(filename,modequiet)
end
```

The function `parseargs` returns a `ParsedArguments` value. It has four fields; all of them are string vectors:
* `strings`, holds all the double-dash arguments (such as `--verbose` or `--mode1`)
* `chars`, holds all the one-dash arguments. If you pass `-lthr` to the program, this field has the elements `"-l"`, `"-t"`, `"-h"`, `"-r"`.
* `values`, holds all the arguments that don't start with a dash, such as filenames or numeric values.
* `args`, a copy of `ARGS`.

`PlainCLIArgs.jl` has more machinery we're yet to see. However, if you're working on a simple program, you might have enough with `if "-v" in parsedargs.chars` and `filenames = parsedargs.values` and so on.

Other `PlainCLIArgs.jl` features such as detecting stray flags or flag collision requires a bit more legwork (such as the type `FlagSearchResult`). The next example shows you how.

# Example function: parsing the arguments of a complex program

For the final example we'll go over an argument-parsing function for a program that takes:
* A mandatory filename list, which can have any number of files.
* A number of bins, although this is optional (the default value is 50).
* A verbosity toggle; the program is quiet by default.

We'll also add a mutual-exclusivity check because of the verbosity toggle, and the program displays a help message with `-h` or `--help`.

For example, here are some valid ways to call the program:
```
$:julia script.jl --help
$:julia script.jl -q -f file1.txt file2.txt -b 100
$:julia script.jl --quiet -b 100 -f file1.txt file2.txt
$:julia script.jl --file file1.txt file2.txt --verbose
```

Whereas this one has a flag unknown to the program, so the argument-parsing function would throw an error and single out the `l` in the `-ql` flag.
```
$:julia script.jl -ql -f file1.txt file2.txt -b 100
```

Lastly, we'll include stray-flag detection using `findunclaimedtokens`. Therefore, the argument-parsing function will scan `ARGS` and extract the user's flags and values, then check at the end if any were left unclaimed. This bookkeeping step is done manually because of `PlainCLIArgs.jl`'s formulation: *Everything in plain sight. Nothing behind the scenes.*

As a result, the argument-parsing function is a bit long. However, every block is transparent, more flags can be added easily, and you are free to do a system call or run `isfile` or `scp` or `curl` or any other task *at any point* throughout the function.

Here's the `struct` for this program:

```
struct MyComplexProgramBehavior
    filenames :: Vector{String}
    nbins :: Int
    modequiet :: Bool
    modehelp :: Bool
end
```

Next is the argument parser. There's an explanation on the functions we haven't introduced so far, at the end:

```
function loadMyComplexProgramBehavior(args :: AbstractVector{<:AbstractString})
    # Set default values
    nbins = 50
    modequiet = true
    modehelp  = false

    # This helps us detect stray flags or typos
    claimedtokens = FlagSearchResult[]

    # Check for mutual exclusivity
    ex = "Modes `quiet' and `verbose' are incompatible!" # This explanation is printed to the screen if there's a collision
    checkgroupexclusivity(args, ex, ["-q","--quiet"], ["-v","--verbose"])

    # Resolve modehelp value
    helpdata = FlagSearchResult[]
    append!(helpdata, seekflag(args,"-h"))
    append!(helpdata, seekflag(args,"--help"))

    if !isempty(helpdata)
        modehelp = true
    end

    # Bookkeeping for stray-token detection
    append!(claimedtokens, helpdata)

    # Resolve modequiet value
    vd_quiet = FlagSearchResult[] # vd: verbosity data
    append!(vd_quiet, seekflag(args,"-q"))
    append!(vd_quiet, seekflag(args,"--quiet"))
    vd_verbose = FlagSearchResult[] # vd: verbosity data
    append!(vd_verbose, seekflag(args,"-v"))
    append!(vd_verbose, seekflag(args,"--verbose"))

    if !isempty(vd_quiet)
        modequiet = true
    elseif !isempty(vd_verbose)
        modequiet = false
    end

    # Bookkeeping for stray-token detection
    append!(claimedtokens, vd_quiet, vd_verbose)

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

    # See if the user passed an explicit nbins number
    binsdata = FlagSearchResult[]
    append!(binsdata, seekvaluesof(args,"-b"))
    append!(binsdata, seekvaluesof(args,"--nbins"))

    if countvalues(binsdata) > 1
        error("The default bincount value is 50; you can override this but don't pass more than one bincount value! You passed the values $(join(getvalues.(binsdata),' '))")
    # Override the default if the user passed a bincount value
    elseif countvalues(binsdata) == 1
        nbins = getvalue(binsdata,Int)
    end

    # Final bookkeeping step
    append!(claimedtokens, binsdata)
    unclaimed = findunclaimedtokens(args,claimedtokens)
    if !isempty(unclaimed)
        error("Error in ARGS! You passed some stray options. Run \n  \$:julia myprogram.jl -h\nto see the valid options.\n\n== Stray tokens:\n"*join(writetokens(args,unclaimed),'\n'))
    end

    return MyComplexProgramBehavior(filenames,nbins,modequiet,modehelp)
end 
```

The code we haven't seen yet is:
* `FlagSearchResult` is a type with three fields: The first two are ints and are used for stray-flag detection: `whicharg` and `whichtoken`. The final one is a string: `value`, and is the one you'll be interacting with. The values from a `FlagSearchResult` scalar or vector can be extracted using `getvalue` or `getvalues`.
* `getvalue` extracts the value from a `FlagSearchResult` or 1-element `Vector{FlagSearchResult}`. In the example above we want an integer value, hence we pass `Int` as the second argument of `getvalue`. If you run `getvalue(binsdata)`, you'll get the value as a `String`.
* `getvalues` is like `getvalue`, but it takes any `Vector{FlagSearchResult}` and returns a vector (of `String`s if no type is provided, of the requested type otherwise). Suppose your program took a variable amount of temperature values. You can save them to a floatvec with: `temps = getvalues(tempdata,Float64)`
* `countvalues` returns the amount of values passed for a flag. Use this to ensure that the user passed a valid number of arguments for a given flag.
* `seekallvalues` extracts all values from `ARGS`. You can use this over `seekvaluesof` if your program doesn't need to distinguish between value types (suppose, they're all filenames or all temperatures) and you'd rather have its calls look like `$:julia script.jl file1.txt file2.txt --verbose` rather than `$:julia script.jl --file file1.txt file2.txt --verbose`.
