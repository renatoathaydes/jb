{{ include /processed/fragments/_header.html }}\
{{ define name "Configuring jb" }}
{{ define path basePath + "/pages/config.html" }}
{{ define order 1 }}
{{ component /processed/fragments/_main.html }}
<div class="space-up"></div>

# Configuring jb

## Table of Contents

* [Imports](#imports)
* [Properties](#properties)
* [Publishing to a Maven Repository](#publishing)
* [Configuration Reference](#reference)

## Introduction

For a directory to contain a `jb` project, a YAML or JSON file called `jbuild.yaml` or `jbuild.json` must exist in it.

This file defines the configuration for the project.

> The `jb` configuration model is defined in [this file](https://github.com/renatoathaydes/jb/blob/main/dartle-src/config/jb_config_schema.dart). A JSON Schema can be generated from the model (TODO).

The minimal configuration file looks like this:

### YAML

```yaml
module: my-module
```

### JSON

```json
{
    "module": "my-module"
}
```

To display the full configuration model of a `jb` project, run the `show` task.

Example:

```yaml
######################## Full jb configuration ########################

### For more information, visit https://github.com/renatoathaydes/jb

# Maven artifact groupId
group: "com.athaydes"
# Module name (Maven artifactId)
module: "example"
# Human readable name of this project
name: null
# Maven version
version: "0.0.0"
# Description for this project
description: null
# URL of this project
url: null
# Licenses this project uses
licenses: []
# Developers who have contributed to this project
developers: []
# Source control management
scm: null
# List of source directories
source-dirs: ["src"]
# List of resource directories (assets)
resource-dirs: ["resources"]
# Output directory (class files)
output-dir: null
# Output jar (may be used instead of output-dir)
output-jar: "build/example.jar"
# Java Main class name
main-class: "com.athaydes.example.Main"
# Manifest file to include in the jar
manifest: null
# Java Compiler arguments
javac-args: []
# Java Compiler environment variables
javac-env: {}
# Java Runtime arguments
run-java-args: []
# Java Runtime environment variables
run-java-env: {}
# Java Test run arguments
test-java-args: []
# Java Test environment variables
test-java-env: {}
# Maven repositories (URLs or directories)
repositories: []
# Maven dependencies
dependencies: {}
# Dependency exclusions (regular expressions)
dependency-exclusion-patterns: []
# Annotation processor Maven dependencies
processor-dependencies: {}
# Annotation processor dependency exclusions (regular expressions)
processor-dependency-exclusion-patterns: []
# Compile-time libs output dir
compile-libs-dir: "build/compile-libs"
# Runtime libs output dir
runtime-libs-dir: "build/runtime-libs"
# Test reports output dir
test-reports-dir: "build/test-reports"
# jb extension project path (for custom tasks)
extension-project: null
```

The [Configuration Reference](#reference) section below explains in more detail what each of these fields mean and how to use them.

<div id="properties"></div>

## Properties

The `properties` value is a Map which can be used for declaring properties.

Example:

```yaml
properties:
    versions:
        jbuild: 0.10.1
        java: 11
        junit: 5.9.1
        assertj: 3.23.1
```

Properties can be used anywhere in a config file using double-curly-braces to refer to them.

Example:

```yaml
javac-args: [ "--release={{versions.java}}" ]

dependencies:
  "org.junit.jupiter:junit-jupiter-api:{{versions.junit}}":
  "org.junit.jupiter:junit-jupiter-params:{{versions.junit}}":
  "org.assertj:assertj-core:{{versions.assertj}}":
```

<div id="imports"></div>

## Imports

The `imports` value is a list of other YAML or JSON files to be imported into the current one.

When a config file is imported, it gets _merged_ with it, and `jb` sees only the result of that merge.

Example:

```yaml
imports:
    - "../../build_properties.yaml"
```

A common usage of imports is to allow declaring all dependencies versions used across various sub-projects in a single place.

Check the [JBuild Tests](https://github.com/renatoathaydes/jbuild/blob/master/src/test/jbuild.yaml) config for a real example.

<div id="publishing"></div>

## Publishing to a Maven Repository

To be able to publish to a Maven Repository, the following fields must be configured properly:

* [group](#group)
* [module](#module)
* [name](#name)
* [version](#version)
* [description](#description)
* [developers](#developers)
* [scm](#scm)
* [licenses](#licenses)
* [url](#url)

Once all of the above fields have proper values, you can publish with `jb publish :-m` (Sonatype Maven Central)
or `jb publish :-n` (Sonatype Legacy Repository, use this if your domain was registered before the transition to the newer repo).

Running `jb publish` without any argument publishes to Maven Local at `~/.m2/repository`.

Any other argument is treated as a destination directory or a http(s) URL.

<div id="reference"></div>

## Configuration Reference

<a id="group" href="#group">group</a>

A project group ID. This is normally used to group associated projects together and for the published artifact metadata.

> Refer to the [Maven Documentation](https://maven.apache.org/guides/mini/guide-naming-conventions.html) for the expected conventions
> regarding Maven repositories metadata.

Example: `com.athaydes.jbuild`.

<a id="module" href="#module">module</a>

The artifact ID. This is the main identifier of a published artifact.

Example: `jbuild`.

<a id="name" href="#name">name</a>

Human-readable name of the project.

Example: `JBuild`.

<a id="version" href="#version">version</a>

The version of this artifact. It is advisable that [Semantic Versioning](https://semver.org/) should be used.

As a project evolves, new versions of it may be published on a repository and then used by other projects as dependencies.

Example: `1.2.3`

<a id="description" href="#description">description</a>

A brief description of what the artifact does.

Example: `Java CLI and Library for building and analysing Java projects.`.

<a id="url" href="#url">url</a>

Project URL. Normally the Documentation Website.

Example: https://renatoathaydes.github.io/dartle-website/

<a id="licenses" href="#licenses">licenses</a>

List of licenses this artifact is published under.
Each string in the list must be a license identifier from [SPDX](https://spdx.org/licenses/).

The allowed license identifiers are updated from the SPDX API on every release.

Example: `["Apache-2.0", "CC0-1.0"]`

<a id="developers" href="#developers">developers</a>

List of Developer objects including the main developers working on the project.

> Only used by jb to include it in generated Maven POMs.

Example:

```yaml
developers:
    - name: Joe Doe
      email: joe.doe@example.org
      organization: ACME Co.
      organization-url: https://example.org
```

<a id="scm" href="#scm">scm</a>

Source Control Management specification.

> Only used by jb to include it in generated Maven POMs.

Example:

```yaml
scm:
    connection: https://github.com/renatoathaydes/jb.git
    developer-connection: https://github.com/renatoathaydes/jb.git
    url: https://github.com/renatoathaydes/jb
```

<a id="source-dirs" href="#source-dirs">source-dirs</a>

The directories where source files can be found.

Defaults to `["src"]`.

Example:

```yaml
source-dirs: ["src/main/java", "src/test/java"]
```

<a id="resource-dirs" href="#resource-dirs">resource-dirs</a>

The directories where files that should be included in the jar, but are not source files, can be found.

Defaults to `[resources]`.

Example:

```yaml
resourde-dirs: ["src/main/resources"]
```

<a id="output-dir" href="#output-dir">output-dir</a>

The directory where the build output (usually the compiled class files) should be written to.

> This option is mutually exclusive with `output-jar`. If this option is used, no jar will be produced.

Example:

```yaml
output-dir: build
```

<a id="output-jar" href="#output-jar">output-jar</a>

The path to the jar to be produced by the build.

> This option is mutually exclusive with `output-dir`. If this option is used, class files will be first written
> to a temporary directory, and then archived in the jar.

Example:

```yaml
output-jar: build/lib.jar
```

<a id="main-class" href="#main-class">main-class</a>

The name of the main class in this project.

The main class is the class that can be run with the `java` command.
`jb` will include `Main-Class` in the generated MANIFEST.MF file, which means that the produced jar will be runnable,
for example with this command:

```shell
java -cp "build/runtime-libs/*" -jar build/lib.jar
```

Example:

```yaml
main-class: org.example.Main
```

<a id="manifest" href="#manifest">manifest</a>

The location of a MANIFEST text file to be passed to the `jar` command when creating a jar.
The file may contain any directives allowed by the [Java Manifest Format](https://docs.oracle.com/javase/tutorial/deployment/jar/manifestindex.html).

Example:

```yaml
manifest: meta/manifest.txt
```

<a id="javac-args" href="#javac-args">javac-args</a>

Java compiler arguments.

`jb` passes various arguments to `javac` based on the configuration of the project. However, you may want to pass further arguments
as necessary.

To see which options `jb` is already including, run `jb compile -l debug`.

Example:

```yaml
javac-args: ["--release=11"]
```

<a id="javac-env" href="#javac-env">javac-env</a>

Deprecated.

<a id="run-java-args" href="#run-java-args">run-java-args</a>

Java runtime arguments.

Used by the `run` task only.

Example:

```yaml
run-java-args: ["-Xmx128m"]
```

<a id="run-java-env" href="#run-java-env">run-java-env</a>

Deprecated.

<a id="test-java-args" href="#test-java-args">test-java-args</a>

Arguments to be passed to the `java` command when executing tests with the `test` task.

Example:

```yaml
test-java-args
  - "-Dtests.repo.dir=resources/jbuild/commands/repo"
```

<a id="test-java-env" href="#test-java-env">test-java-env</a>

Deprecated.

<a id="repositories" href="#repositories">repositories</a>

The repositories to use when resolving dependencies.

By default, Maven Central and Maven Local (`~/.mvn/repository`) are used.

Example:

```yaml
repositories:
    - https://maven.repository.redhat.com/ga/
    - https://repo1.maven.org/maven2/
```

<a id="dependencies" href="#dependencies">dependencies</a>

The artifact dependencies of the project.

Dependencies use the notation `<group>:<module>:<version>` and may have the following attributes:

- `transitive`: `true` or `false` - whether to include transitive dependencies or only the single artifact.
- `scope`: one of:
  * `all` - the default, include dependency both at compile time and at runtime.
  * `compile-only` - only include the depenency when compiling.
  * `runtime-only` - only include the dependency at runtime.
- `path`: path to a local jar or another `jb` project. This is recommended only for local development.

Example:

```yaml
dependencies:
    org.slf4j:slf4j-api:2.0.16:
    com.google.guava:guava:33.4.0-jre:
        transitive: false
        scope: all
```

<a id="dependency-exclusion-patterns" href="#dependency-exclusion-patterns">dependency-exclusion-patterns</a>

Regular expressions for excluding specific transitive dependencies from the classpath.

The patterns should match against dependencies specifications, not file names.

Example:

```yaml
dependency-exclusion-patterns:
    - com.google.errorprone.*
```

<a id="processor-dependencies" href="#processor-dependencies">processor-dependencies</a>

Dependencies for Java annotation processors.

Example:

```yaml
processor-dependencies:
    com.google.errorprone:error_prone_core:2.16:
```

<a id="processor-dependency-exclusion-patterns" href="#processor-dependency-exclusion-patterns">processor-dependency-exclusion-patterns</a>

Similar to `dependency-exclusion-patterns` above, but for annotation processor dependencies.

<a id="compile-libs-dir" href="#compile-libs-dir">compile-libs-dir</a>

The directory to use for compile-time dependencies.

Defaults to `build/compile-libs`.

Example: `target/libs`.

<a id="runtime-libs-dir" href="#runtime-libs-dir">runtime-libs-dir</a>

The directory to use for compile-time dependencies.

Defaults to `build/runtime-libs`.

Example: `target/runtime`.

<a id="test-reports-dir" href="#test-reports-dir">test-reports-dir</a>

The directory to use for testing framework's reports.

Defaults to `build/test-reports`.

Example: `target/test-reports`.

<a id="extension-project" href="#extension-project">extension-project</a>

The path to a jar containing a `jb` extension, or to a local directory containing a `jb` project which is a `jb` extension.

{{ define extensions path["extensions.md"] }}
See [{{ eval extensions.name }}]({{ eval extensions.path }}).

> WARNING: this may be changed to become an array in the future.

Example: `jb-extensions/my-extension`.


{{ end }}
{{ include /processed/fragments/_footer.html }}
