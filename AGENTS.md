# Code Style
* The `main` function's only job is to call `run` and return a non
  zero code if an Exception was thrown, do not make it do more than
  that.
* Use the One True Brace Style.
* Use UFCS wherever possible.
* Use localised imports, that is, import inside the function that
  requires the imports. See examples below.
* Prefer `const` to `auto`.
* Prefer to write code that has at most 80 columns, but do not use
  this number as a hard limit. Sometimes code needs more space to
  breathe.

# Building
* Use `ldc2 -O3 get_builds_tests.d` to build after any changes have
  been made to `get_builds.tests.d`.
* Use `ldc2 -O3 try_packages.d` to build after any changes have been
  made to `try_packages.d`.


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
