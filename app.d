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
    import std.datetime.stopwatch: StopWatch, AutoStart;
    import std.algorithm: filter;
    import std.range: walkLength;

    output.writeln("Checking packages...\n");
    auto sw = StopWatch(AutoStart.yes);

    auto packages = getPackages;
    auto okPackages = packages
        .save
        .parallelMap!builds
        .filter!(x => x != "");

    output.writeln("\n\nChecked ", packages.length, " packages in ", sw.peek);
    output.writeln(okPackages.save.walkLength, " packages still build.\n\n");

    write(okPackages);
}


auto parallelMap(alias F, R)(R range) {
    import std.parallelism: TaskPool;

    auto taskPool = new TaskPool;
    auto ret = taskPool
        .amap!F(range);

    taskPool.finish(/*blocking=*/false);

    return ret;
}

auto getPackages() {
    import std.net.curl: get;
    import std.json: parseJSON;
    import std.algorithm: map;

    return "https://code.dlang.org/packages/index.json"
        .get
        .parseJSON
        .array // the JSONValue one, not std.array.array
        .map!(a => a.str)
        ;
}

string builds(in string dubPackage) {
    import std.process: execute;
    import std.stdio: writeln;
    writeln("Checking ", dubPackage);
    auto ret = execute(["dub", "build", "-y", dubPackage]);
    return ret.status == 0
        ? dubPackage
        : "";
}

void write(R)(R okPackages) {
    import std.stdio: File;
    import std.array: array;
    import std.algorithm: sort;

    auto file = File("packages.txt", "w");
    foreach(pkg; sort(okPackages.array)) {
        file.writeln(pkg);
    }
}
