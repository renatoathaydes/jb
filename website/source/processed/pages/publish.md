{{ include /processed/fragments/_header.html }}\
{{ define name "Publishing jb artifacts" }}
{{ define path basePath + "/pages/publish.html" }}
{{ define order 35 }}
# Publishing jb artifacts

Once you've written an artifact, you can publish it to a custom location, or to Maven Central.

## Publishing to a file system location or custom HTTP Maven Repository

To publish to a custom location, just run the `publish` task with the location as an argument:

```shell
$ jb publish :path/to/maven/repository

# if the location starts with 'http://' or 'https://', a HTTP Client is used.
$ jb publish https://acme.org/my-custom/repository
```

## Publishing to Maven Local

By default, `jb` publishes to Maven Local, so if you do not provide any options, the artifact
is only published to your Maven Local location:

```shell
# Publishes to "~/.m2/repository", or MAVEN_LOCAL_HOME if that is set.
$ jb publish
```

> If the `MAVEN_LOCAL_HOME` environment variable is set, the location it points to is used instead.

## Publishing to Maven Central

If you want to publish to Sonatype's Maven Central Repository, use the `-m` flag:

```shell
$ jb publish :-m
```

> When using the `-m` option, you cannot use also a custom location.

## Signing artifacts

Most repositories demand that you sign artifacts, so `jb` signs everything by default.

If you want to skip signing, you can use `--no-sign`:

```shell
$ jb publish :--no-sign :path/to/maven/repository
```

## Credentials

Since Sonatype generates an XML file with credentials when you generate a [Portal Token](https://central.sonatype.org/publish/generate-portal-token/), `jb`
accepts credentials via an XML file with the format created by Sonatype.

Example XML file with a Portal Token:

```xml
<server>
	<id>${server}</id>
	<username>XXXXX</username>
	<password>YYYYY</password>
</server>
```

To let `jb` know you have a file with credentials, set the path to the file as follows:

```shell
$ SONATYPE_PORTAL_TOKEN_XML_FILE=/path/to/sonatype-token.xml jb publish :-m
```

A Bearer Token is included in the request, as Sonatype expects:

```groovy
Authorization: Bearer ${base64Encode("$username:$password")}
```

{{ include /processed/fragments/_footer.html }}
