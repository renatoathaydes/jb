# `jb` - Java Builder

`jb` is a modern (circa 2020's) build tool for Java.

It aims to simplify Java project management and provide an excellent developer experience by being much simpler
than Maven or Gradle, while still providing enough flexibility for most projects to achieve complex workflows.

## Using `jb`

To create a new Java project, run:

```shell
jb create
```

This creates a JBuild project with two modules, one at the working dir (or the directory given by the `-p` option),
and one in the `test` directory (optionally).

Each module has a `jbuild.yaml` file describing it. `./jbuild.yaml` looks like this:

```yaml
group: my-group
module: my-app
version: '0.0.0'

source-dirs: [ src ]
compile-libs-dir: build/compile
runtime-libs-dir: build/runtime
output-jar: build/my-app.jar
main-class: my_group.my_app.Main

# dependencies can be Maven artifacts or other jb projects
dependencies:
```

The `test` module is just a `jb` project which depends on a supported testing library API, and contains tests.

This is what `test/jbuild.yaml` looks like:

```yaml
group: my-group
module: tests
version: '0.0.0'

source-dirs: [ src ]
compile-libs-dir: build/compile
runtime-libs-dir: build/runtime
output-jar: build/tests.jar

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

Or using `java` directly:

```shell
java -jar build/my-app.jar
```

> Once you add dependencies to your project, it's still trivial to run it as `jb` puts all the runtime libraries
> at the `build/runtime-libs` directory by default, so just use `-cp "build/runtime-libs/*"` to Java after building
> the project with `jb compile installRuntime`.

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

## Acknowledgements

This project is the [JBuild](https://github.com/renatoathaydes/jbuild) CLI front-end.

JBuild is a Java tool for managing Java dependencies, extracting information from existing jars/classpath and
compiling Java projects.

`jb` builds on JBuild to provide a modern developer environment, similar to other languages like
[Rust](https://www.rust-lang.org/) and [Dart](https://dart.dev/), whose great developer UX inspired `jb`.

[JUnit5](https://junit.org/junit5/) is used for Java tests.

> I hope to add support for other testing frameworks in the future, specially [Spock](https://spockframework.org/).
> If you want your favourite framework to be supported, create an issue!

[Dart](https://dart.dev/) was used to implement this project because:

* it supports building small, native executables that do not require a JVM to run.
* [Dartle](https://github.com/renatoathaydes/dartle/), the task runner behind `jb`, is written in Dart.
* the possibility of writing a Flutter UI to manage `jb` projects in the future.
* possibly adding support for build scripting in the future using Dart.
