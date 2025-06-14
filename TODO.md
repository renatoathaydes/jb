# A list of unresolved tasks in this project

Temporary file tracking known bugs and missing features in jb.

Once the project is in good shape, this should be moved to a proper bug tracker.

## Missing features

- fat jar
- detect Java version from environment and recompile if changed.
- generatePom task needs to resolve transitive dependencies in order to generate appropriate POM exclusions.
- tasks that depend on the jb config file must also depend on any imports into it.

## Bugs

- test task generates a test-reports directory but does not clean it.
