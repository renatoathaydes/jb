import 'package:jb/jb.dart';
import 'package:test/test.dart';

const emptyLocalDependencies = ResolvedLocalDependencies([], []);

void main() {
  group('POM generation', () {
    test('simple POM', () async {
      expect(createPom(await loadConfigString('''
      group: foo
      module: bar
      version: 1.0
      '''), emptyLocalDependencies).toString(), equals('''\
$pomHeader
    <groupId>foo</groupId>
    <artifactId>bar</artifactId>
    <version>1.0</version>
    <dependencies>
    </dependencies>
</project>
'''));
    });

    test('POM with Maven dependencies', () async {
      expect(createPom(await loadConfigString('''
      group: foo
      module: bar
      version: 1.0
      dependencies:
        - org.apache:json.parser:1.0.0
        - com.junit.api:junit:4.12
      '''), emptyLocalDependencies).toString(), equals('''\
$pomHeader
    <groupId>foo</groupId>
    <artifactId>bar</artifactId>
    <version>1.0</version>
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
</project>
'''));
    });

    test('POM with configured Maven dependencies', () async {
      expect(createPom(await loadConfigString('''
      group: foo
      module: bar
      version: 1.0
      dependencies:
        - org.apache:json.parser:1.0.0:
            scope: runtime-only
        - com.junit.api:junit:4.12:
            scope: compile-only
            transitive: false
      '''), emptyLocalDependencies).toString(), equals('''\
$pomHeader
    <groupId>foo</groupId>
    <artifactId>bar</artifactId>
    <version>1.0</version>
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
</project>
'''));
    });

    test('POM with Maven and Local dependencies', () async {
      final jbApiConfig = await loadConfigString('''
      module: jb-api
      group: com.athaydes.jb
      version: 0.1.0
      ''');
      expect(
          createPom(
              await loadConfigString('''
      group: my.group
      module: my.module
      version: 4.3.2.1
      dependencies:
        - org.apache:json.parser:1.0.0
      '''),
              ResolvedLocalDependencies([], [
                ResolvedProjectDependency(
                    ProjectDependency(
                        DependencySpec(
                            transitive: true,
                            scope: DependencyScope.compileOnly,
                            path: 'jb-api'),
                        'jb-api'),
                    'jb-api',
                    jbApiConfig)
              ])).toString(),
          equals('''\
$pomHeader
    <groupId>my.group</groupId>
    <artifactId>my.module</artifactId>
    <version>4.3.2.1</version>
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
</project>
'''));
    });
  });
}
