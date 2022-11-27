## Next

- #5 Support for annotation processors.
- Pass options starting with `-J-` to the JVM runtime, not the Java tool being called. See error-prone example.
- Report basic errors without stacktrace.

## 0.3.0

- Support for YAML imports.
- Added config `java-env`, `run-java-env` and `test-java-env` for setting environment variables.
- Removed build dependency on freezed. 

## 0.2.0

- Fixed detecting `--main-class` argument to `run` task when it's the first argument.
- Added documentation for most code.
- Detect when user selects JUnit tests explicitly to avoid passing `--scan-classpath` option.
- Updated embedded jbuild.jar with several fixes.
- #6 Support for properties in YAML files.
- Print a success message at the end of a build.
- Better output of `dependencies` task.

## 0.1.0

- Initial version.
