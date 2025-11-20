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

struct PackageOutcome {
    string name;
    bool success;
}

void run(Options options) {
    import std.stdio : writeln;
    import std.algorithm : map, filter;
    import std.array : array;
    import std.range : enumerate;

    auto packages = loadPackages(options.packagesFile);
    writeln("Re-running ", packages.length, " packages from ", options.packagesFile);

    auto jobs = packages
        .enumerate
        .map!(pkg => PackageJob(pkg.index, packages.length, pkg.value,
                                 options.op, options.dmdArgs, options.baseDFlags))
        .array;

    auto results = jobs
        .parallelMap!runPackage
        .array;

    auto successes = results
        .filter!(pkg => pkg.success)
        .array;
    auto failures = results
        .filter!(pkg => !pkg.success)
        .map!(pkg => pkg.name)
        .array;

    writeln("\n", successes.length, " out of ", packages.length, " packages succeeded.");

    auto failureFile = buildFailureFilePath(options.packagesFile);
    writeln("Writing ", failures.length, " failures to ", failureFile);
    writeFailures(failureFile, failures);
}

PackageOutcome runPackage(PackageJob job) {
    import std.process : execute;
    import std.string : join;
    import std.stdio : writeln, stderr;
    import std.format : format;

    auto baseCmd = job.op == Operation.build
        ? ["dub", "build", "-y"]
        : ["dub", "build", "-y", "--build=unittest"];

    auto cmd = baseCmd ~ [job.name];
    auto dflagsValue = buildDFlags(job.baseDFlags, job.dmdArgs);
    auto progress = format("%5d/%5d", job.index + 1, job.total);
    auto cmdString = cmd.join(" ");

    writeln("Running [", progress, "] ", job.name, " with `", cmdString, "`");

    string[string] env;
    if(dflagsValue.length)
        env["DFLAGS"] = dflagsValue;

    auto result = env.length ? execute(cmd, env) : execute(cmd);
    if(result.status == 0)
        return PackageOutcome(job.name, true);

    stderr.writeln("Command failed for ", job.name, " (exit code ", result.status, ")");
    if(result.output.length)
        stderr.writeln(result.output);
    return PackageOutcome(job.name, false);
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

string buildFailureFilePath(string packagesFile) {
    import std.path : dirName, baseName, stripExtension, extension, buildPath;
    import std.string : startsWith;

    const dir = packagesFile.dirName;
    const base = packagesFile.baseName;
    const core = base.stripExtension;
    const ext = base.extension.length ? base.extension : "";

    string transformed = core;
    if(transformed.startsWith("dub-"))
        transformed = transformed[4 .. $];

    auto failureName = "new-" ~ transformed ~ "-failures" ~ ext;
    return dir.length ? buildPath(dir, failureName) : failureName;
}

void writeFailures(string fileName, string[] failures) {
    import std.stdio : File;

    auto file = File(fileName, "w");
    foreach(name; failures)
        file.writeln(name);
}
