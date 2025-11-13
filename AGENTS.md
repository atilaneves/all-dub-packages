# Code Style
* The `main` function's only job is to call `run` and return a non
  zero code if an Exception was thrown, do not make it do more than
  that.
* Use the One True Brace Style.
* Use UFCS wherever possible.
* Use localised imports, that is, import inside the function that
  requires the imports.
* Prefer `const` to `auto`.

# Building
* Use `ldc2 -O3 get_builds_tests.d -of get_builds_tests` to build
  after any changes have been done.
