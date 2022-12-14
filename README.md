# `jb` - Java Builder

![jb-CI](https://github.com/renatoathaydes/jb/workflows/jb-CI/badge.svg)
[![pub package](https://img.shields.io/pub/v/jb.svg)](https://pub.dev/packages/jb)

`jb` is a modern (2020's era) build tool for Java.

It aims to simplify Java project management and provide an excellent developer experience by being much simpler
than Maven or Gradle, while still providing enough flexibility for most projects to achieve complex workflows.

## Using `jb`

To create a new Java project, run:

```shell
jb create
```

This creates a `jb` project with two modules, one at the working dir (or the directory given by the `-p` option),
and one in the `test` directory (optionally).

Each module has a `jbuild.yaml` file describing it. `./jbuild.yaml` looks like this:

```yaml
group: my-group
module: my-app
version: '0.0.0'

# default is src/main/java
source-dirs: [ src ]

# default is src/main/resources
resource-dirs: [ resources ]
# The following options use the default values and could be omitted
compile-libs-dir: build/compile-libs
runtime-libs-dir: build/runtime-libs
test-reports-dir: build/test-reports

# Specify a jar to package this project into.
# Use `output-dir` instead to keep class files unpacked.
# default is `build/<project-dir>.jar`.
output-jar: build/my-app.jar

# To be able to use the 'run' task without arguments, specify the main-class to run.
# You can also run any class by invoking `jb run :--main-class=some.other.Class`.
main-class: my_group.my_app.Main

# dependencies can be Maven artifacts or other jb projects
dependencies:
```

The `test` module is just a `jb` project which depends on a supported testing library API, and contains tests.

This is what `test/jbuild.yaml` looks like, with most optional fields omitted:

```yaml
group: my-group
module: tests
version: '0.0.0'

# default is src/main/java
source-dirs: [ src ]

# default is src/main/resources
resource-dirs: [ resources ]

# do not create a redundant jar for tests
output-dir: build/classes

# dependencies can be Maven artifacts or other jb projects
dependencies:
  - org.junit.jupiter:junit-jupiter-api:5.8.2
  - org.assertj:assertj-core:3.22.0
  - core-module:
      path: ../
```

Some very basic Java code and a test are added as well.

To compile the main module:

```shell
jb compile
```

This should create a jar file at `./build/my-app.jar`.

As the basic Java class `jb` creates has a main method, you can run it with:

```shell
jb run
```

> To pass arguments to the Main class, you can prepend the arguments with `:`
> (without that, arguments are passed to `jb` itself).
> For example, to pass `-h` to the Main class, run `jb run :-h`.

Or using `java` directly:

```shell
java -jar build/my-app.jar
```

> Once you add dependencies to your project, it's still trivial to run it with `java`, as `jb` puts all the runtime
> libraries at the `build/runtime` directory by default, so just pass `-cp "build/runtime/*"` to Java after
> building the project with `jb compile installRuntime`.

To run the tests:

```shell
jb -p test test

# or
cd test
jb test
```

To show help or information about the build:

```shell
# show the help message
jb -h

# show task information, including what tasks would be executed
jb -s     # or e.g. 'jb -s run' to see which tasks 'run' would require 

# show a task dependency graph
jb -g
```

## Demo Project

A demo Java project (using the [Javalin Web Framework](https://javalin.io/)) is available in the
[example/sample-java-project](example/sample-java-project) directory.

## About `jb` (implementation)

This project is the [JBuild](https://github.com/renatoathaydes/jbuild) CLI front-end.

**JBuild** is a Java tool for managing Java dependencies, extracting information from existing jars/classpath and
compiling Java projects.

**`jb`** builds on JBuild to provide a modern developer environment, similar to other languages like
[Rust](https://www.rust-lang.org/) and [Dart](https://dart.dev/), whose great developer UX inspired `jb`.

[JUnit5](https://junit.org/junit5/) is used for executing Java tests.

> I hope to add support for other testing frameworks in the future, specially [Spock](https://spockframework.org/).
> If you want your favourite framework to be supported, create an issue or upvote an existing one
> ([Spock support issue](https://github.com/renatoathaydes/jb/issues/4))!

[Dart](https://dart.dev/) may look like a weird choice of language to write a Java build system... so I think it's
appropriate to explain the choice:

* it supports building small, native, fast executables that do not require a JVM to run.
* that makes it easier to avoid a common pitfall: tying the build system to certain version of the JDK.
* [Dartle](https://github.com/renatoathaydes/dartle/), the task runner behind `jb`, is written in Dart, by me.
* the possibility of writing a Flutter UI to manage `jb` projects in the future, which may be of great help to beginners.
* I find it very easy to write code in Dart, and enjoy using it.
