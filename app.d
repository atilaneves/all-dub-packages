private:


public void main() {
    import std.stdio: writeln, File;
    import std.parallelism: TaskPool;
    import std.datetime.stopwatch: StopWatch, AutoStart;
    import std.algorithm: filter;
    import std.range: take, walkLength;

    auto taskPool = new TaskPool;
    auto sw = StopWatch(AutoStart.yes);
    writeln("Checking packages...\n");
    auto packages = getPackages;
    auto okPackages = taskPool
        .amap!builds(packages.save)
        .filter!(x => x != "");
    taskPool.finish(/*blocking=*/false);
    writeln("\n\nChecked ", packages.length, " packages in ", sw.peek);
    writeln(okPackages.save.walkLength, " packages still build.\n\n");

    auto file = File("packages.txt", "w");
    foreach(pkg; okPackages) {
        file.writeln(pkg);
    }
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
