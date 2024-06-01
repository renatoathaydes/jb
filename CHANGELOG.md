## Next

## 0.6.0

- added `publish` task for publishing to local and remote Maven repositories, including Maven Central.
- added `showJbConfiguration` task.
- improved POM creation task.
- added config `name`, `description`, `url`, `licenses`, `developers`, `scm` (used by Maven) to project configuration.
- include jar dependencies in project's libraries directories.
- list also jar and sub-project dependencies in `dependencies` task.
- many improvements to extension tasks.

## 0.5.0

- Handle jar dependencies.
- Show dependencies in dependencies task.
- Experimental support for Java-written extension tasks.
- New `requirements` task to show project requirements.

## 0.4.0

- #5 Support for annotation processors.
- Pass options starting with `-J-` to the JVM runtime, not the Java tool being called. See error-prone example.
- Report basic errors without stacktrace.
- Fixed version report.

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
