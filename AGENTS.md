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
* This is only valid for `*.d` files at the root of this git
  repository.
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

Each directory in `forks` is a fork of a Github project. The idea is
to fix any DIP1000 errors in that project. See `dip1000-check` below
for more details.

# dip1000-check

The task is to check a dub project for compilation failures due to
DIP1000. Running `./build_fork.sh <project>` forks (if necessary),
clones (if necessary), and builds a project in `forks/<project>`,
so running `./build_fork.sh <project>` is the only thing you need
to do to get going.

Running that is going to result in build failures. Edit files as
necessary in `forks/<project>` to make the build work. Do NOT edit
files elsewhere such as dub dependencies.

Do *not* remove `scope` annotations. If anything, you should add them.
Do *not* add `@trusted` to a function.

After the project successfully compiles, if you edited a function that
*had* to be `@trusted` before, try and see if it now compiles with
`@safe`. If it doesn't, revert the changes to what they were when the
project managed to compile.

Either way, if the project compiles, create a branch called
`fix-dip1000` and do a git commit with the message "Fix DIP1000
compilation errors".
