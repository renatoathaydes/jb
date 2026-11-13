{{ include /processed/fragments/_header.html }}\
{{ define name "Extending jb" }}
{{ define path basePath + "/pages/extensions.html" }}
{{ define order 20 }}
# Extending jb

A `jb` extension is a Java project that depends on the `com.athaydes.jbuild:jbuild-api` dependency and provides tasks and
configuration to `jb`.

Extensions can be either local `jb` projects or dependencies downloaded from a Maven repository.

## Creating a jb extension

The easiest way to create a `jb` extension is to use `jb create`. It will ask what kind of project to create,
and one of the options is a `jb` extension:

```shell
$ jb create
Please enter a project group ID: foo

Enter the artifact ID of this project: bar

Enter the root package [foo.bar]: 

Would you like to create a test module [Y/n]? n

Select a project type:
  1. basic project.
  2. jb extension.
Choose [1]: 2

jb project created at /Users/me/jb-extension
```

The following example shows a task that will depend on the `test` task from `jb`:

```java
package com.athaydes.jb_ext_open_test;

import jbuild.api.JbTask;
import jbuild.api.JbTaskInfo;
import jbuild.api.TaskPhase;

import java.io.IOException;
import java.util.List;

@JbTaskInfo(name = "createHtmlReport",
        description = "Creates a HTML report.",
        phase = @TaskPhase(name = "evaluate", index = 510))
public final class CreateHtmlReportTask implements JbTask {
    private static final List<String> dependsOn = List.of("test");

    @Override
    public List<String> dependsOn() {
        return dependsOn;
    }

    @Override
    public void run(String... args) throws IOException {
        System.out.println("Extension task running: " + getClass().getName());
    }
}
```

> Notice that a `jb` extension needs to be compiled with `jb` itself for the necessary metadata
> to be automatically included in the jar.

After writing the code you need for your extension to work, you can build it with `jb` and then
test it locally with another project by declaring a reference to the extension as follows:

```yaml
extension-projects:
    - "./jb-extension"
```

If you want the extension to be usable from multiple projects, you should publish the extension in a
Maven repository, and then you can declare it as follows:

```yaml
extension-projects:
    - "my-org:my-jb-extension:1.0.0"
```

> See [Publish jb artifacts](publish.html) for details on how to publish your extension.

The coordinates, as with all dependencies, uses the syntax `<group>:<module>:<version>`.

{{ include /processed/fragments/_footer.html }}
