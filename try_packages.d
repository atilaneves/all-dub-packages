/**
 * Re-run `dub build`/`dub test` for packages listed in dub-build.txt or dub-test.txt,
 * optionally forwarding extra arguments to the underlying D compiler (e.g. dmd).
 */
enum Operation { build, test }

struct Options {
    string packagesFile;
    string[] dmdArgs;
    string baseDFlags;
    Operation op;

    this(string[] rawArgs) {
        import std.getopt : getopt, defaultGetoptPrinter;
        import core.stdc.stdlib : exit;
        import std.exception : enforce;

        auto args = rawArgs;

        auto result = getopt(
            args,
            "dmd-flag", "Additional flag to pass to the compiler (repeatable)",
            &dmdArgs,
        );

        if(result.helpWanted) {
            defaultGetoptPrinter("Usage: rerun_packages [OPTIONS] <dub-build.txt|dub-test.txt>",
                                 result.options);
            exit(0);
        }

        {
            import std.process : environment;
            baseDFlags = environment.get("DFLAGS", "");
        }

        enforce(args.length > 1, "Expected a path to dub-build.txt or dub-test.txt");
        enforce(args.length == 2, "Expected only one path to dub-build.txt or dub-test.txt");
        packagesFile = args[1];
        op = determineOperation(packagesFile);
    }
}

int main(string[] args) {
    import std.stdio : stderr;

    try {
        run(Options(args));
        return 0;
    } catch(Exception e) {
        stderr.writeln("Error: ", e.msg);
        return 1;
    }
}

struct PackageJob {
    size_t index;
    size_t total;
    string name;
    Operation op;
    string[] dmdArgs;
    string baseDFlags;
}

void run(Options options) {
    import std.stdio : writeln;
    import std.algorithm : map, filter;
    import std.array : array;
    import std.range : enumerate;
    import std.string : join;

    auto packages = loadPackages(options.packagesFile);
    writeln("Re-running ", packages.length, " packages from ", options.packagesFile);

    auto jobs = packages
        .enumerate
        .map!(pkg => PackageJob(pkg.index, packages.length, pkg.value,
                                 options.op, options.dmdArgs, options.baseDFlags))
        .array;

    auto successes = jobs
        .parallelMap!runPackage
        .filter!(pkg => pkg.length != 0)
        .array;

    writeln("\n", successes.length, " out of ", packages.length, " packages succeeded.");
    if(successes.length)
        writeln("Successful packages:\n", successes.join("\n"));
}

string runPackage(PackageJob job) {
    import std.process : execute;
    import std.string : join;
    import std.stdio : writeln, stderr;

    auto baseCmd = job.op == Operation.build
        ? ["dub", "build", "-y"]
        : ["dub", "test"];

    auto cmd = baseCmd ~ [job.name];
    auto dflagsValue = buildDFlags(job.baseDFlags, job.dmdArgs);

    writeln("Running [", job.index + 1, "/", job.total, "] ",
            job.name, " with `", cmd.join(" "), "`");

    string[string] env;
    if(dflagsValue.length)
        env["DFLAGS"] = dflagsValue;

    auto result = env.length ? execute(cmd, env) : execute(cmd);
    if(result.status == 0)
        return job.name;

    stderr.writeln("Command failed for ", job.name, " (exit code ", result.status, ")");
    if(result.output.length)
        stderr.writeln(result.output);
    return "";
}

auto parallelMap(alias F, R)(R range) {
    import std.parallelism : TaskPool;

    auto pool = new TaskPool;
    auto ret = pool.amap!F(range);
    pool.finish(/*blocking=*/true);
    return ret;
}

string buildDFlags(string baseFlags, string[] extraFlags) {
    import std.string : join;

    string[] parts;
    if(baseFlags.length)
        parts ~= baseFlags;
    foreach(flag; extraFlags) {
        if(flag.length)
            parts ~= flag;
    }
    return parts.length ? parts.join(" ") : baseFlags;
}


Operation determineOperation(string fileName) {
    import std.path : baseName;
    import std.string : toLower;
    import std.algorithm : canFind;
    import std.exception : enforce;

    auto lowerName = fileName.baseName.toLower;
    if(lowerName.canFind("build"))
        return Operation.build;
    if(lowerName.canFind("test"))
        return Operation.test;
    enforce(false, "Unable to infer operation from file name: "~fileName);
    return Operation.build; // unreachable but satisfies compiler.
}

string[] loadPackages(string fileName) {
    import std.exception : enforce;
    import std.file : exists;
    import std.stdio : File;
    import std.algorithm : map, filter;
    import std.string : strip;
    import std.array : array;

    enforce(exists(fileName), "File not found: "~fileName);
    return File(fileName, "r")
        .byLine
        .map!(line => line.strip.idup)
        .filter!(line => line.length != 0)
        .array;
}
