private:

public int main(string[] args) {
    import std.stdio: stderr;

    try {
        run(args);
        return 0;
    } catch(Exception e) {
        stderr.writeln("Error: ", e.msg);
        return 1;
    }
}

void run(string[] args) {
    import std.exception: enforce;
    import std.file: getcwd, mkdirRecurse;
    import std.path: buildPath;
    import std.stdio: writeln;

    enforce(args.length == 2, "Usage: fork_dub_package <package name>");

    const packageName = args[1];
    const githubUrl = githubUrlFromPackage(packageName);
    const repoName = repoNameFromGithubUrl(githubUrl);
    const forkOwner = "atilaneves";
    const bool forkAlreadyExists = forkExists(forkOwner, repoName);
    ensureFork(githubUrl, forkOwner, repoName, forkAlreadyExists);
    const destinationRoot = buildPath(getcwd(), "forks");
    mkdirRecurse(destinationRoot);
    const destination = buildPath(destinationRoot, packageName);
    ensureCloned(forkOwner, repoName, destination);
    ensureUpstream(destination, githubUrl);
    writeln("Fork ready at ", destination);
}

string githubUrlFromPackage(in string packageName) {
    import std.exception: enforce;
    import std.format: format;
    import std.json: JSONType, JSONValue, parseJSON;
    import std.net.curl: get;
    import std.string: endsWith;

    const apiUrl = format("https://code.dlang.org/api/packages/%s/info", packageName);
    const JSONValue parsed = parseJSON(get(apiUrl).idup);
    enforce(parsed.type == JSONType.object, "Package info JSON is not an object.");
    const JSONValue repo = parsed["repository"];
    const JSONValue* ownerPtr = "owner" in repo.object;
    const JSONValue* projectPtr = "project" in repo.object;
    enforce(ownerPtr && ownerPtr.type == JSONType.string, "Repository owner missing.");
    enforce(projectPtr && projectPtr.type == JSONType.string, "Repository project missing.");
    const owner = ownerPtr.str;
    const projectRaw = projectPtr.str;
    const hasDotGit = projectRaw.endsWith(".git");
    const project = hasDotGit ? projectRaw[0 .. $ - 4] : projectRaw;
    return "https://github.com/" ~ owner ~ "/" ~ project;
}

string repoNameFromGithubUrl(in string url) {
    import std.exception: enforce;
    import std.string: lastIndexOf, endsWith;

    const slashIndex = lastIndexOf(url, '/');
    enforce(slashIndex != -1 && slashIndex + 1 < url.length, "Invalid GitHub URL: " ~ url);
    const tail = url[cast(size_t)(slashIndex + 1) .. $];
    const hasDotGit = tail.endsWith(".git");
    const repoName = hasDotGit ? tail[0 .. $ - 4] : tail;
    enforce(repoName.length != 0, "Could not determine repository name from URL: " ~ url);
    return repoName;
}

bool commandSucceeded(in string[] command) {
    import std.process: execute;

    const result = execute(command);
    return result.status == 0;
}

void runCommand(in string[] command, in string errorMessage) {
    import std.conv: to;
    import std.exception: enforce;
    import std.process: execute;

    const result = execute(command);
    enforce(result.status == 0, errorMessage ~ "\nCommand: " ~ command.to!string ~ "\nOutput: " ~ result.output);
}

bool forkExists(in string owner, in string repoName) {
    const fullName = owner ~ "/" ~ repoName;
    const string[] command = ["gh", "repo", "view", fullName];
    return commandSucceeded(command);
}

void ensureFork(in string originalUrl, in string forkOwner, in string repoName, const bool forkAlreadyExists) {
    import std.stdio: writeln;

    if(forkAlreadyExists)
    {
        writeln("Fork already exists: ", forkOwner, "/", repoName);
        return;
    }

    writeln("Forking ", originalUrl, " into ", forkOwner, "/", repoName);
    const string[] command = ["gh", "repo", "fork", originalUrl, "--clone=false", "--remote=false"];
    runCommand(command, "Failed to fork " ~ originalUrl);
}

void ensureCloned(in string forkOwner, in string repoName, in string destination) {
    import std.file: exists;
    import std.stdio: writeln;

    if(exists(destination))
    {
        writeln("Clone already exists at ", destination);
        return;
    }

    const forkFullName = forkOwner ~ "/" ~ repoName;
    writeln("Cloning ", forkFullName, " into ", destination);
    const string[] command = ["gh", "repo", "clone", forkFullName, destination];
    runCommand(command, "Failed to clone fork " ~ forkFullName);
}

bool remoteExists(in string repoPath, in string remoteName) {
    const string[] command = ["git", "-C", repoPath, "remote", "get-url", remoteName];
    return commandSucceeded(command);
}

void ensureUpstream(in string repoPath, in string upstreamUrl) {
    import std.stdio: writeln;

    if(remoteExists(repoPath, "upstream"))
    {
        writeln("Upstream remote already present in ", repoPath);
        return;
    }

    writeln("Adding upstream remote (", upstreamUrl, ") to ", repoPath);
    const string[] command = ["git", "-C", repoPath, "remote", "add", "upstream", upstreamUrl];
    runCommand(command, "Failed to add upstream remote.");
}
