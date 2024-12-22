{{ define title "Jb Docs" }}\
{{ include /processed/fragments/_header.html }}\

<img src="jb-logo.png" alt="jb Logo" class="center" style="width: 20em"></img>

{{ component /processed/fragments/_main.html }}
<div class="space-up"></div>

`jb` is a build tool that aims to bring Java build tools to the state-of-the-art as of the 2020's.

It is fast, easy to use and extensible via a simple Java API.

<ul>
{{ for item (sortBy order) pages }}
<li><a href="{{ eval item.path }}">{{ eval item.name }}</a></li>
{{ end }}
</ul>

## Download jb

<a href="https://github.com/renatoathaydes/jb/releases" style="font-size: 1.3em;">⬇️ Download from GitHub Releases</a>

Pre-built binaries are available for Windows, Linux and MacOS (x86 and ARM).

<div style="display: flex; justify-content: space-around; max-width: 80%;">
    <img src="/windows-logo.svg" alt="Windows Logo" style="width: 5em;">
    <img src="/linux-logo.svg" alt="Linux Logo" style="width: 5em;">
    <img src="/macos-logo.svg" alt="Mac OS Logo" style="width: 5em;">
</div>


## Why jb

Java build systems like [Ant](https://ant.apache.org/), [Maven](https://maven.apache.org/)
and [Gradle](https://gradle.org/) feel quite antiquated, heavy and difficult to use when compared with
more modern alternatives like [Cargo](https://doc.rust-lang.org/cargo/).

`jb` is an attempt at bringing what's best in contemporary build systems to Java, while respecting the Java
way of doing things.

## Features

* easy configuration via YAML or JSON.
* very fast (it doesn't need a daemon).
* distributed as single, small binary (~ 4MB).
* trivial dependency management (you decide how to handle conflicts).
* publish artifacts to any Maven repository.
* supports any Java version from 11 (built to be forward-compatible with newer Java versions).
* tasks run in parallel with full isolation.
* task results are cached, nothing runs unless actually required.
* extensions/plugins written in Java or any JVM language.
* great support for build profiling and introspection.
* runs [JUnit5](https://junit.org/junit5/) tests.

{{ end }}

{{ include /processed/fragments/_footer.html }}
