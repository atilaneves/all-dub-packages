# General
Re-read every D (`*.d`) file in the repository that has changed after
every command. Use git to figure out which ones that is.

# Code Style
* The `main` function's only job is to call `run` and return a non
  zero code if an Exception was thrown, do not make it do more than
  that.
* Use the One True Brace Style.
* Use UFCS wherever possible.
* Use localised imports, that is, import inside the function that
  requires the imports. See examples below.
* Use `const` instead of `auto` whenever/wherever possible.
* Prefer to write code that has at most 80 columns, but do not use
  this number as a hard limit. Sometimes code needs more space to
  breathe.

# Building
* Do not print "Next step: rebuild with ..." after editing a file.
  Instead, if you touch it, rebuild it.
* Use `ldc2 -O3 <file>.d` to build after any changes have been made
  to `<file>`. For example, `ldc2 -O3 foo.d` after changes
  to `foo.d`.


# Examples of what to do

```dlang
string foo(string input) {
    import std.string: replace;
    return input.replace("foo", "bar");
}
```

# Examples of what not to do

```dlang
import std.string;
string foo(string input) {
    return input.replace("foo", "bar");
}
```

# Forks

Each directory in `forks` is a fork of a Github project.  The idea is
to fix any DIP1000 errors in that project. The way one builds any of
those projects to see what the DIP1000 errors are is
`DFLAGS="-preview=dip1000" dub build --build=unittest`.
