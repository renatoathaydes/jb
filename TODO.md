# A list of unresolved tasks in this project

Temporary file tracking known bugs and missing features in jb.

Once the project is in good shape, this should be moved to a proper bug tracker.

## Missing features

- fat jar
- detect Java version from environment and recompile if changed.
- tasks that depend on the jb config file must also depend on any imports into it.
- add `--watch` option to `compile` task.

## Bugs

- test task generates a test-reports directory but does not clean it.
- Java test runner: downloads latest runner: `org.junit.platform:junit-platform-console-standalone:6.0.0-M1`
  which decided to change all CLI options!
