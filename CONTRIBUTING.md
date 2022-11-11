# `jb` Contributing Guide

Thanks for considering contributing to `jb`!

I hope you find the source code well organized and easy to work with.

The `jb` source is mostly written in Dart, but all the _low level_ work is done by [JBuild](https://github.com/renatoathaydes/jbuild/),
which is written in Java.

Here's a little more detail about what `jb` does, and what `JBuild` does:

`jb`:

* defines and uses the `jbuild.yaml` file.
* embeds the JBuild jar and keeps it up-to-date.
* executes tasks by invoking JBuild.
* caches tasks' inputs/outputs, so it can skip tasks if no changes are detected.
* determines defaults that make sense for a build system similar to Maven.
* introduces sub-projects via dependencies on other `jb` projects.

`JBuild`:

* handles Maven dependencies.
* compiles and packages Java code by invoking the JDK's [`java.util.spi.ToolProvider`](https://docs.oracle.com/en/java/javase/19/docs/api/java.base/java/util/spi/ToolProvider.html).
* parses class files and jar's contents to analyze code interdependencies.

## Source organization

As with most Dart projects, the main file is located at [bin/](bin/jbuild_cli.dart), and other code is at the [lib/](lib/)
directory.

The `jbuild.yaml` config file model is at [config.dart](lib/src/config.dart), which uses [Freezed](https://pub.dev/packages/freezed)
for Dart data-class and union-type support.

The CLI options are defined in [options.dart](lib/src/options.dart).

CLI commands (or tasks) are defined in [tasks.dart](lib/src/tasks.dart).

The other file names are, similarly, fairly obvious, I hope.

Tests are located at the [test/](test) directory. The [test-projects/](test/test-projects) directory contains some
test Java projects.

## Building `jb`

`jb` uses [Dartle](https://github.com/renatoathaydes/dartle) both as a build tool and as a library.

As such, the build is declared in the [dartle.dart](dartle.dart) file (with more code in the `dartle-src` dir).

To build the `jb` executable, you need:

* [Dart SDK](https://dart.dev/get-dart)
* [Dartle](https://github.com/renatoathaydes/dartle)

Once you've installed Dart, get Dartle by running:

```shell
dart pub global activate dartle
```

> Make sure to have the Pub installation directory (usually `~.pub-cache/bin`) in your `PATH`.

Now, to compile the executable:

```shell
dartle compile
```

This creates the executable at `build/bin/jb`.

To run the default tasks, including tests:

```shell
dartle
```

To see all Dartle tasks available:

```shell
dartle -s
```

Check the Dartle docs for more usage information.

## Updating the embedded jar

`jb` ships with an embedded JBuild jar to be able to do things (like downloading a newer JBuild jar from a Maven repo!)
out-of-the-box.

To update that jar, you need to:

* download the new `jbuild.jar` file or build it locally. 
* delete the [jbuild_jar.g.dart](lib/src/jbuild_jar.g.dart) file.
* compile `jb` again, but set the `JBUILD_HOME` env var to the directory where the `jbuild.jar` file is located.

Essentially:

```shell
# export JBUILD_HOME so the jb build can find it
export JBUILD_HOME=<some-dir>

# assuming jbuild-x-y-z.jar is in the working dir
cp jbuild-x-y-z.jar "$JBUILD_HOME/jbuild.jar"

# remove the current embedded jar
rm lib/src/jbuild_jar.g.dart

# build jb
dartle build
```

## Publishing

To publish `jb` to [pub.dev](https://pub.dev/):

```shell
dart pub publish
```

TODO: website
