# JBuild (jb) - Project Overview

JBuild is a Java build tool implemented in **Dart**. It compiles Java and Groovy projects
by delegating to a JBuild jar (Java-based) via XML-RPC.

## Project Structure

- `bin/jbuild_cli.dart` - CLI entry point
- `lib/src/` - Core library source (Dart)
  - `compile/` - Compilation logic
    - `groovy.dart` - Groovy detection and jar localization
    - `compile.dart` - Compilation command building
    - `jbuild_compile.dart` - JBuild compilation integration
  - `tasks.dart` - Task orchestration
  - `config.dart` - Configuration parsing (jbuild.yaml/json), Groovy constants
  - `jvm_executor.dart` - RPC communication with JBuild jar process
- `test/` - Dart tests and test fixtures
  - `test-projects/` - Test Maven repos and sample projects
    - `test-repo-prebuilt/` - Pre-built Maven repo with jars, poms, and sha1 checksums
- `example/groovy-example/` - Groovy example project (uses Groovy 4.x and Spock)
- `.github/workflows/ci.yml` - CI: runs on Ubuntu, macOS, Windows with Dart SDK + Java 11
- `dartle.dart` - Build file (run with `dart dartle.dart`)

## Groovy Compilation

- Groovy projects are auto-detected by checking for Groovy or Spock dependencies
- Groovy 3.x: `org.codehaus.groovy:groovy`
- Groovy 4.x: `org.apache.groovy:groovy`
- Spock: `org.spockframework:spock-core`
- The Groovy jar is found by pattern `groovy-\d+\.\d+\..*\.jar` in compile-libs dir
- Compilation is delegated to the JBuild jar with `-g <groovy-jar-path>` flag
- The JBuild jar (Java code) handles Groovy classloading internally (not in this repo)

## Test Discovery (`lib/src/java_tests.dart`)

- Tests are detected by looking at project dependencies for JUnit or Spock
- JUnit: dependency on `org.junit.jupiter:junit-jupiter-api:<version>`
- Spock: dependency on `org.spockframework:spock-core:<version>`
- `TestConfig` record holds `apiVersion` (JUnit), `platformVersion`, and `spockVersion`
- Tests are run via JUnit ConsoleLauncher (`junit-platform-console-standalone` jar)
  - The launcher version is matched to the project's `org.junit.platform:` dependency version
  - Since JUnit 1.10+, the `execute` subcommand is required
- For Spock tests, the spock-core jar is also provided as a test runner lib
- `validateTestConfig()` fails if neither JUnit API nor Spock dependency is found

## Configuration

Projects are configured via `jbuild.yaml` files. Key fields:
- `dependencies` - Maven-style dependency declarations
- `main-class` - Entry point for `jb run`
- `output-dir` - Override default output directory
- `compile-libs-dir` - Where dependency jars are installed (default: `build/compile-libs/`)

## Binary Files

`.gitattributes` marks `*.jar` and `*.pom` as binary to prevent git line-ending normalization,
which would break SHA1 checksum verification of Maven artifacts.
