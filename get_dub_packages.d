/**
   This app queries code.dlang.org for the list of all dub packages.
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
    import std.datetime.stopwatch: StopWatch, AutoStart;
    import std.array: array, join;
    import std.stdio: File;

    output.writeln("Fetching packages...");
    auto sw = StopWatch(AutoStart.yes);
    auto packages = getPackages.array;
    output.writeln("There are ", packages.length, " dub packages");
    output.writeln("Fetched the information in ", sw.peek);
    auto file = File("packages.txt", "w");
    file.write(packages.join("\n"));
}

auto getPackages() {
    import std.net.curl: get;
    import std.json: parseJSON;
    import std.algorithm: map;

    import std.range;
    return "https://code.dlang.org/packages/index.json"
        .get
        .parseJSON
        .array // the JSONValue one, not std.array.array
        .map!(a => a.str)
        ;
}
