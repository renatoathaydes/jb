{{ include /processed/fragments/_header.html }}\
{{ define name "Getting Started" }}
{{ define path basePath + "/pages/get-started.html" }}
{{ define order 0 }}
{{ component /processed/fragments/_main.html }}
<div class="space-up"></div>

## Getting Started

To get started with `jb`, download the correct binary for your platform from [GitHub Releases](https://github.com/renatoathaydes/jb/releasesx).

> Pre-built binaries are available for Windows, Linux and MacOS (x86 and ARM).
> You can also easily build `jb` on any platform, check [`jb` on GitHub](https://github.com/renatoathaydes/jb) for details.

Create a directory for your project and then just run `jb create`, which will start an interactive CLI:

<iframe src="{{ eval basePath }}/jb-create.html" style="width: 100%;height: 20em;"></iframe>

That's it! The project structure looks like this (given the answers above):

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

Notice how the production source code is in `src/`, while the test source code is in `test/src`. You can configure that, of course.

Also notice that `test/` is a `jb` project (because it has a `jbuild.yaml` file in it)!
Unlike Maven or Gradle, `jb` does not have the notiion of multiple _groups of source code_ (`sourceSets` in Gradle).
`jb` knows a project is a test project because it depends on one of the supported testing frameworks (currently JUnit).

The `jbuild.yaml` file at the root looks like this:

```yaml
group: com.athaydes
module: example
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
output-jar: build/example.jar

# To be able to use the 'run' task without arguments, specify the main-class to run.
# You can also run any class by invoking `jb run :--main-class=some.other.Class`.
main-class: com.athaydes.example.Main

# dependencies can be Maven artifacts or other jb projects
dependencies:
    # Examples:
    #   org.slf4j:slf4j-api:2.0.16:
    #   com.google.guava:guava:33.4.0-jre:
    #     transitive: false
    #     scope: compile
    {}
```

This file has lots of comments to make it easy to understand the basic configuration model.
You can remove most of its contents as it is mostly using defaults, and you'll end up with something as simple as this:

```yaml
group: com.athaydes
module: example
version: '0.0.0'
output-jar: build/example.jar
main-class: com.athaydes.example.Main
```

> Even `output-jar` (which defaults to `build/<dir-name>.jar`) and `main-class` are optional.

If you run the `jb` command without any options, the `compile` task is executed, which means that the main project
will be built and all class files and resources archived in a jar:

<iframe src="{{ eval basePath }}/jb.html" style="width: 100%;height: 9em;"></iframe>

To run the tests, which are in the `test/` directory, you can either switch to that directory and run `jb test` from it,
or use the `-p` switch, which changes the project directory, to run the `test` task from the `test/` project as shown below:

<iframe src="{{ eval basePath }}/jb-test.html" style="width: 100%;height: 43em;"></iframe>

Because the main project declares a `main-class`, you can ask `jb` to run that with the `run` task:

<iframe src="{{ eval basePath }}/jb-run.html" style="width: 100%;height: 7em;"></iframe>

> The full runtime classpath is always stored in the location given by `runtime-libs-dir` which defaults to `build/runtime-libs`.
> This means that you can easily run the jar also with the java command directly:
> ```
> java -cp "build/runtime-libs/*" -jar build/example.jar
> ```

This time, `jb` only executes the `run` task because the `compile` task (and all tasks it depends on) is up-to-date.
If you modified a source file and then ran `jb run` again, the project would first be re-compiled, and then run.

You can see the task graph by passing the `-g` option to `jb`:

<iframe src="{{ eval basePath }}/jb-task-graph.html" style="width: 100%;height: 47em;"></iframe>

To show a description of each task, use the `-s` flag.

To see all `jb`'s command options, use the `-h` flag.

## Where to go next

This page gives a short introduction to `jb`. For more details, please visit the documentation:

<ul>
{{ for item (sortBy order) ../pages }}
{{ if item.path != path }}
<li><a href="{{ eval item.path }}">{{ eval item.name }}</a></li>
{{ end }}
{{ end }}
</ul>


{{ end }}
{{ include /processed/fragments/_footer.html }}
