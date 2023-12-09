import 'package:jb/jb.dart';
import 'package:test/test.dart';

const pomHeader = '<?xml version="1.0" encoding="UTF-8"?>\n'
    '<project xmlns="http://maven.apache.org/POM/4.0.0" '
    'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
    'xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 '
    'http://maven.apache.org/xsd/maven-4.0.0.xsd">\n'
    '  <modelVersion>4.0.0</modelVersion>';

const nonTransitiveDependency = '''\
      <exclusions>
        <exclusion>
          <groupId>*</groupId>
          <artifactId>*</artifactId>
        </exclusion>
      </exclusions>''';

const emptyLocalDependencies = ResolvedLocalDependencies([], []);

Artifact _artifact(
        {required String group,
        required String name,
        required String module,
        required String version}) =>
    (
      group: group,
      module: module,
      name: name,
      version: version,
      description: '',
      developers: const [],
      scm: null,
      url: null,
      licenses: const [],
    );

void main() {
  group('POM generation', () {
    test('simple POM', () async {
      expect(
          createPom(
              _artifact(
                group: 'foo',
                name: 'Foo',
                module: 'bar',
                version: '1.0',
              ),
              const {},
              emptyLocalDependencies),
          equals('''\
$pomHeader
  <groupId>foo</groupId>
  <artifactId>bar</artifactId>
  <version>1.0</version>
  <name>Foo</name>
</project>'''));
    });

    test('POM with Maven dependencies', () async {
      expect(
          createPom(
                  _artifact(
                    group: 'foo',
                    module: 'bar',
                    name: 'Bar',
                    version: '1.0',
                  ),
                  {
                    'org.apache:json.parser:1.0.0': defaultSpec,
                    'com.junit.api:junit:4.12': defaultSpec,
                  }.entries,
                  emptyLocalDependencies)
              .toString(),
          equals('''\
$pomHeader
  <groupId>foo</groupId>
  <artifactId>bar</artifactId>
  <version>1.0</version>
  <name>Bar</name>
  <dependencies>
    <dependency>
      <groupId>org.apache</groupId>
      <artifactId>json.parser</artifactId>
      <version>1.0.0</version>
      <scope>compile</scope>
    </dependency>
    <dependency>
      <groupId>com.junit.api</groupId>
      <artifactId>junit</artifactId>
      <version>4.12</version>
      <scope>compile</scope>
    </dependency>
  </dependencies>
</project>'''));
    });

    test('POM with configured Maven dependencies', () async {
      expect(
          createPom(
                  _artifact(
                      group: 'foo', module: 'bar', name: 'BAR', version: '1.0'),
                  {
                    'org.apache:json.parser:1.0.0': DependencySpec(
                        scope: DependencyScope.runtimeOnly, transitive: true),
                    'com.junit.api:junit:4.12': DependencySpec(
                        scope: DependencyScope.compileOnly, transitive: false),
                  }.entries,
                  emptyLocalDependencies)
              .toString(),
          equals('''\
$pomHeader
  <groupId>foo</groupId>
  <artifactId>bar</artifactId>
  <version>1.0</version>
  <name>BAR</name>
  <dependencies>
    <dependency>
      <groupId>org.apache</groupId>
      <artifactId>json.parser</artifactId>
      <version>1.0.0</version>
      <scope>runtime</scope>
    </dependency>
    <dependency>
      <groupId>com.junit.api</groupId>
      <artifactId>junit</artifactId>
      <version>4.12</version>
      <scope>provided</scope>
$nonTransitiveDependency
    </dependency>
  </dependencies>
</project>'''));
    });

    test('POM with Maven and Local dependencies', () async {
      final jbApiConfig = await loadConfigString('''
      module: jb-api
      group: com.athaydes.jb
      version: 0.1.0
      ''');

      expect(
          createPom(
              _artifact(
                  group: 'my.group',
                  module: 'my.module',
                  name: 'My Module',
                  version: '4.3.2.1'),
              {
                'org.apache:json.parser:1.0.0': defaultSpec,
              }.entries,
              ResolvedLocalDependencies([], [
                ResolvedProjectDependency(
                    ProjectDependency(
                        DependencySpec(
                            transitive: true,
                            scope: DependencyScope.compileOnly,
                            path: 'jb-api'),
                        'jb-api'),
                    'jb-api',
                    JbConfigContainer(jbApiConfig))
              ])).toString(),
          equals('''\
$pomHeader
  <groupId>my.group</groupId>
  <artifactId>my.module</artifactId>
  <version>4.3.2.1</version>
  <name>My Module</name>
  <dependencies>
    <dependency>
      <groupId>org.apache</groupId>
      <artifactId>json.parser</artifactId>
      <version>1.0.0</version>
      <scope>compile</scope>
    </dependency>
    <dependency>
      <groupId>com.athaydes.jb</groupId>
      <artifactId>jb-api</artifactId>
      <version>0.1.0</version>
      <scope>provided</scope>
    </dependency>
  </dependencies>
</project>'''));
    });

    test('Full POM', () async {
      expect(
          createPom(
            (
              group: 'com.athaydes.jbuild',
              module: 'jb',
              name: 'JBuild',
              version: '1.0',
              developers: [
                const Developer(
                    name: 'Renato Athaydes',
                    email: 'renato@athaydes.com',
                    organization: 'athaydes.com',
                    organizationUrl: 'https://renato.athaydes.com')
              ],
              description: 'JBuild - a developer-friendly Java build tool',
              licenses: [allLicenses['Apache-2.0']!],
              scm: const SourceControlManagement(
                  connection: 'git@github.com:renatoathaydes/jbuild.git',
                  developerConnection:
                      'git@github.com:renatoathaydes/jbuild.git',
                  url: 'https://github.com/renatoathaydes/jbuild'),
              url: 'https://github.com/renatoathaydes/jbuild',
            ),
            {
              'org.apache:json.parser:1.0.0': defaultSpec,
              'junit:junit:4.12': DependencySpec(
                  transitive: true, scope: DependencyScope.compileOnly),
            }.entries,
            const ResolvedLocalDependencies([], []),
          ).toString(),
          equals('''\
$pomHeader
  <groupId>com.athaydes.jbuild</groupId>
  <artifactId>jb</artifactId>
  <version>1.0</version>
  <name>JBuild</name>
  <description>JBuild - a developer-friendly Java build tool</description>
  <url>https://github.com/renatoathaydes/jbuild</url>
  <scm>
    <connection>git@github.com:renatoathaydes/jbuild.git</connection>
    <developerConnection>git@github.com:renatoathaydes/jbuild.git</developerConnection>
    <url>https://github.com/renatoathaydes/jbuild</url>
  </scm>
  <licenses>
    <license>
      <name>Apache License 2.0</name>
      <url>https://spdx.org/licenses/Apache-2.0.html</url>
    </license>
  </licenses>
  <developers>
    <developer>
      <name>Renato Athaydes</name>
      <email>renato@athaydes.com</email>
      <organization>athaydes.com</organization>
      <organizationUrl>https://renato.athaydes.com</organizationUrl>
    </developer>
  </developers>
  <dependencies>
    <dependency>
      <groupId>org.apache</groupId>
      <artifactId>json.parser</artifactId>
      <version>1.0.0</version>
      <scope>compile</scope>
    </dependency>
    <dependency>
      <groupId>junit</groupId>
      <artifactId>junit</artifactId>
      <version>4.12</version>
      <scope>provided</scope>
    </dependency>
  </dependencies>
</project>'''));
    });
  });
}
