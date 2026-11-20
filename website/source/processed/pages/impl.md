{{ include /processed/fragments/_header.html }}\
{{ define name "Implementation Details" }}
{{ define path basePath + "/pages/impl.html" }}
{{ define order 1 }}
{{ component /processed/fragments/_main.html }}
<div class="space-up"></div>

# jb implementation details

## Overview

`jb` is, in essence, a task runner (provided by [dartle](https://renatoathaydes.github.io/dartle-website/))
with built-in tasks designed to build Java-based projects. It also has an extension mechanism that allows
users to write their own tasks in Java or other JVM languages.

This page explains in detail what each built-in task does, how they do it.

> The information provided in this page is not necessary for daily usage of jb.
> It is provided to help debugging issues and help jb contributors and advanced users understand how everything works.

## jb Tasks

_Setup Phase_:

* [`clean`](#clean)
* [`checkJavaVersion`](#checkJavaVersion)
* [`showJbConfiguration`](#showJbConfiguration)
* [`updateJBuild`](#updateJBuild)

_Deps Phase_:

* [`writeDependencies`](#writeDependencies)
* [`verifyDependencies`](#verifyDependencies)
* [`dependencies`](#dependencies)
* [`downloadDependenciesChecksums`](#downloadDependenciesChecksums)

_Build Phase_:

* [`createJavaCompilationPath`](#createJavaCompilationPath)
* [`createJavaRuntimePath`](#createJavaRuntimePath)
* [`installCompileDependencies`](#installCompileDependencies)
* [`installRuntimeDependencies`](#installRuntimeDependencies)
* [`installProcessorDependencies`](#installProcessorDependencies)
* [`installGroovydocsRuntime`](#installGroovydocsRuntime)
* [`compile`](#compile)
* [`downloadTestRunner`](#downloadTestRunner)
* [`publicationCompile`](#publicationCompile)
* [`requirements`](#requirements)
* [`createEclipseFiles`](#createEclipseFiles)

_Evaluate Phase_:

* [`test`](#test)
* [`runJavaMainClass`](#runJavaMainClass)
* [`jshell`](#jshell)

_Publish Phase_:

* [`generatePom`](#generatePom)
* [`publish`](#publish)

### clean
<div id="clean"></div>

Deletes the outputs of all other tasks.

Phase: `Setup`
Depends on: none

This task is implemented by `Dartle`.

### checkJavaVersion
<div id="checkJavaVersion"></div>

Check if the Java executable has the same version as in the previous build.

Phase: `Setup`
Depends on: none

### writeDependencies
<div id="writeDependencies"></div>

Write resolved dependencies files.

Phase: `Deps`
Depends on: none

This task reads the jb config to find the project's dependencies, then asks JBuild to resolve transitive dependencies.
The result is written to a JSON file.

It does that for each group of dependencies:

| Group                             | JSON output                               |
|-----------------------------------|-------------------------------------------|
| Main dependencies                 | `.jb-cache/dependencies.json`             |
| Annotation processor dependencies | `.jb-cache/processor-dependencies.json`   |
| Test runner dependencies          | `.jb-cache/test-runner-dependencies.json` |

> All of the above files are always created, even if the project does not have main/processor/test dependencies.

To figure out the test runner dependencies, this task tries to find out which Testing Framework is used by the project.

If it finds a dependency on an artifact with group `org.junit.platform`, or the `org.spockframework:spock-core` artifact,
it will use the following test runner artifact:

```
org.junit.platform:junit-platform-console-standalone
```

The version used for the above artifact is the same as the version of the `org.junit.platform` artifact, or `LATEST` if the version
was not found.

An actor called `_DepsCacheHandler` is used to read/write the dependencies files and cache the dependencies in
memory for subsequent tasks.

### verifyDependencies
<div id="verifyDependencies"></div>

Fails the build if dependency version conflicts are detected.

Phase: `Deps`
Depends on: [`writeDependencies`](#writeDependencies)

This task reads the dependencies files created by `writeDependencies` and checks if there's any version conflict between
dependencies.
The file should always exist, since this task depends on the task that writes it. If
`writeDependencies` has run on the same build, the `_DepsCacheHandler` actor will already have the dependencies in memory,
so it does not need to read the dependencies file. Otherwise (i.e. if the previous task had run in a previous build),
the actor reads the dependencies file.

### dependencies
<div id="dependencies"></div>

Shows information about project dependencies.

Phase: `Deps`
Depends on: [`writeDependencies`](#writeDependencies)

The `_DepsCacheHandler` actor is used to get dependencies from memory (if `writeDependencies` has run in the same build)
or parse the dependencies files.

The `_JBuildDepsPrinter` class is used to print the dependency graph.

### downloadDependenciesChecksums
<div id="downloadDependenciesChecksums"></div>

Downloads dependencies checksums.

Phase: `Deps`
Depends on: [`verifyDependencies`](#verifyDependencies)

### createJavaCompilationPath
<div id="createJavaCompilationPath"></div>

Computes the Java compile classpath and modulepath.

Phase: `Build`
Depends on: [`installCompileDependencies`](#installCompileDependencies)

This task looks at the jars in the `compile-libs` directory, which is created by the
[installCompileDependencies](#installCompileDependencies) task. It then asks JBuild to
output information about each jar with the `module` command so `jb` will know everything
it needs to know about the jar:

* whether it's a module, and if so, whether it's an automatic module, its name, requirements, etc.
* Java bytecode version (i.e. minimum required JVM runtime).

The `_CompilePathsHandler` actor is used to keep all information about the compilation path.
It writes the compilation path to the file `.jb-cache/compilation-path.json`.

The compilation path is used by the [compile](#compile) task later.

### createJavaRuntimePath
<div id="createJavaRuntimePath"></div>

Computes the Java runtime classpath and modulepath.

Phase: `Build`
Depends on: [`installRuntimeDependencies`](#installRuntimeDependencies)

This task is implemented exactly as [createJavaCompilationPath](#createJavaCompilationPath),
but instead of looking at the `compile-libs`, it looks at the `runtime-libs`, and instead of writing to the file
`.jb-cache/compilation-path.json`, it writes to file `.jb-cache/runtime-path.json`.

The Java runtime path is used by the [runJavaMainClass](#runJavaMainClass) task later. 

### installCompileDependencies
<div id="installCompileDependencies"></div>

Install `compile` scoped dependencies.

Phase: `Build`
Depends on: [`verifyDependencies`](#verifyDependencies)

By default, dependencies are installed in the configured libs
directory (given by `compile-libs-dir`) and also on Maven Local.
This is done so that dependencies are globally cached on Maven Local as they are retrieved.
Notice that if the dependency was found in Maven Local, JBuild is smart enough to not write back to it.

> To disable Maven Local, set the `JB_INSTALL_TO_MAVEN_LOCAL` env var to `false`.

Information about non-local dependencies is obtained from the data created by [`writeDependencies`](#writeDependencies),
then JBuild is asked to install all dependencies on the libs directory.

For local dependencies (i.e. those which define a `path`), their output is copied directly into the libs
directory.

### installRuntimeDependencies
<div id="installRuntimeDependencies"></div>

Install `runtime` scoped dependencies.

Phase: `Build`
Depends on: [`verifyDependencies`](#verifyDependencies), [`compile`](#compile)

This task is implemented exactly as [installCompileDependencies](#installCompileDependencies),
except that all dependencies that are scoped for the runtime are installed, and the installation directory
is given by `runtime-libs-dir`.

### installProcessorDependencies
<div id="installProcessorDependencies"></div>

Install the Java annotation processor dependencies.

Phase: `Build`
Depends on: [`verifyDependencies`](#verifyDependencies), [`compile`](#compile)

This task is implemented exactly as [installCompileDependencies](#installCompileDependencies),
except that dependencies come from the `processor-dependencies` configuration, not `dependencies`,
all dependencies that are scoped for the runtime are installed, and the installation directory
is `.jb-cache/processor-dependencies`.

### installGroovydocsRuntime
<div id="installGroovydocsRuntime"></div>

Install the Groovydocs runtime dependencies.

Phase: `Build`
Depends on: [`verifyDependencies`](#verifyDependencies), [`compile`](#compile)

This task is implemented exactly as [installCompileDependencies](#installCompileDependencies),
except that dependencies come from the `groovydocs-runtime-dependencies` configuration, not `dependencies`,
all dependencies that are scoped for the runtime are installed, and the installation directory
is `.jb-cache/groovydocs-runtime-dependencies`.

This task is executed automatically when publishing Groovy libraries, to generate the `groovydocs` jar.

### compile
<div id="compile"></div>

Compile Java source code.

Phase: `Build`
Depends on: [`createJavaCompilationPath`](#createJavaCompilationPath), [`installProcessorDependencies`](#installProcessorDependencies)

While the main goal of this task is to compile source code, this task does a few other things as well.

First of all, it computes all changes since the last build. To do that, it maintains a source file tree which contains
interdependencies between the source files. That means that when a source file is changed, not only that source file will
be re-compiled, but also all other files that depended on the modified file in the last build.

> The source tree is created by calling JBuild's `requirements` command after every build. That is why
  in the next build, the source tree will be available.

Once that's done, the compilation path generated by [createJavaCompilationPath](#createJavaCompilationPath)
is used to invoke the Java compiler via JBuild. See the `compileCommand` function for details.

Finally, a new source tree is generated for the next build.

### updateJBuild
<div id="updateJBuild"></div>

Updates the JBuild jar used by jb.

Phase: `Setup`
Depends on: none

### downloadTestRunner
<div id="downloadTestRunner"></div>

Download a test runner. JBuild automatically detects [JUnit](https://junit.org/).

Phase: `Build`
Depends on: none

This task reads the test dependencies file created by [writeDependencies](#writeDependencies),
which contains the test runner to use for this project, if any, and then downloads
the required artifacts to the directory `.jb-cache/test-runner`.

This task also validates that the test configuration exists (hence, it should only run when this project has tests).

### publicationCompile
<div id="publicationCompile"></div>

Compile Java source code, javadocs (or groovydocs) and sources jar.

Phase: `Build`
Depends on: [`compile`](#compile), [`installProcessorDependencies`](#installProcessorDependencies), [`installGroovydocsRuntime`](#installGroovydocsRuntime)

### test
<div id="test"></div>

Run tests. JBuild automatically detects the JUnit and Spock frameworks.

Phase: `Evaluate`
Depends on: [`compile`](#compile), [`downloadTestRunner`](#downloadTestRunner), [`installRuntimeDependencies`](#installRuntimeDependencies)

If a project does not depend on the JUnit or Spock APIs, this task fails as it cannot execute tests.
Otherwise, it invokes the respective test runner to run the tests.

### runJavaMainClass
<div id="runJavaMainClass"></div>

Run the project's main class.

Phase: `Evaluate`
Depends on: [`compile`](#compile), [`createJavaRuntimePath`](#createJavaRuntimePath)

Task arguments are passed to the Java class.

This task fails unless a `main-class` setting has been configured.

### jshell
<div id="jshell"></div>

Start `jshell` with the project's runtime classpath loaded.

Phase: `Evaluate`
Depends on: [`compile`](#compile), [`installRuntimeDependencies`](#installRuntimeDependencies)

This task allows quick experimentation with Java code in a REPL.
`jb` will watch the project sources while the REPL is running, re-compiling as
necessary.

Use `/reset` to hot-reload the classpath into the REPL.

Task arguments are passed to jshell.

### showJbConfiguration
<div id="showJbConfiguration"></div>

Shows the fully resolved jb configuration.

Phase: `Setup`
Depends on: none

### requirements
<div id="requirements"></div>

Shows information about project requirements.

Phase: `Build`
Depends on: [`compile`](#compile)

By default, this task shows the external Java classes required by the project. These are the
classes provided by dependencies, not by the project's own source code.

The `:-c` option can be used to show requirements, including internal ones, for each individual class in this project.

### createEclipseFiles
<div id="createEclipseFiles"></div>

Generate Eclipse IDE files for the project.

Phase: `Build`
Depends on: [`installCompileDependencies`](#installCompileDependencies)

**This task is experimental**.

### generatePom
<div id="generatePom"></div>

Generate a Maven POM for publishing the project.

Phase: `Publish`
Depends on: [`writeDependencies`](#writeDependencies)

### publish
<div id="publish"></div>

Publish project to a Maven repository (Maven local by default).

Phase: `Publish`
Depends on: [`writeDependencies`](#writeDependencies)

Files are signed, if enabled, using `gpg`.

The following arguments may be provided:
    - local dir or http(s) URL.
    - `-m` for Maven Central.
    - `--no-sign` to skip signing artifacts.

Environment variables:
    - `MAVEN_LOCAL_HOME` - location of the local Maven home.
    - `SONATYPE_PORTAL_TOKEN_XML_FILE` - location of the Sonatype portal token XML file.
    - `GPG_COMMAND` - which command to use to invoke `gpg`.
