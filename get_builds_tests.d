/**
   This app writes out the dub packages that build into dub-build.txt
   and the ones for which their tests pass into dub-test.txt.
 */

private:


public int main() {
    import std.stdio: stdout, stderr;
    try {
        run(stdout);
        return 0;
    } catch(Exception e) {
        stderr.writeln("Error: ", e.msg);
        return 1;
    }
}

void run(O)(auto ref O output) {
    auto packages = getPackages;
    output.writeln("Checking ", packages.length, " packages...\n");

    check!builds(output, packages, "dub-build.txt");
    check!tests(output, packages, "dub-test.txt");
}

auto getPackages() {
    import std.stdio: File;
    import std.algorithm: map;
    import std.array: array;
    import std.range: take;

    return File("packages.txt")
        .byLine
        .map!(l => l.idup)
        .take(50)
        .array
        ;
}

void check(alias F, O)(auto ref O output, in string[] dubPackages, in string outputFileName) {
    import std.datetime.stopwatch: StopWatch, AutoStart;
    import std.array: array;
    import std.algorithm: filter;
    import std.array: array;

    output.writeln("Checking ", dubPackages.length, " ", __traits(identifier, F));
    auto sw = StopWatch(AutoStart.yes);

    auto okPackages = dubPackages
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

    taskPool.finish(/*blocking=*/false);

    return ret;
}

string builds(in string dubPackage) {
    return checkBuild(
        dubPackage,
        [
            "dub",
            "build",
            "-y",
        ]
    );
}

string tests(in string dubPackage) {
    return checkBuild(
        dubPackage,
        [
            "dub",
            "test",
        ]
    );
}

string checkBuild(in string dubPackage, in string[] cmd) {
    import std.process: execute;
    import std.stdio: writeln;
    writeln("Checking ", dubPackage);
    auto ret = execute(cmd ~ dubPackage);
    return ret.status == 0
        ? dubPackage
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
