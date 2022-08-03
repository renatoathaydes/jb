# JBuild CLI

The [JBuild](https://github.com/renatoathaydes/jbuild) CLI.

JBuild is a Java build system written in Java. This is JBuild's CLI, which is a wrapper around JBuild that uses a
YAML configuration file to control JBuild's command and inputs/outputs.

The [Dartle Task Runner](https://github.com/renatoathaydes/dartle/) is used to make sure that only work that needs to be
done is actually done on each invocation. Previous work is "remembered" and skipped whenever possible.
