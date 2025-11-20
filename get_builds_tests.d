/**
   This app writes out the dub packages that build into dub-build.txt
   and the ones for which their tests pass into dub-test.txt.
 */

private:

public int main(string[] args) {
    import std.stdio: stdout, stderr;
    import std.getopt: GetOptException;

    try {
        run(stdout, Options(args));
        return 0;
    } catch(GetOptException e) {
        stderr.writeln("Error parsing options: ", e.msg);
        return 1;
    } catch(Exception e) {
        stderr.writeln("Error: ", e.msg);
        return 1;
    }
}

struct Options {
    bool runBuilds;
    bool runTests;

    this(string[] args) {
        import std.getopt: getopt, defaultGetoptPrinter;
        import core.stdc.stdlib: exit;

        bool helpFlag;

        auto result = getopt(
            args,
            "builds|b", "Run build checks only (can be combined with --tests)",
            &runBuilds,
            "tests|t", "Run test checks only (can be combined with --builds)",
            &runTests,
            "help|h", "Show this help message",
            &helpFlag,
            );

        if(helpFlag) {
            defaultGetoptPrinter("Usage: get_builds_tests [OPTIONS]", result.options);
            exit(0);
        }

        if(!runBuilds && !runTests)
            runBuilds = runTests = true;
    }
}

void run(O)(auto ref O output, Options options = Options.init) {
    auto packages = getPackages;
    output.writeln("Checking ", packages.length, " packages...\n");

    if(options.runBuilds)
        check!builds(output, packages, "dub-build.txt");

    if(options.runTests)
        check!tests(output, packages, "dub-test.txt");
}

struct PackageContext {
    size_t index;
    size_t total;
    string name;
}

auto getPackages() {
    import std.stdio: File;
    import std.algorithm: map;
    import std.array: array;
    import std.range: take;

    return File("packages.txt")
        .byLine
        .map!(l => l.idup)
        //.take(250)
        .array
        ;
}

void check(alias F, O)(auto ref O output, in string[] dubPackages, in string outputFileName) {
    import std.datetime.stopwatch: StopWatch, AutoStart;
    import std.array: array;
    import std.algorithm: filter, map;
    import std.range: enumerate;

    output.writeln("Checking ", dubPackages.length, " ", __traits(identifier, F));
    auto sw = StopWatch(AutoStart.yes);

    auto packageContexts = dubPackages
        .enumerate
        .map!(pkg => PackageContext(pkg.index, dubPackages.length, pkg.value))
        .array;

    auto okPackages = packageContexts
        .parallelMap!F
        .filter!(x => x != "")
        .array;

    output.writeln("\n\nChecked ", dubPackages.length, " packages in ", sw.peek);
    output.writeln("Outputting to ", outputFileName);
    output.writeln(okPackages.length, " packages passed check `",  __traits(identifier, F), "`");
    write(outputFileName, okPackages);
}


auto parallelMap(alias F, R)(R range) {
    import std.parallelism: TaskPool;

    auto taskPool = new TaskPool;
    auto ret = taskPool
        .amap!F(range);

    taskPool.finish(/*blocking=*/true);

    return ret;
}

string builds(in PackageContext packageContext) {
    return checkBuild(
        packageContext,
        [
            "dub",
            "build",
            "-y",
        ]
    );
}

string tests(in PackageContext packageContext) {
    return checkBuild(
        packageContext,
        [
            "dub",
            "build",
            "-y",
            "-build=unittest",
        ]
    );
}

string checkBuild(in PackageContext packageContext, in string[] cmd) {
    import std.process: execute;
    import std.stdio: writeln;
    import std.string: join;
    import std.format: format;
    import std.algorithm: canFind;

    const progress = format("%5d/%5d", packageContext.index + 1, packageContext.total);
    const cmdString = cmd.join(" ");
    const type = () {
        if(cmdString.canFind("build"))
            return "build";
        else if (cmdString.canFind("test"))
            return "test ";
        else
            throw new Exception("Unknown cmdString `" ~ cmdString ~ `"`);
    }();
    writeln("Checking ", type, " [", progress, "] ", packageContext.name);
    auto ret = execute(cmd ~ packageContext.name);
    return ret.status == 0
        ? packageContext.name
        : "";
}

void write(R)(in string fileName, R okPackages) {
    import std.stdio: File;
    import std.array: array;
    import std.algorithm: sort;

    auto file = File(fileName, "w");
    foreach(pkg; sort(okPackages.array)) {
        file.writeln(pkg);
    }
}
