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

The `jbuild.yaml` config file model is at [config.dart](lib/src/config.dart).

The CLI options are defined in [options.dart](lib/src/options.dart).

CLI commands (or tasks) are defined in [tasks.dart](lib/src/tasks.dart).

The other file names are, similarly, fairly obvious, I hope.

Tests are located at the [test/](test) directory. The [test-projects/](test/test-projects) directory contains some
test Java projects.

## Building `jb`

`jb` uses [Dartle](https://github.com/renatoathaydes/dartle) both as a build tool and as a library.

As such, the build script is declared in the [dartle.dart](dartle.dart) file (with more build code in the `dartle-src` dir).

To build the `jb` executable, you need:

* [Dart SDK](https://dart.dev/get-dart)
* [Dartle](https://github.com/renatoathaydes/dartle)
* [JDK 11+](https://openjdk.org/) (only required to run `jb` itself and the tests)

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
* set the contents of [jbuild_jar.g.dart](lib/src/jbuild_jar.g.dart) to `const jbuildJarB64 = '';` (can be done by `dartle empty`).
* compile `jb` again with the `JBUILD_HOME` env var set to the directory where the `jbuild.jar` file is located.

Essentially:

```shell
# export JBUILD_HOME so the jb build can find it
export JBUILD_HOME=<some-dir>

# assuming jbuild-x-y-z.jar is in the working dir
cp jbuild-x-y-z.jar "$JBUILD_HOME/jbuild.jar"

# empty the contents of the current embedded jar
dartle emptyGeneratedAssets

# build jb
dartle build
```

## Updating the SPDX licenses list

`jb` uses [the SPDX licenses list](https://spdx.org/licenses/) to validate license IDs in the config files,
as well as to generate Maven metadata for publishing.

To re-generate the list in `[licenses.g.dart](lib/src/licenses.g.dart)`, delete this file and build again.

The `generateLicenses` Dartle task will download the licenses list and create the file again automatically.

## Updating the configuration model

The `jb` configuration model is defined using [Schemake](https://pub.dev/packages/schemake).
The definition can be found at [jb_config_schema.dart](dartle-src/config/jb_config_schema.dart).

If you change that file, you will need to re-run the `generateJbConfigModel` task:

```shell
dartle generateJbConfigModel
```

> A JSON Schema is created at [jb-schema.json](website/source/static/schemas/jb-schema.json).

## Publishing

To publish `jb` to [pub.dev](https://pub.dev/):

```shell
dart pub publish
```

TODO: website

## Making Pull Requests

Bug fixes are welcome at any time!

Please file an issue before contributing/working on new features.

The only branch used for development, currently, is `main`, so target pull requests at it.

I appreciate if changes are kept small and to-the-point, and come with tests proving they work.
