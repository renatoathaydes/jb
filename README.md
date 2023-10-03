# `jb` - Java Builder

![jb-CI](https://github.com/renatoathaydes/jb/workflows/jb-CI/badge.svg)
[![pub package](https://img.shields.io/pub/v/jb.svg)](https://pub.dev/packages/jb)

`jb` is a modern build tool for Java that looks like what you would expect in the 2020's.

It aims to simplify Java project management and provide an excellent developer experience by being much simpler
than Maven or Gradle, while still providing enough flexibility for most projects to achieve complex workflows.

## Using `jb`

To create a new Java project, run:

```shell
jb create
```

This creates a `jb` project with two modules, one at the working dir (or the directory given by the `-p` option),
and one in the `test` directory (optionally).

Each module has a `jbuild.yaml` or `jbuild.json` build file describing it. The build file may look like this:

```yaml
group: my-group
module: my-app
version: '0.0.0'

# default is src
source-dirs: [ src ]

# default is resources
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
  - some.group:some.module:1.0.0
```

The `test` module is just a `jb` project which depends on a supported testing library API, and contains tests.

This is what `test/jbuild.yaml` looks like, with most optional fields omitted:

```yaml
group: my-group
module: tests
version: '0.0.0'

# default is src
source-dirs: [ src ]

# default is resources
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

> If you run `jb create` on an empty directory, a basic project with some Java code and a test module is created.

To compile the main module:

```shell
jb compile
```

In fact, because `compile` is the default task, you can just run:

```shell
jb
```

> Run `jb -s` to see all tasks in the build, and `jb -h` for help and listing all options.

This should create a jar file at `./build/my-app.jar`.

If your build file declares the `main-class`, you can ask `jb` to run it with:

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

To run the tests, point to the directory where the test project is with `-p`, and run the `test` task:

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

## Extending jb

To create your own tasks, first run `jb create` on a sub-directory of your root project and select `jb extension`
when asked about the project type.

A `jb` extension project consists of a regular `jb` project that has a dependency on `com.athaydes.jbuild:jbuild-api`,
and has one or more Java classes implementing `jbuild.api.JbTask`, which makes them tasks `jb` can execute.

The sample `JbTask` looks like this:

```java
package my_group.my_extension;

import jbuild.api.*;

@JbTaskInfo(name = "sample-task",
        description = "Prints a message to show this extension works.")
public final class ExampleTask implements JbTask {
    @Override
    public void run(String... args) throws IOException {
        System.out.println("Extension task running: " + getClass().getName());
    }
}
```

## Demo Project

A demo Java project (using the [Javalin Web Framework](https://javalin.io/)) is available in the
[example/javalin-http-server-sample](example/javalin-http-server-sample) directory.

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
