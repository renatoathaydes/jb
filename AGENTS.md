# JBuild (jb) - Project Overview

JBuild is a Java build tool implemented in **Dart**. It compiles Java and Groovy projects
by delegating to a JBuild jar (Java-based) via XML-RPC on localhost (with bearer token auth).

The JBuild jar is a separate Java project (not in this repo). It is embedded in the Dart
build output as base64 (`lib/src/jbuild_jar.g.dart`) and extracted to `.jb-cache/jbuild.jar`
on first run.

## Project Structure

```
jb/
├── bin/jbuild_cli.dart           # CLI entry point
├── lib/src/                      # Core library (~25K lines including generated)
│   ├── compile/                  # Compilation logic
│   ├── dependencies/             # Dependency resolution
│   ├── create/                   # Project creation (`jb create`)
│   ├── extension/                # Extension system (custom tasks)
│   ├── entry_point.dart          # Main entry after CLI parsing
│   ├── runner.dart               # JbRunner - orchestrates build execution
│   ├── tasks.dart                # All 20+ jb task definitions
│   ├── jb_dartle.dart            # JbDartle - creates Dartle task graph, sub-projects
│   ├── config.dart               # Configuration parsing (YAML/JSON), Groovy constants
│   ├── jvm_executor.dart         # Actor managing JBuild jar process via XML-RPC
│   ├── xml_rpc.dart              # XML-RPC client implementation
│   ├── java_tests.dart           # Test framework detection (JUnit/Spock)
│   ├── resolved_dependency.dart  # ResolvedDependency models
│   ├── compute_compilation_path.dart  # Classpath/modulepath calculation
│   ├── publish.dart              # Publishing to local/remote Maven repos
│   ├── pom.dart                  # POM file generation
│   ├── maven_client.dart         # HTTP client for Maven Central publishing
│   ├── utils.dart                # Extract embedded jar, file ops, logging
│   ├── jshell.dart               # Interactive Java Shell integration
│   ├── file_tree.dart            # Efficient file tree tracking
│   ├── patterns.dart             # Regex patterns for parsing
│   ├── options.dart              # CLI options parsing
│   ├── properties.dart           # Property variable resolution ({{var}})
│   ├── *.g.dart                  # Generated files (config model, jar, licenses, version)
│   └── ...
├── test/                         # Test suite (16 files, ~20K lines)
├── example/                      # Example projects (4)
├── dartle.dart                   # Build file for jb itself (uses Dartle)
├── dartle-src/                   # Build task definitions for jb
├── website/                      # Documentation site
├── .github/workflows/            # CI/CD configurations
├── pubspec.yaml                  # Dart package definition
├── analysis_options.yaml         # Lint config (excludes *.g.dart and dartle-src/)
└── dart_test.yaml                # Test config (JSON reporter to build/test-results.json)
```

## Building and Running

Using Dart directly:

```bash
dart pub get                  # Install dependencies
dart run dartle.dart          # Build jb (default task is `build`, outputs to build/bin/jb)
dart run dartle.dart test     # Run tests
dart run dartle.dart distribution  # Create distribution artifacts
```

### Dartle

The build file (`dartle.dart`) uses `DartleDart` (Dartle's Dart integration) plus custom tasks
from `dartle-src/` for code generation, test setup, and distribution.

Using Dartle (build system):

```bash
dartle -s                     # show the build tasks
dartle test                   # Run tests
dartle compileExe -l debug    # Compile executable, enable Dartle DEBUG logging
dartle test :-n :"POM with Maven dependencies" # Run a single test (Task options are prefixed with ':') 
```

To generate the generated Dart files and run the Dart analyzer, run:

```bash
dartle analyzeCode
```

The Dart formatter is run automatically by Dartle. Be careful when editing Dart files as they can be re-formatted.

## Architecture

### Basics

`jb` is a build system for Java and other JVM languages.
It uses the Dartle build system not only for its build, but as a Dart library.
As Dartle, `jb` is task-based. Tasks declare dependencies between each other and
inputs/outputs so that they can be cached.

### Actor Model

Concurrency uses the **actors** package (isolate-based):
- `JvmExecutor` - Manages JBuild jar process (singleton per build)
- `DepsCache` - Caches resolved dependencies
- `CompilationPathComputer` - Computes compilation/runtime classpaths

Actors are properly shut down at end of build, even on errors.

### Execution Flow

1. Parse CLI options (`options.dart`)
2. Load `jbuild.yaml`/`jbuild.json` config (`config.dart`)
3. Create actors (JVM executor, deps cache, compilation path)
4. Resolve local path dependencies (`resolved_dependency.dart`)
5. Create Dartle task graph (`jb_dartle.dart`)
6. Execute tasks respecting dependencies and phases
7. Cache results (file hashes in `.jb-cache/`)
8. Cleanup actors

## Tests

### Test Projects

Several test projects exist in `test/test-projects/`.
The projects under `example/` are also used by the tests.

The `test-repo-prebuilt/` directory contains artifacts like `org/slf4j/slf4j-api/1.7.36/`
with `.jar`, `.pom`, and `.sha1` files. These are used by tests that need resolved dependencies
without hitting Maven Central.

> Tests that use the test and example projects must be run with `dartle`, so the binary and
> the auto-generated files are up-to-date.

### Test Patterns

```dart
// Integration test pattern
projectGroup(helloProjectDir, 'hello project', () {
  test('can compile basic Java class', () async {
    final jbResult = await runJb(Directory(helloProjectDir));
    expectSuccess(jbResult);
    expect(
      await File(p.join(helloProjectDir, 'out', 'Hello.class')).exists(),
      isTrue,
    );
  });
});
```

Some tests are platform-specific: `testOn: '!windows'` (e.g., Groovy tests due to path handling).

## Groovy Compilation

`jb` supports both Java and Groovy compilation.

Groovy is auto-detected by checking for Groovy or Spock dependencies.

- Groovy 3.x: `org.codehaus.groovy:groovy`
- Groovy 4.x: `org.apache.groovy:groovy`
- Spock: `org.spockframework:spock-core`
- The Groovy jar is found by pattern `groovy-\d+\.\d+\..*\.jar` in compile-libs dir
- Compilation delegated to JBuild jar with `-g <groovy-jar-path>` flag
- JBuild jar handles Groovy classloading internally (not in this repo)

## Test Discovery (`lib/src/java_tests.dart`)

`jb` discovers tests automatically.

- Tests detected by looking at project dependencies for JUnit or Spock
- JUnit: dependency on `org.junit.jupiter:junit-jupiter-api:<version>`
- Spock: dependency on `org.spockframework:spock-core:<version>`
- `TestConfig` record holds `apiVersion` (JUnit), `platformVersion`, and `spockVersion`
- Tests run via JUnit ConsoleLauncher (`junit-platform-console-standalone` jar)
  - Launcher version matched to project's `org.junit.platform:` dependency version
  - Since JUnit 1.10+, the `execute` subcommand is required
- For Spock tests, the spock-core jar is also provided as a test runner lib
- `validateTestConfig()` fails if neither JUnit API nor Spock dependency is found

## Configuration

Projects are configured via `jbuild.yaml` (or `jbuild.json`) files.

The configuration model is generated from `dartle-src/config/jb_config_schema.dart`, which uses
the `schemake` package.

Key fields:

- `dependencies` - Maven-style dependency declarations (scope: compile, runtime-only, processor, test)
- `main-class` - Entry point for `jb run`
- `output-dir` / `output-jar` - Build output location
- `compile-libs-dir` - Where dependency jars are installed (default: `build/compile-libs/`)
- `source-dirs` - Java source directories
- `resource-dirs` - Resource directories
- `javac-args` - Compiler arguments (args starting with `-J-` are passed to the JVM)
- `repositories` - Maven repositories to use
- `exclusions` - Global transitive dependency exclusions (regex patterns)
- `properties` - Variables usable as `{{group.key}}` in config values

Config supports YAML imports for modular configuration.

## CI/CD

**CI** (`ci.yml`): Runs on push. Matrix: `ubuntu-latest`, `ubuntu-24.04-arm`, `macos-latest`,
`windows-latest` with Dart stable SDK and Java 11 (Zulu). Runs `dart dartle.dart` (build + test).

**Release** (`release.yml`): Triggered on GitHub release creation. Builds native executables
for 5 platforms using matrix strategy: `linux-x86`, `linux-arm64`, `macos-x86`, `macos-arm64`,
`windows`. Uploads `.tar.gz` artifacts to the GitHub release.

## `.jb-cache/` Directory

Per-project cache directory containing:
- `jbuild.jar` - Extracted JBuild jar (which is embedded in the `jb`'s binary')
- `dependencies.json` - Resolved dependencies
- `processor-dependencies.json` - Processor dependencies
- `compilation-path.json` - Compilation classpath
- `runtime-path.json` - Runtime classpath
- `java-src-file-tree.txt` - Source file tracking
- `jvm.cds` - Class Data Sharing archive (Java 12+, not reusable across Java versions)
- Dartle cache files for incremental builds
