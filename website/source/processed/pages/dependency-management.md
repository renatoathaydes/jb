{{ include /processed/fragments/_header.html }}\
{{ define name "Dependency Management" }}
{{ define path basePath + "/pages/dependency-management.html" }}
{{ define order 3 }}
{{ component /processed/fragments/_main.html }}
<div class="space-up"></div>
# Dependency Management

Dependency management is very simple in `jb`. This page explains how to manage dependencies in a `jb` project.

## Adding a dependency

To add a dependency to your project, add an entry in the [`dependencies`](config.html#dependencies) configuration section.

For example, to use Google Guava:

```yaml
dependencies:
    com.google.guava:guava:33.4.0-jre:
```

Notice that each entry in `dependencies` needs to end with a colon (`:`), because the entry may declare optional attributes:

* `path` - for a local dependency, the path to a jar or directory containing another `jb` project.
* `transitive` - whether to include transitive dependencies of the artifact.
* `scope` - one of `compile-only`, `runtime-only` or `all` (which is the default).

As an example of using dependency attributes, consider configuring `slf4j` and a logging provider, say `log4j`.

The dependencies may look like this:

```yaml
dependencies:
    # SFL4J Logging API
    org.slf4j:slf4j-api:2.0.16:
    # Use the Log4j2 Provider for SLF4J
    org.apache.logging.log4j:log4j-slf4j2-impl:2.19.0:
        scope: runtime-only
    org.apache.logging.log4j:log4j-core:2.24.3:
        scope: runtime-only
```

Conflicts are not automatically resolved, but it's easy to find and fix one when it happens.

### Resolving conflicts

With the example above, there's already a few dependency version conflicts, as you can see by running `jb dep`:

<iframe src="{{ eval basePath }}/jb-deps.html" style="width: 100%;height: 27em;"></iframe>

As you can see, `log4j2-core` (all modules are the latest versions as of writing) depends on `log4j2-api` version `2.24.3`,
but the latest version of `log4j-slf4j2-impl` still depends on version `2.19.0`.

Similarly, while the project wants to use `slf4j-api` version `2.0.16`, `log4j-slf4j2-impl` requires that module with version `2.0.0`.

The problem is clearly that `log4j-slf4j2-impl` is not kept up-to-date. We can fix that in a couple of ways.

First, you can just make `log4j-slf4j2-impl` a non-transitive dependency:

```yaml
dependencies:
    # SFL4J Logging API
    org.slf4j:slf4j-api:2.0.16:
    # Use the Log4j2 Provider for SLF4J
    org.apache.logging.log4j:log4j-slf4j2-impl:2.19.0:
        scope: runtime-only
        transitive: false # <<-------
    org.apache.logging.log4j:log4j-core:2.24.3:
        scope: runtime-only
```

This works, and running `jb dep` again shows that there's no more conflicts:

<iframe src="{{ eval basePath }}/jb-deps-fixed.html" style="width: 100%;height: 20em;"></iframe>

In this case, this may be the best approach. But there are cases where doing this would be less maintainable.
On every update, you could run into problems if the non-transitive dependency added new dependencies (which may be a good thing
as that would _alert_ you that your project also has a new dependency).

If that's not desirable, you can try to exclude the exact transitive dependencies that are problematic:

```yaml
dependencies:
    # SFL4J Logging API
    org.slf4j:slf4j-api:2.0.16:
    # Use the Log4j2 Provider for SLF4J
    org.apache.logging.log4j:log4j-slf4j2-impl:2.19.0:
        scope: runtime-only
        exclusions: [".*:log4j-api:.*", ".*:slf4j-api:.*"] # <<------
    org.apache.logging.log4j:log4j-core:2.24.3:
        scope: runtime-only
```

This has the same effect as before. The downside is that you need to re-calculate the exclusion patterns every time you update
your dependencies. However, doing so as shown above shouldn't take more than a few minutes.

## Annotation Processor dependencies

Besides `dependencies`, `jb` also has `processor-dependencies`, which is where you declare dependencies for annotation processors
you may run at compile-time.

Similarly, there's also `processor-dependency-exclusion-patterns` for excluding transitive dependencies from the annotation processor's
classpath.

The `jb` repository has [an example](https://github.com/renatoathaydes/jb/tree/main/example/error-prone-java-project)
configuring the [ErrorProne](https://errorprone.info/) annotation processor.

## Local dependencies

Normally, dependencies are downloaded from a Maven repository (see [repositories](config.html#repositories)).
But `jb` also supports depending on a local jar or on another `jb` project.

In either case, all you have to do is specify the `path` attribute of the dependency, as shown below:

```yaml
dependencies:
    main-project:
        path: ../main
```

This is very common, for example, in test projects, which depend on the _main project_.

> Notice that if the `path` points to a directory, the directory is expected to be a `jb` project.
> If it's a file, then it's assumed to be a jar.

See the [JBuild unit test config](https://github.com/renatoathaydes/jbuild/blob/master/src/test/jbuild.yaml) itself for a good example.

## Test Dependencies

In `jb`, there are no test dependencies, only test projects. Test projects are simply `jb` projects that depend on one of the supported Testing Frameworks.

For example, a project depending on `org.junit.jupiter:junit-jupiter-api` directly is assumed to be a JUnit Test module,
and the `test` task will execute any tests found by the JUnit5 engine.

A common pattern is to have the main project at the _root directory_, and the test project at `test/`:

```
├── jbuild.yaml
├── src
│   └── com
│       └── athaydes
│           └── example
│               └── Main.java
└── test
    ├── jbuild.yaml
    └── src
        └── com
            └── athaydes
                └── example
                    └── MainTest.java
```

> Notice how there's a `jbuild.yaml` file at `./` and `./test/`.

This allows compiling and running tests very easily:

```shell
# compile the main project
$ jb

# run the tests
$ jb -p test test
```

You can have several test directories for different kinds of tests, for example, `int-test`, `ext-test` and so on.

Then, running them becomes very easy:

```shell
# run unit tests
$ jb -p test test

# run integration tests
$ jb -p int-test test
```

{{ end }}
{{ include /processed/fragments/_footer.html }}
