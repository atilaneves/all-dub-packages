import std.exception : enforce;
import std.format : format;
import std.json : JSONType, JSONValue, parseJSON;
import std.net.curl : get;
import std.stdio : writeln;
import std.string : endsWith;

string githubUrlFromPackage(in string packageName)
{
    const string apiUrl = format("https://code.dlang.org/api/packages/%s/info", packageName);
    const string body = get(apiUrl).idup;
    const JSONValue parsed = parseJSON(body);
    enforce(parsed.type == JSONType.object, "Package info JSON is not an object.");
    const JSONValue[string] obj = parsed.object;
    const JSONValue* repositoryPtr = "repository" in obj;
    enforce(repositoryPtr && repositoryPtr.type == JSONType.object, "Package JSON missing repository information.");
    const JSONValue[string] repository = repositoryPtr.object;
    const JSONValue* ownerPtr = "owner" in repository;
    const JSONValue* projectPtr = "project" in repository;
    enforce(ownerPtr && ownerPtr.type == JSONType.string && ownerPtr.str.length, "Repository owner missing.");
    enforce(projectPtr && projectPtr.type == JSONType.string && projectPtr.str.length, "Repository project missing.");
    const string owner = ownerPtr.str;
    const string projectRaw = projectPtr.str;
    const bool hasDotGit = projectRaw.endsWith(".git");
    const string project = hasDotGit ? projectRaw[0 .. $ - 4] : projectRaw;
    return "https://github.com/" ~ owner ~ "/" ~ project;
}

void main(string[] args)
{
    enforce(args.length == 2, "Usage: dub_package_url <package name>");
    const string packageName = args[1];
    const string githubUrl = githubUrlFromPackage(packageName);
    writeln(githubUrl);
}
