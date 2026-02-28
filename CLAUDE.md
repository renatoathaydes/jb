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
│   │   ├── compile.dart          # Build compilation command
│   │   ├── groovy.dart           # Groovy detection and jar localization
│   │   └── jbuild_compile.dart   # JBuild compilation integration via XML-RPC
│   ├── dependencies/             # Dependency resolution
│   │   ├── parse.dart            # Parse JBuild output for resolved deps
│   │   ├── deps_cache.dart       # Actor-based caching of resolved deps
│   │   ├── printer.dart          # Format dependency tree for display
│   │   ├── writer.dart           # Write deps JSON and download jars
│   │   └── warnings.dart         # Detect/report version conflicts
│   ├── create/                   # Project creation (`jb create`)
│   ├── extension/                # Extension system (custom tasks)
│   │   ├── jb_extension.dart     # Load and execute extension projects
│   │   ├── cache_model.dart      # Cache models for extension tasks
│   │   └── constructors.dart     # Construct extension task arguments
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

```bash
dart pub get              # Install dependencies
dart dartle.dart          # Build jb (default task is `build`, outputs to build/bin/jb)
dart dartle.dart test     # Run tests
dart dartle.dart distribution  # Create distribution artifacts
```

The build file (`dartle.dart`) uses `DartleDart` (Dartle's Dart integration) plus custom tasks
from `dartle-src/` for code generation, test setup, and distribution.

**Generated files** (committed, regenerated during build):
- `lib/src/jb_config.g.dart` - Configuration model (schemake)
- `lib/src/compilation_path.g.dart` - Compilation path model
- `lib/src/jbuild_jar.g.dart` - Embedded JBuild jar (base64, ~626KB)
- `lib/src/licenses.g.dart` - SPDX license registry (~153KB)
- `lib/src/version.g.dart` - Version string

## Architecture

### Task System (Dartle)

jb uses the **Dartle** build framework for task management. Key concepts:
- **Task**: Unit of work with `dependsOn`, `runCondition`, `TaskPhase`
- **RunOnChanges**: Track file inputs/outputs for incremental builds
- **AlwaysRun**: Task runs unconditionally (use with care - bypasses dependency propagation)
- **TaskPhase**: `depsPhase` → `evaluatePhase` → `publishPhase` (controls execution order)
- **dependsOn**: Declares task dependencies; Dartle runs them in topological order

Important: When a task has `AlwaysRun` run condition, Dartle's `_createTaskWithStatus` short-circuits,
bypassing the `_anyDepMustRun` check. This means dependencies won't be triggered. Use `RunOnChanges`
instead to ensure proper dependency propagation.

Task definitions are in `lib/src/tasks.dart`. The task graph is assembled in `lib/src/jb_dartle.dart`
(`JbDartle` class). `lib/src/runner.dart` (`JbRunner`) orchestrates execution.

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

## Testing

### Running Tests

```bash
dart dartle.dart test                         # All tests (via Dartle build)
dart test                                     # All tests (direct)
dart test test/config_test.dart               # Single test file
dart test test/projects_test.dart --name "hello"  # Tests matching name
```

Tests require `build/bin/jb` to exist (built by `dart dartle.dart`).
Test results are written to `build/test-results.json` (configured in `dart_test.yaml`).

### Test Files

| File | What it tests |
|------|---------------|
| `config_test.dart` | Config loading/parsing from YAML/JSON |
| `projects_test.dart` | Full project compilation, test execution, sub-projects |
| `examples_test.dart` | Example project builds |
| `jb_extension_test.dart` | Extension system functionality |
| `pom_test.dart` | POM file generation |
| `dependencies/jbuild_deps_collector_test.dart` | Dependency parsing |
| `dependencies/license_parser_test.dart` | License information extraction |
| `dependencies/warnings_test.dart` | Version conflict warnings |
| `compile/groovy_test.dart` | Groovy jar pattern recognition |
| `file_tree_test.dart` | File tree traversal |
| `modules_parser_test.dart` | Java modules detection |
| `patterns_test.dart` | Regex patterns |
| `options_test.dart` | CLI options parsing |
| `properties_test.dart` | Property resolution |
| `util_test.dart` | Utility functions |
| `xml_rpc_test.dart` | XML-RPC communication |

### Test Infrastructure

**Test helper** (`test/test_helper.dart`):
- `projectGroup(dir, name, body)` - Sets up test group with setUp/tearDown that cleans build artifacts
  (deletes `.jb-cache`, `out`, `build`, `compile-libs`, `runtime-libs`)
- `runJb(dir, args)` - Executes `build/bin/jb` in a directory, returns `ProcessResult`
- `startJb(dir, args)` - Starts jb process (for long-running)
- `expectSuccess(result)` - Asserts exit code 0
- `assertDirectoryContents(dir, expected)` - Validates directory contents
- `createTempFiles(files)` - Creates temporary test files
- `expectCompilationPath(result)` - Validates compilation paths

### Test Projects (`test/test-projects/`)

| Directory | Purpose |
|-----------|---------|
| `hello/` | Basic Java "Hello World" - single class compilation |
| `with-deps/` | External dependencies using pre-built test repo |
| `with-sub-project/` | Multi-module project (main + greeting sub-project) |
| `with-version-conflicts/` | Dependency conflict resolution testing |
| `tests/` | JUnit 5 test execution, sub-project dependencies |
| `java-modules/` | Java module system (module-info.java) |
| `empty/` | Minimal empty project |
| `example-extension/` | Custom jb extension task definition |
| `uses-extension/` | Project consuming an extension |
| `run-env/` | Runtime environment variables testing |
| `test-repo-prebuilt/` | Pre-built Maven repo with jars, poms, sha1 checksums |
| `test-repo/` | Source-based Maven repo (lists project) |
| `test-repo-src/` | Maven source repository |
| `java-libs/` | Java libraries for testing |

The `test-repo-prebuilt/` directory contains artifacts like `org/slf4j/slf4j-api/1.7.36/`
with `.jar`, `.pom`, and `.sha1` files. These are used by tests that need resolved dependencies
without hitting Maven Central.

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

## Example Projects (`example/`)

- `minimal-java-project/` - Basic Java project, no external dependencies
- `groovy-example/` - Groovy 4.x with Spock tests
- `javalin-http-server-sample/` - HTTP server with transitive dependency management
- `error-prone-java-project/` - Annotation processor integration

## Groovy Compilation

- Auto-detected by checking for Groovy or Spock dependencies
- Groovy 3.x: `org.codehaus.groovy:groovy`
- Groovy 4.x: `org.apache.groovy:groovy`
- Spock: `org.spockframework:spock-core`
- The Groovy jar is found by pattern `groovy-\d+\.\d+\..*\.jar` in compile-libs dir
- Compilation delegated to JBuild jar with `-g <groovy-jar-path>` flag
- JBuild jar handles Groovy classloading internally (not in this repo)

## Test Discovery (`lib/src/java_tests.dart`)

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

Projects are configured via `jbuild.yaml` (or `jbuild.json`) files. Key fields:
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

## Key Dependencies

| Package | Purpose |
|---------|---------|
| `dartle` | Task-based build system (like Make/Gradle) |
| `actors` | Actor model for safe concurrency (isolate-based) |
| `args` | CLI argument parsing |
| `yaml` | Parse YAML configuration files |
| `xml` | XML parsing (for XML-RPC) |
| `schemake` | Generate configuration models from schema |
| `archive` | ZIP archive handling for publishing |
| `crypto` | SHA256/MD5 checksum verification |
| `conveniently` | Extension methods and utilities |
| `structured_async` | Structured concurrency |

## Binary Files

`.gitattributes` marks `*.jar` and `*.pom` as binary to prevent git line-ending normalization,
which would break SHA1 checksum verification of Maven artifacts.

## `.jb-cache/` Directory

Per-project cache directory containing:
- `jbuild.jar` - Extracted JBuild jar
- `dependencies.json` - Resolved dependencies
- `processor-dependencies.json` - Processor dependencies
- `compilation-path.json` - Compilation classpath
- `runtime-path.json` - Runtime classpath
- `java-src-file-tree.txt` - Source file tracking
- `jvm.cds` - Class Data Sharing archive (Java 12+)
- Dartle cache files for incremental builds
