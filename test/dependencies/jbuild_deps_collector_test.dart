import 'package:jb/jb.dart';
import 'package:jb/src/dependencies/parse.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('JBuildDepsCollector Tests', () {
    test('can parse dependency', () {
      final collector = JBuildDepsCollector();
      collector(
        'Dependencies of com.google.errorprone:error_prone_core:2.16 (incl. transitive) [{Apache-2.0}]:',
      );
      collector('  - scope runtime');
      collector('    * foo:bar:1.0 [compile] [{Apache-2.0}]');

      collector.done(emitRoot: false);

      expect(
        collector.resolvedDeps.dependencies,
        equals([
          ResolvedDependency(
            artifact: 'foo:bar:1.0',
            spec: DependencySpec(scope: DependencyScope.runtimeOnly),
            sha1: '',
            isDirect: false,
            dependencies: const [],
            licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
          ),
        ]),
      );
    });

    test('can parse dependency (include root)', () {
      final collector = JBuildDepsCollector();
      collector(
        'Dependencies of com.google.errorprone:error_prone_core:2.16 (incl. transitive) [{Apache-2.0}]:',
      );
      collector('  - scope runtime');
      collector('    * foo:bar:1.0 [compile] [{Apache-2.0}]');

      collector.done(emitRoot: true);

      expect(
        collector.resolvedDeps.dependencies,
        equals([
          ResolvedDependency(
            artifact: "com.google.errorprone:error_prone_core:2.16",
            spec: DependencySpec(
              transitive: true,
              scope: DependencyScope.all,
              path: null,
            ),
            sha1: "",
            licenses: [DependencyLicense(name: "Apache-2.0", url: "")],
            isDirect: true,
            dependencies: ['foo:bar:1.0'],
          ),
          ResolvedDependency(
            artifact: 'foo:bar:1.0',
            spec: DependencySpec(scope: DependencyScope.runtimeOnly),
            sha1: '',
            isDirect: false,
            dependencies: const [],
            licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
          ),
        ]),
      );
    });

    test('can parse no-dependencies direct dependency', () {
      final collector = JBuildDepsCollector();
      collector('Dependencies of com.example:lists:1.0 (incl. transitive):');
      collector('  * no dependencies');
      collector.done(emitRoot: true);

      expect(
        collector.resolvedDeps.dependencies,
        equals([
          ResolvedDependency(
            artifact: 'com.example:lists:1.0',
            spec: defaultSpec,
            sha1: '',
            isDirect: true,
            dependencies: const [],
            licenses: const [],
          ),
        ]),
      );
    });

    test('can parse repeated dependencies', () {
      final collector = JBuildDepsCollector();
      collector(
        'Dependencies of com.example:project (incl. transitive) [{Apache-2.0}]:',
      );
      collector('  - scope compile');
      collector('    * foo:bar:1.0 [compile] [{Apache-2.0}]');
      collector('        * bar:zort:2.0 [compile] [{MIT}]');
      collector('            * zort:bar:2.0 [compile] [{Eclipse-2.0}]');
      collector('    * bar:zort:2.0 [compile] (-)');

      collector.done(emitRoot: true);

      expect(
        collector.resolvedDeps.dependencies,
        containsAll([
          ResolvedDependency(
            artifact: "com.example:project",
            spec: DependencySpec(),
            sha1: "",
            licenses: [DependencyLicense(name: "Apache-2.0", url: "")],
            isDirect: true,
            dependencies: ['foo:bar:1.0', 'bar:zort:2.0'],
          ),
          ResolvedDependency(
            artifact: 'foo:bar:1.0',
            spec: DependencySpec(),
            sha1: '',
            isDirect: false,
            dependencies: ['bar:zort:2.0'],
            licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
          ),
          ResolvedDependency(
            artifact: 'bar:zort:2.0',
            spec: DependencySpec(),
            sha1: '',
            isDirect: false,
            dependencies: ['zort:bar:2.0'],
            licenses: [DependencyLicense(name: 'MIT', url: '')],
          ),
          ResolvedDependency(
            artifact: 'bar:zort:2.0',
            spec: DependencySpec(),
            sha1: '',
            isDirect: false,
            dependencies: const [],
            // repeated dependency
            licenses: null,
          ),
          ResolvedDependency(
            artifact: 'zort:bar:2.0',
            spec: DependencySpec(),
            sha1: '',
            isDirect: false,
            dependencies: const [],
            // repeated dependency
            licenses: [DependencyLicense(name: 'Eclipse-2.0', url: '')],
          ),
        ]),
      );
    });

    test('can parse multiple scopes and dependency missing license', () {
      final collector = JBuildDepsCollector();
      collector(
        'Dependencies of com.example:with-deps:1.2.3 (incl. transitive):',
      );
      collector('  - scope runtime');
      collector('    * foo:bar:1.0 [runtime]');
      collector('  1 runtime dependency listed');
      collector('  - scope compile');
      collector('    * com.example:lists:1.0 [compile]');
      collector(
        '    * com.example:other:2.0 [compile] '
        '[{name=Eclipse Distribution License (New BSD License), url=<unspecified>}]',
      );
      collector('        * com.example:transitive:1.1 [compile]');
      collector('  3 compile dependencies listed');
      collector('Dependencies of com.example:another:4 (incl. transitive):');
      collector('  - scope compile');
      collector('    * org.apache.groovy:groovy:4.0.20 [compile]');
      collector('  1 compile dependency listed');
      collector('JBuild success in 1 ms!');

      collector.done(emitRoot: true);

      expect(
        collector.resolvedDeps.dependencies,
        containsAll([
          ResolvedDependency(
            artifact: 'com.example:with-deps:1.2.3',
            spec: DependencySpec(),
            sha1: '',
            isDirect: true,
            dependencies: [
              'foo:bar:1.0',
              'com.example:lists:1.0',
              'com.example:other:2.0',
            ],
            licenses: const [],
          ),
          ResolvedDependency(
            artifact: 'com.example:another:4',
            spec: DependencySpec(),
            sha1: '',
            isDirect: true,
            dependencies: ['org.apache.groovy:groovy:4.0.20'],
            licenses: const [],
          ),
          ResolvedDependency(
            artifact: 'org.apache.groovy:groovy:4.0.20',
            spec: DependencySpec(),
            sha1: '',
            isDirect: false,
            dependencies: const [],
            licenses: const [],
          ),
          ResolvedDependency(
            artifact: 'foo:bar:1.0',
            spec: DependencySpec(scope: DependencyScope.runtimeOnly),
            sha1: '',
            isDirect: false,
            dependencies: const [],
            licenses: const [],
          ),
          ResolvedDependency(
            artifact: 'com.example:lists:1.0',
            spec: DependencySpec(),
            sha1: '',
            isDirect: false,
            dependencies: const [],
            licenses: const [],
          ),
          ResolvedDependency(
            artifact: 'com.example:other:2.0',
            spec: DependencySpec(),
            sha1: '',
            isDirect: false,
            dependencies: ['com.example:transitive:1.1'],
            licenses: [
              DependencyLicense(
                name: 'Eclipse Distribution License (New BSD License)',
                url: '<unspecified>',
              ),
            ],
          ),
          ResolvedDependency(
            artifact: 'com.example:transitive:1.1',
            spec: DependencySpec(),
            sha1: '',
            isDirect: false,
            dependencies: const [],
            licenses: const [],
          ),
        ]),
      );
    });

    test('can parse dep with exclusions and license', () {
      final collector = JBuildDepsCollector();
      collector(
        'Dependencies of com.google.errorprone:error_prone_core:2.16 (incl. transitive) [{Apache-2.0}]:',
      );
      collector('  - scope runtime');
      collector(
        '    * org.eclipse.jgit:org.eclipse.jgit:4.4.1.201607150455-r '
        '[compile]:exclusions:[commons-codec:commons-codec, commons-logging:commons-logging, '
        'com.jcraft:jsch, com.googlecode.javaewah:JavaEWAH, org.apache.httpcomponents:httpclient, '
        'org.slf4j:slf4j-api] [{name=Eclipse Distribution License (New BSD License), url=<unspecified>}]',
      );

      collector.done(emitRoot: false);

      expect(
        collector.resolvedDeps.dependencies,
        equals([
          ResolvedDependency(
            artifact: 'org.eclipse.jgit:org.eclipse.jgit:4.4.1.201607150455-r',
            spec: DependencySpec(
              scope: DependencyScope.runtimeOnly,
              exclusions: [
                'commons-codec:commons-codec',
                'commons-logging:commons-logging',
                'com.jcraft:jsch',
                'com.googlecode.javaewah:JavaEWAH',
                'org.apache.httpcomponents:httpclient',
                'org.slf4j:slf4j-api',
              ],
            ),
            sha1: '',
            isDirect: false,
            dependencies: const [],
            licenses: [
              DependencyLicense(
                name: 'Eclipse Distribution License (New BSD License)',
                url: '<unspecified>',
              ),
            ],
          ),
        ]),
      );
    });

    test('real world, huge example', () {
      const realWorldExample = '''
Dependencies of org.springframework.boot:spring-boot-starter-thymeleaf: (incl. transitive) [{Apache-2.0}]:
  - scope compile
    * org.springframework.boot:spring-boot-starter:3.5.3 [compile] [{Apache-2.0}]
        * jakarta.annotation:jakarta.annotation-api:2.1.1 [compile] [{name=EPL 2.0, url=http://www.eclipse.org/legal/epl-2.0}, {name=GPL2 w/ CPE, url=https://www.gnu.org/software/classpath/license.html}, {name=Eclipse Public License v. 2.0, url=https://www.eclipse.org/org/documents/epl-2.0/EPL-2.0.txt}, {name=GNU General Public License, version 2 with the GNU Classpath Exception, url=https://www.gnu.org/software/classpath/license.html}]
        * org.springframework.boot:spring-boot-autoconfigure:3.5.3 [compile] [{Apache-2.0}]
            * org.springframework.boot:spring-boot:3.5.3 [compile] [{Apache-2.0}]
                * org.springframework:spring-context:6.2.8 [compile] [{Apache-2.0}]
                    * io.micrometer:micrometer-observation:1.14.8 [compile] [{Apache-2.0}]
                        * io.micrometer:micrometer-commons:1.14.8 [compile] [{Apache-2.0}]
                    * org.springframework:spring-aop:6.2.8 [compile] [{Apache-2.0}]
                        * org.springframework:spring-beans:6.2.8 [compile] [{Apache-2.0}]
                            * org.springframework:spring-core:6.2.8 [compile] [{Apache-2.0}]
                                * org.springframework:spring-jcl:6.2.8 [compile] [{Apache-2.0}]
                        * org.springframework:spring-core:6.2.8 [compile] (-)
                    * org.springframework:spring-beans:6.2.8 [compile] (-)
                    * org.springframework:spring-core:6.2.8 [compile] (-)
                    * org.springframework:spring-expression:6.2.8 [compile] [{Apache-2.0}]
                        * org.springframework:spring-core:6.2.8 [compile] (-)
                * org.springframework:spring-core:6.2.8 [compile] (-)
        * org.springframework.boot:spring-boot-starter-logging:3.5.3 [compile] [{Apache-2.0}]
            * ch.qos.logback:logback-classic:1.5.18 [compile] [{LGPL-2.1}, {EPL-1.0}]
                * ch.qos.logback:logback-core:1.5.18 [compile] [{LGPL-2.1}, {EPL-1.0}]
                * org.slf4j:slf4j-api:2.0.17 [compile] [{MIT}]
            * org.apache.logging.log4j:log4j-to-slf4j:2.24.3 [compile] [{Apache-2.0}]
                * org.apache.logging.log4j:log4j-api:2.24.3 [compile] [{Apache-2.0}]
                * org.slf4j:slf4j-api:2.0.16 [compile] [{MIT}]
            * org.slf4j:jul-to-slf4j:2.0.17 [compile] [{MIT}]
                * org.slf4j:slf4j-api:2.0.17 [compile] (-)
        * org.springframework.boot:spring-boot:3.5.3 [compile] (-)
        * org.springframework:spring-core:6.2.8 [compile] (-)
        * org.yaml:snakeyaml:2.4 [compile] [{Apache-2.0}]
    * org.thymeleaf:thymeleaf-spring6:3.1.3.RELEASE [compile] [{Apache-2.0}]
        * org.slf4j:slf4j-api:2.0.16 [compile] (-)
        * org.thymeleaf:thymeleaf:3.1.3.RELEASE [compile]:exclusions:[ognl:ognl] [{Apache-2.0}]
            * org.attoparser:attoparser:2.0.7.RELEASE [compile] [{Apache-2.0}]
            * org.slf4j:slf4j-api:2.0.16 [compile] (-)
            * org.unbescape:unbescape:1.1.6.RELEASE [compile] [{Apache-2.0}]
  25 compile dependencies listed
  The artifact org.slf4j:slf4j-api is required with more than one version:
    * 2.0.16 (org.springframework.boot:spring-boot-starter:3.5.3 -> org.springframework.boot:spring-boot-starter-logging:3.5.3 -> org.apache.logging.log4j:log4j-to-slf4j:2.24.3 -> org.slf4j:slf4j-api:2.0.16)
    * 2.0.17 (org.springframework.boot:spring-boot-starter:3.5.3 -> org.springframework.boot:spring-boot-starter-logging:3.5.3 -> ch.qos.logback:logback-classic:1.5.18 -> org.slf4j:slf4j-api:2.0.17)
All licenses listed (see https://spdx.org/licenses/ for more information):
  * Apache-2.0
  * EPL-1.0
  * LGPL-2.1
  * MIT
  * name=EPL 2.0, url=http://www.eclipse.org/legal/epl-2.0
  * name=Eclipse Public License v. 2.0, url=https://www.eclipse.org/org/documents/epl-2.0/EPL-2.0.txt
  * name=GNU General Public License, version 2 with the GNU Classpath Exception, url=https://www.gnu.org/software/classpath/license.html
  * name=GPL2 w/ CPE, url=https://www.gnu.org/software/classpath/license.html
Dependencies of org.springframework.boot:spring-boot-starter-oauth2-client: (incl. transitive) [{Apache-2.0}]:
  - scope compile
    * org.springframework.boot:spring-boot-starter:3.5.3 [compile] [{Apache-2.0}]
        * jakarta.annotation:jakarta.annotation-api:2.1.1 [compile] [{name=EPL 2.0, url=http://www.eclipse.org/legal/epl-2.0}, {name=GPL2 w/ CPE, url=https://www.gnu.org/software/classpath/license.html}, {name=Eclipse Public License v. 2.0, url=https://www.eclipse.org/org/documents/epl-2.0/EPL-2.0.txt}, {name=GNU General Public License, version 2 with the GNU Classpath Exception, url=https://www.gnu.org/software/classpath/license.html}]
        * org.springframework.boot:spring-boot-autoconfigure:3.5.3 [compile] [{Apache-2.0}]
            * org.springframework.boot:spring-boot:3.5.3 [compile] [{Apache-2.0}]
                * org.springframework:spring-context:6.2.8 [compile] [{Apache-2.0}]
                    * io.micrometer:micrometer-observation:1.14.8 [compile] [{Apache-2.0}]
                        * io.micrometer:micrometer-commons:1.14.8 [compile] [{Apache-2.0}]
                    * org.springframework:spring-aop:6.2.8 [compile] [{Apache-2.0}]
                        * org.springframework:spring-beans:6.2.8 [compile] [{Apache-2.0}]
                            * org.springframework:spring-core:6.2.8 [compile] [{Apache-2.0}]
                                * org.springframework:spring-jcl:6.2.8 [compile] [{Apache-2.0}]
                        * org.springframework:spring-core:6.2.8 [compile] (-)
                    * org.springframework:spring-beans:6.2.8 [compile] (-)
                    * org.springframework:spring-core:6.2.8 [compile] (-)
                    * org.springframework:spring-expression:6.2.8 [compile] [{Apache-2.0}]
                        * org.springframework:spring-core:6.2.8 [compile] (-)
                * org.springframework:spring-core:6.2.8 [compile] (-)
        * org.springframework.boot:spring-boot-starter-logging:3.5.3 [compile] [{Apache-2.0}]
            * ch.qos.logback:logback-classic:1.5.18 [compile] [{LGPL-2.1}, {EPL-1.0}]
                * ch.qos.logback:logback-core:1.5.18 [compile] [{LGPL-2.1}, {EPL-1.0}]
                * org.slf4j:slf4j-api:2.0.17 [compile] [{MIT}]
            * org.apache.logging.log4j:log4j-to-slf4j:2.24.3 [compile] [{Apache-2.0}]
                * org.apache.logging.log4j:log4j-api:2.24.3 [compile] [{Apache-2.0}]
                * org.slf4j:slf4j-api:2.0.16 [compile] [{MIT}]
            * org.slf4j:jul-to-slf4j:2.0.17 [compile] [{MIT}]
                * org.slf4j:slf4j-api:2.0.17 [compile] (-)
        * org.springframework.boot:spring-boot:3.5.3 [compile] (-)
        * org.springframework:spring-core:6.2.8 [compile] (-)
        * org.yaml:snakeyaml:2.4 [compile] [{Apache-2.0}]
    * org.springframework.security:spring-security-config:6.5.1 [compile] [{Apache-2.0}]
        * org.springframework.security:spring-security-core:6.5.1 [compile] [{Apache-2.0}]
            * io.micrometer:micrometer-observation:1.14.8 [compile] (-)
            * org.springframework.security:spring-security-crypto:6.5.1 [compile] [{Apache-2.0}]
            * org.springframework:spring-aop:6.2.7 [compile] [{Apache-2.0}]
                * org.springframework:spring-beans:6.2.7 [compile] [{Apache-2.0}]
                    * org.springframework:spring-core:6.2.7 [compile] [{Apache-2.0}]
                        * org.springframework:spring-jcl:6.2.7 [compile] [{Apache-2.0}]
                * org.springframework:spring-core:6.2.7 [compile] (-)
            * org.springframework:spring-beans:6.2.7 [compile] (-)
            * org.springframework:spring-context:6.2.7 [compile] [{Apache-2.0}]
                * io.micrometer:micrometer-observation:1.14.7 [compile] [{Apache-2.0}]
                    * io.micrometer:micrometer-commons:1.14.7 [compile] [{Apache-2.0}]
                * org.springframework:spring-aop:6.2.7 [compile] (-)
                * org.springframework:spring-beans:6.2.7 [compile] (-)
                * org.springframework:spring-core:6.2.7 [compile] (-)
                * org.springframework:spring-expression:6.2.7 [compile] [{Apache-2.0}]
                    * org.springframework:spring-core:6.2.7 [compile] (-)
            * org.springframework:spring-core:6.2.7 [compile] (-)
            * org.springframework:spring-expression:6.2.7 [compile] (-)
        * org.springframework:spring-aop:6.2.7 [compile] (-)
        * org.springframework:spring-beans:6.2.7 [compile] (-)
        * org.springframework:spring-context:6.2.7 [compile] (-)
        * org.springframework:spring-core:6.2.7 [compile] (-)
    * org.springframework.security:spring-security-core:6.5.1 [compile] (-)
    * org.springframework.security:spring-security-oauth2-client:6.5.1 [compile] [{Apache-2.0}]
        * com.nimbusds:oauth2-oidc-sdk:9.43.6 [compile] [{name=Apache License, version 2.0, url=https://www.apache.org/licenses/LICENSE-2.0.html}]
            * com.github.stephenc.jcip:jcip-annotations:1.0-1 [compile] [{Apache-2.0}]
            * com.nimbusds:content-type:2.2 [compile] [{Apache-2.0}]
            * com.nimbusds:lang-tag:1.7 [compile] [{Apache-2.0}]
            * com.nimbusds:nimbus-jose-jwt:9.37.3 [compile] [{Apache-2.0}]
                * com.github.stephenc.jcip:jcip-annotations:1.0-1 [compile] (-)
            * net.minidev:json-smart:2.5.2 [compile] [{Apache-2.0}]
                * net.minidev:accessors-smart:2.5.2 [compile] [{Apache-2.0}]
                    * org.ow2.asm:asm:9.7.1 [compile] [{Apache-2.0}, {name=BSD-3-Clause, url=https://asm.ow2.io/license.html}]
        * org.springframework.security:spring-security-core:6.5.1 [compile] (-)
        * org.springframework.security:spring-security-oauth2-core:6.5.1 [compile] [{Apache-2.0}]
            * org.springframework.security:spring-security-core:6.5.1 [compile] (-)
            * org.springframework:spring-core:6.2.7 [compile] (-)
            * org.springframework:spring-web:6.2.7 [compile] [{Apache-2.0}]
                * io.micrometer:micrometer-observation:1.14.7 [compile] (-)
                * org.springframework:spring-beans:6.2.7 [compile] (-)
                * org.springframework:spring-core:6.2.7 [compile] (-)
        * org.springframework.security:spring-security-web:6.5.1 [compile] [{Apache-2.0}]
            * org.springframework.security:spring-security-core:6.5.1 [compile] (-)
            * org.springframework:spring-aop:6.2.7 [compile] (-)
            * org.springframework:spring-beans:6.2.7 [compile] (-)
            * org.springframework:spring-context:6.2.7 [compile] (-)
            * org.springframework:spring-core:6.2.7 [compile] (-)
            * org.springframework:spring-expression:6.2.7 [compile] (-)
            * org.springframework:spring-web:6.2.7 [compile] (-)
        * org.springframework:spring-core:6.2.7 [compile] (-)
    * org.springframework.security:spring-security-oauth2-jose:6.5.1 [compile] [{Apache-2.0}]
        * com.nimbusds:nimbus-jose-jwt:9.37.3 [compile] (-)
        * org.springframework.security:spring-security-core:6.5.1 [compile] (-)
        * org.springframework.security:spring-security-oauth2-core:6.5.1 [compile] (-)
        * org.springframework:spring-core:6.2.7 [compile] (-)
  45 compile dependencies listed
  The artifact org.springframework:spring-jcl is required with more than one version:
    * 6.2.8 (org.springframework.boot:spring-boot-starter:3.5.3 -> org.springframework.boot:spring-boot-autoconfigure:3.5.3 -> org.springframework.boot:spring-boot:3.5.3 -> org.springframework:spring-context:6.2.8 -> org.springframework:spring-aop:6.2.8 -> org.springframework:spring-beans:6.2.8 -> org.springframework:spring-core:6.2.8 -> org.springframework:spring-jcl:6.2.8)
    * 6.2.7 (org.springframework.security:spring-security-config:6.5.1 -> org.springframework.security:spring-security-core:6.5.1 -> org.springframework:spring-aop:6.2.7 -> org.springframework:spring-beans:6.2.7 -> org.springframework:spring-core:6.2.7 -> org.springframework:spring-jcl:6.2.7)
  The artifact org.springframework:spring-context is required with more than one version:
    * 6.2.8 (org.springframework.boot:spring-boot-starter:3.5.3 -> org.springframework.boot:spring-boot-autoconfigure:3.5.3 -> org.springframework.boot:spring-boot:3.5.3 -> org.springframework:spring-context:6.2.8)
    * 6.2.7 (org.springframework.security:spring-security-config:6.5.1 -> org.springframework.security:spring-security-core:6.5.1 -> org.springframework:spring-context:6.2.7)
  The artifact io.micrometer:micrometer-commons is required with more than one version:
    * 1.14.8 (org.springframework.boot:spring-boot-starter:3.5.3 -> org.springframework.boot:spring-boot-autoconfigure:3.5.3 -> org.springframework.boot:spring-boot:3.5.3 -> org.springframework:spring-context:6.2.8 -> io.micrometer:micrometer-observation:1.14.8 -> io.micrometer:micrometer-commons:1.14.8)
    * 1.14.7 (org.springframework.security:spring-security-config:6.5.1 -> org.springframework.security:spring-security-core:6.5.1 -> org.springframework:spring-context:6.2.7 -> io.micrometer:micrometer-observation:1.14.7 -> io.micrometer:micrometer-commons:1.14.7)
  The artifact org.springframework:spring-aop is required with more than one version:
    * 6.2.8 (org.springframework.boot:spring-boot-starter:3.5.3 -> org.springframework.boot:spring-boot-autoconfigure:3.5.3 -> org.springframework.boot:spring-boot:3.5.3 -> org.springframework:spring-context:6.2.8 -> org.springframework:spring-aop:6.2.8)
    * 6.2.7 (org.springframework.security:spring-security-config:6.5.1 -> org.springframework.security:spring-security-core:6.5.1 -> org.springframework:spring-aop:6.2.7)
  The artifact org.slf4j:slf4j-api is required with more than one version:
    * 2.0.16 (org.springframework.boot:spring-boot-starter:3.5.3 -> org.springframework.boot:spring-boot-starter-logging:3.5.3 -> org.apache.logging.log4j:log4j-to-slf4j:2.24.3 -> org.slf4j:slf4j-api:2.0.16)
    * 2.0.17 (org.springframework.boot:spring-boot-starter:3.5.3 -> org.springframework.boot:spring-boot-starter-logging:3.5.3 -> ch.qos.logback:logback-classic:1.5.18 -> org.slf4j:slf4j-api:2.0.17)
  The artifact org.springframework:spring-core is required with more than one version:
    * 6.2.8 (org.springframework.boot:spring-boot-starter:3.5.3 -> org.springframework.boot:spring-boot-autoconfigure:3.5.3 -> org.springframework.boot:spring-boot:3.5.3 -> org.springframework:spring-context:6.2.8 -> org.springframework:spring-aop:6.2.8 -> org.springframework:spring-beans:6.2.8 -> org.springframework:spring-core:6.2.8)
    * 6.2.7 (org.springframework.security:spring-security-config:6.5.1 -> org.springframework.security:spring-security-core:6.5.1 -> org.springframework:spring-aop:6.2.7 -> org.springframework:spring-beans:6.2.7 -> org.springframework:spring-core:6.2.7)
  The artifact org.springframework:spring-beans is required with more than one version:
    * 6.2.8 (org.springframework.boot:spring-boot-starter:3.5.3 -> org.springframework.boot:spring-boot-autoconfigure:3.5.3 -> org.springframework.boot:spring-boot:3.5.3 -> org.springframework:spring-context:6.2.8 -> org.springframework:spring-aop:6.2.8 -> org.springframework:spring-beans:6.2.8)
    * 6.2.7 (org.springframework.security:spring-security-config:6.5.1 -> org.springframework.security:spring-security-core:6.5.1 -> org.springframework:spring-aop:6.2.7 -> org.springframework:spring-beans:6.2.7)
  The artifact org.springframework:spring-expression is required with more than one version:
    * 6.2.8 (org.springframework.boot:spring-boot-starter:3.5.3 -> org.springframework.boot:spring-boot-autoconfigure:3.5.3 -> org.springframework.boot:spring-boot:3.5.3 -> org.springframework:spring-context:6.2.8 -> org.springframework:spring-expression:6.2.8)
    * 6.2.7 (org.springframework.security:spring-security-config:6.5.1 -> org.springframework.security:spring-security-core:6.5.1 -> org.springframework:spring-context:6.2.7 -> org.springframework:spring-expression:6.2.7)
  The artifact io.micrometer:micrometer-observation is required with more than one version:
    * 1.14.8 (org.springframework.boot:spring-boot-starter:3.5.3 -> org.springframework.boot:spring-boot-autoconfigure:3.5.3 -> org.springframework.boot:spring-boot:3.5.3 -> org.springframework:spring-context:6.2.8 -> io.micrometer:micrometer-observation:1.14.8)
    * 1.14.7 (org.springframework.security:spring-security-config:6.5.1 -> org.springframework.security:spring-security-core:6.5.1 -> org.springframework:spring-context:6.2.7 -> io.micrometer:micrometer-observation:1.14.7)
All licenses listed (see https://spdx.org/licenses/ for more information):
  * Apache-2.0
  * EPL-1.0
  * LGPL-2.1
  * MIT
  * name=Apache License, version 2.0, url=https://www.apache.org/licenses/LICENSE-2.0.html
  * name=BSD-3-Clause, url=https://asm.ow2.io/license.html
  * name=EPL 2.0, url=http://www.eclipse.org/legal/epl-2.0
  * name=Eclipse Public License v. 2.0, url=https://www.eclipse.org/org/documents/epl-2.0/EPL-2.0.txt
  * name=GNU General Public License, version 2 with the GNU Classpath Exception, url=https://www.gnu.org/software/classpath/license.html
  * name=GPL2 w/ CPE, url=https://www.gnu.org/software/classpath/license.html
JBuild success in 415 ms!
      ''';

      final collector = JBuildDepsCollector();
      realWorldExample.split('\n').forEach(collector.call);
      collector.done(emitRoot: true);

      final expectedDependencies = [
        // --- spring-boot-starter-thymeleaf root ---
        ResolvedDependency(
          artifact: 'org.springframework.boot:spring-boot-starter-thymeleaf:',
          spec: defaultSpec,
          sha1: '',
          isDirect: true,
          dependencies: [
            'org.springframework.boot:spring-boot-starter:3.5.3',
            'org.thymeleaf:thymeleaf-spring6:3.1.3.RELEASE',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework.boot:spring-boot-starter ---
        ResolvedDependency(
          artifact: 'org.springframework.boot:spring-boot-starter:3.5.3',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'jakarta.annotation:jakarta.annotation-api:2.1.1',
            'org.springframework.boot:spring-boot-autoconfigure:3.5.3',
            'org.springframework.boot:spring-boot-starter-logging:3.5.3',
            'org.springframework.boot:spring-boot:3.5.3',
            'org.springframework:spring-core:6.2.8',
            'org.yaml:snakeyaml:2.4',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.thymeleaf:thymeleaf-spring6 ---
        ResolvedDependency(
          artifact: 'org.thymeleaf:thymeleaf-spring6:3.1.3.RELEASE',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'org.slf4j:slf4j-api:2.0.16',
            'org.thymeleaf:thymeleaf:3.1.3.RELEASE',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.thymeleaf:thymeleaf ---
        ResolvedDependency(
          artifact: 'org.thymeleaf:thymeleaf:3.1.3.RELEASE',
          spec: DependencySpec(exclusions: ['ognl:ognl']),
          sha1: '',
          isDirect: false,
          dependencies: [
            'org.attoparser:attoparser:2.0.7.RELEASE',
            'org.slf4j:slf4j-api:2.0.16',
            'org.unbescape:unbescape:1.1.6.RELEASE',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        ResolvedDependency(
          artifact: 'org.attoparser:attoparser:2.0.7.RELEASE',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        ResolvedDependency(
          artifact: 'org.unbescape:unbescape:1.1.6.RELEASE',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework.boot:spring-boot-autoconfigure ---
        ResolvedDependency(
          artifact: 'org.springframework.boot:spring-boot-autoconfigure:3.5.3',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['org.springframework.boot:spring-boot:3.5.3'],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework.boot:spring-boot ---
        ResolvedDependency(
          artifact: 'org.springframework.boot:spring-boot:3.5.3',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'org.springframework:spring-context:6.2.8',
            'org.springframework:spring-core:6.2.8',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-context ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-context:6.2.8',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'io.micrometer:micrometer-observation:1.14.8',
            'org.springframework:spring-aop:6.2.8',
            'org.springframework:spring-beans:6.2.8',
            'org.springframework:spring-core:6.2.8',
            'org.springframework:spring-expression:6.2.8',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- io.micrometer:micrometer-observation ---
        ResolvedDependency(
          artifact: 'io.micrometer:micrometer-observation:1.14.8',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['io.micrometer:micrometer-commons:1.14.8'],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- io.micrometer:micrometer-commons ---
        ResolvedDependency(
          artifact: 'io.micrometer:micrometer-commons:1.14.8',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-aop ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-aop:6.2.8',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'org.springframework:spring-beans:6.2.8',
            'org.springframework:spring-core:6.2.8',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-beans ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-beans:6.2.8',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['org.springframework:spring-core:6.2.8'],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-core ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-core:6.2.8',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['org.springframework:spring-jcl:6.2.8'],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-jcl ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-jcl:6.2.8',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-expression ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-expression:6.2.8',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['org.springframework:spring-core:6.2.8'],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.yaml:snakeyaml ---
        ResolvedDependency(
          artifact: 'org.yaml:snakeyaml:2.4',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework.boot:spring-boot-starter-logging ---
        ResolvedDependency(
          artifact:
              'org.springframework.boot:spring-boot-starter-logging:3.5.3',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'ch.qos.logback:logback-classic:1.5.18',
            'org.apache.logging.log4j:log4j-to-slf4j:2.24.3',
            'org.slf4j:jul-to-slf4j:2.0.17',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- ch.qos.logback:logback-classic ---
        ResolvedDependency(
          artifact: 'ch.qos.logback:logback-classic:1.5.18',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'ch.qos.logback:logback-core:1.5.18',
            'org.slf4j:slf4j-api:2.0.17',
          ],
          licenses: [
            DependencyLicense(name: 'LGPL-2.1', url: ''),
            DependencyLicense(name: 'EPL-1.0', url: ''),
          ],
        ),
        // --- ch.qos.logback:logback-core ---
        ResolvedDependency(
          artifact: 'ch.qos.logback:logback-core:1.5.18',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [
            DependencyLicense(name: 'LGPL-2.1', url: ''),
            DependencyLicense(name: 'EPL-1.0', url: ''),
          ],
        ),
        // --- org.slf4j:slf4j-api:2.0.17 ---
        ResolvedDependency(
          artifact: 'org.slf4j:slf4j-api:2.0.17',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'MIT', url: '')],
        ),
        // --- org.apache.logging.log4j:log4j-to-slf4j ---
        ResolvedDependency(
          artifact: 'org.apache.logging.log4j:log4j-to-slf4j:2.24.3',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'org.apache.logging.log4j:log4j-api:2.24.3',
            'org.slf4j:slf4j-api:2.0.16',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.apache.logging.log4j:log4j-api ---
        ResolvedDependency(
          artifact: 'org.apache.logging.log4j:log4j-api:2.24.3',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.slf4j:slf4j-api:2.0.16 ---
        ResolvedDependency(
          artifact: 'org.slf4j:slf4j-api:2.0.16',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'MIT', url: '')],
        ),
        // --- org.slf4j:jul-to-slf4j ---
        ResolvedDependency(
          artifact: 'org.slf4j:jul-to-slf4j:2.0.17',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['org.slf4j:slf4j-api:2.0.17'],
          licenses: [DependencyLicense(name: 'MIT', url: '')],
        ),
        // --- jakarta.annotation:jakarta.annotation-api ---
        ResolvedDependency(
          artifact: 'jakarta.annotation:jakarta.annotation-api:2.1.1',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [
            DependencyLicense(
              name: 'EPL 2.0',
              url: 'http://www.eclipse.org/legal/epl-2.0',
            ),
            DependencyLicense(
              name: 'GPL2 w/ CPE',
              url: 'https://www.gnu.org/software/classpath/license.html',
            ),
            DependencyLicense(
              name: 'Eclipse Public License v. 2.0',
              url: 'https://www.eclipse.org/org/documents/epl-2.0/EPL-2.0.txt',
            ),
            DependencyLicense(
              name:
                  'GNU General Public License, version 2 with the GNU Classpath Exception',
              url: 'https://www.gnu.org/software/classpath/license.html',
            ),
          ],
        ),
        // --- spring-boot-starter-oauth2-client root ---
        ResolvedDependency(
          artifact:
              'org.springframework.boot:spring-boot-starter-oauth2-client:',
          spec: defaultSpec,
          sha1: '',
          isDirect: true,
          dependencies: [
            'org.springframework.boot:spring-boot-starter:3.5.3',
            'org.springframework.security:spring-security-config:6.5.1',
            'org.springframework.security:spring-security-core:6.5.1',
            'org.springframework.security:spring-security-oauth2-client:6.5.1',
            'org.springframework.security:spring-security-oauth2-jose:6.5.1',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework.security:spring-security-config ---
        ResolvedDependency(
          artifact: 'org.springframework.security:spring-security-config:6.5.1',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'org.springframework.security:spring-security-core:6.5.1',
            'org.springframework:spring-aop:6.2.7',
            'org.springframework:spring-beans:6.2.7',
            'org.springframework:spring-context:6.2.7',
            'org.springframework:spring-core:6.2.7',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework.security:spring-security-core ---
        ResolvedDependency(
          artifact: 'org.springframework.security:spring-security-core:6.5.1',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'io.micrometer:micrometer-observation:1.14.8',
            'org.springframework.security:spring-security-crypto:6.5.1',
            'org.springframework:spring-aop:6.2.7',
            'org.springframework:spring-beans:6.2.7',
            'org.springframework:spring-context:6.2.7',
            'org.springframework:spring-core:6.2.7',
            'org.springframework:spring-expression:6.2.7',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework.security:spring-security-crypto ---
        ResolvedDependency(
          artifact: 'org.springframework.security:spring-security-crypto:6.5.1',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-aop:6.2.7 ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-aop:6.2.7',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'org.springframework:spring-beans:6.2.7',
            'org.springframework:spring-core:6.2.7',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-beans:6.2.7 ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-beans:6.2.7',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['org.springframework:spring-core:6.2.7'],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-core:6.2.7 ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-core:6.2.7',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['org.springframework:spring-jcl:6.2.7'],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-jcl:6.2.7 ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-jcl:6.2.7',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-context:6.2.7 ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-context:6.2.7',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'io.micrometer:micrometer-observation:1.14.7',
            'org.springframework:spring-aop:6.2.7',
            'org.springframework:spring-beans:6.2.7',
            'org.springframework:spring-core:6.2.7',
            'org.springframework:spring-expression:6.2.7',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- io.micrometer:micrometer-observation:1.14.7 ---
        ResolvedDependency(
          artifact: 'io.micrometer:micrometer-observation:1.14.7',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['io.micrometer:micrometer-commons:1.14.7'],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- io.micrometer:micrometer-commons:1.14.7 ---
        ResolvedDependency(
          artifact: 'io.micrometer:micrometer-commons:1.14.7',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-expression:6.2.7 ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-expression:6.2.7',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['org.springframework:spring-core:6.2.7'],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework.security:spring-security-oauth2-client ---
        ResolvedDependency(
          artifact:
              'org.springframework.security:spring-security-oauth2-client:6.5.1',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'com.nimbusds:oauth2-oidc-sdk:9.43.6',
            'org.springframework.security:spring-security-core:6.5.1',
            'org.springframework.security:spring-security-oauth2-core:6.5.1',
            'org.springframework.security:spring-security-web:6.5.1',
            'org.springframework:spring-core:6.2.7',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- com.nimbusds:oauth2-oidc-sdk ---
        ResolvedDependency(
          artifact: 'com.nimbusds:oauth2-oidc-sdk:9.43.6',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'com.github.stephenc.jcip:jcip-annotations:1.0-1',
            'com.nimbusds:content-type:2.2',
            'com.nimbusds:lang-tag:1.7',
            'com.nimbusds:nimbus-jose-jwt:9.37.3',
            'net.minidev:json-smart:2.5.2',
          ],
          licenses: [
            DependencyLicense(
              name: 'Apache License, version 2.0',
              url: 'https://www.apache.org/licenses/LICENSE-2.0.html',
            ),
          ],
        ),
        // --- com.github.stephenc.jcip:jcip-annotations ---
        ResolvedDependency(
          artifact: 'com.github.stephenc.jcip:jcip-annotations:1.0-1',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- com.nimbusds:content-type ---
        ResolvedDependency(
          artifact: 'com.nimbusds:content-type:2.2',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- com.nimbusds:lang-tag ---
        ResolvedDependency(
          artifact: 'com.nimbusds:lang-tag:1.7',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- com.nimbusds:nimbus-jose-jwt ---
        ResolvedDependency(
          artifact: 'com.nimbusds:nimbus-jose-jwt:9.37.3',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['com.github.stephenc.jcip:jcip-annotations:1.0-1'],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- net.minidev:json-smart ---
        ResolvedDependency(
          artifact: 'net.minidev:json-smart:2.5.2',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['net.minidev:accessors-smart:2.5.2'],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- net.minidev:accessors-smart ---
        ResolvedDependency(
          artifact: 'net.minidev:accessors-smart:2.5.2',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: ['org.ow2.asm:asm:9.7.1'],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.ow2.asm:asm ---
        ResolvedDependency(
          artifact: 'org.ow2.asm:asm:9.7.1',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: const [],
          licenses: [
            DependencyLicense(name: 'Apache-2.0', url: ''),
            DependencyLicense(
              name: 'BSD-3-Clause',
              url: 'https://asm.ow2.io/license.html',
            ),
          ],
        ),
        // --- org.springframework.security:spring-security-oauth2-core ---
        ResolvedDependency(
          artifact:
              'org.springframework.security:spring-security-oauth2-core:6.5.1',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'org.springframework.security:spring-security-core:6.5.1',
            'org.springframework:spring-core:6.2.7',
            'org.springframework:spring-web:6.2.7',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework:spring-web ---
        ResolvedDependency(
          artifact: 'org.springframework:spring-web:6.2.7',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'io.micrometer:micrometer-observation:1.14.7',
            'org.springframework:spring-beans:6.2.7',
            'org.springframework:spring-core:6.2.7',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework.security:spring-security-web ---
        ResolvedDependency(
          artifact: 'org.springframework.security:spring-security-web:6.5.1',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'org.springframework.security:spring-security-core:6.5.1',
            'org.springframework:spring-aop:6.2.7',
            'org.springframework:spring-beans:6.2.7',
            'org.springframework:spring-context:6.2.7',
            'org.springframework:spring-core:6.2.7',
            'org.springframework:spring-expression:6.2.7',
            'org.springframework:spring-web:6.2.7',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
        // --- org.springframework.security:spring-security-oauth2-jose ---
        ResolvedDependency(
          artifact:
              'org.springframework.security:spring-security-oauth2-jose:6.5.1',
          spec: defaultSpec,
          sha1: '',
          isDirect: false,
          dependencies: [
            'com.nimbusds:nimbus-jose-jwt:9.37.3',
            'org.springframework.security:spring-security-core:6.5.1',
            'org.springframework.security:spring-security-oauth2-core:6.5.1',
            'org.springframework:spring-core:6.2.7',
          ],
          licenses: [DependencyLicense(name: 'Apache-2.0', url: '')],
        ),
      ];

      final actualDependencies = collector.resolvedDeps.dependencies;

      expect(
        actualDependencies.map((d) => d.artifact).toSet(),
        equals(expectedDependencies.map((d) => d.artifact).toSet()),
      );

      for (final expected in expectedDependencies) {
        final actual = actualDependencies.firstWhere(
          (d) => d.artifact == expected.artifact,
        );
        expect(actual, equals(expected));
      }

      expect(
        collector.resolvedDeps.warnings,
        equals([
          DependencyWarning(
            artifact: 'org.slf4j:slf4j-api',
            versionConflicts: [
              VersionConflict(
                version: '2.0.16',
                requestedBy: [
                  'org.springframework.boot:spring-boot-starter:3.5.3',
                  'org.springframework.boot:spring-boot-starter-logging:3.5.3',
                  'org.apache.logging.log4j:log4j-to-slf4j:2.24.3',
                  'org.slf4j:slf4j-api:2.0.16',
                ],
              ),
              VersionConflict(
                version: '2.0.17',
                requestedBy: [
                  'org.springframework.boot:spring-boot-starter:3.5.3',
                  'org.springframework.boot:spring-boot-starter-logging:3.5.3',
                  'ch.qos.logback:logback-classic:1.5.18',
                  'org.slf4j:slf4j-api:2.0.17',
                ],
              ),
            ],
          ),
          DependencyWarning(
            artifact: 'org.springframework:spring-jcl',
            versionConflicts: [
              VersionConflict(
                version: '6.2.8',
                requestedBy: [
                  'org.springframework.boot:spring-boot-starter:3.5.3',
                  'org.springframework.boot:spring-boot-autoconfigure:3.5.3',
                  'org.springframework.boot:spring-boot:3.5.3',
                  'org.springframework:spring-context:6.2.8',
                  'org.springframework:spring-aop:6.2.8',
                  'org.springframework:spring-beans:6.2.8',
                  'org.springframework:spring-core:6.2.8',
                  'org.springframework:spring-jcl:6.2.8',
                ],
              ),
              VersionConflict(
                version: '6.2.7',
                requestedBy: [
                  'org.springframework.security:spring-security-config:6.5.1',
                  'org.springframework.security:spring-security-core:6.5.1',
                  'org.springframework:spring-aop:6.2.7',
                  'org.springframework:spring-beans:6.2.7',
                  'org.springframework:spring-core:6.2.7',
                  'org.springframework:spring-jcl:6.2.7',
                ],
              ),
            ],
          ),
          DependencyWarning(
            artifact: 'org.springframework:spring-context',
            versionConflicts: [
              VersionConflict(
                version: '6.2.8',
                requestedBy: [
                  'org.springframework.boot:spring-boot-starter:3.5.3',
                  'org.springframework.boot:spring-boot-autoconfigure:3.5.3',
                  'org.springframework.boot:spring-boot:3.5.3',
                  'org.springframework:spring-context:6.2.8',
                ],
              ),
              VersionConflict(
                version: '6.2.7',
                requestedBy: [
                  'org.springframework.security:spring-security-config:6.5.1',
                  'org.springframework.security:spring-security-core:6.5.1',
                  'org.springframework:spring-context:6.2.7',
                ],
              ),
            ],
          ),
          DependencyWarning(
            artifact: 'io.micrometer:micrometer-commons',
            versionConflicts: [
              VersionConflict(
                version: '1.14.8',
                requestedBy: [
                  'org.springframework.boot:spring-boot-starter:3.5.3',
                  'org.springframework.boot:spring-boot-autoconfigure:3.5.3',
                  'org.springframework.boot:spring-boot:3.5.3',
                  'org.springframework:spring-context:6.2.8',
                  'io.micrometer:micrometer-observation:1.14.8',
                  'io.micrometer:micrometer-commons:1.14.8',
                ],
              ),
              VersionConflict(
                version: '1.14.7',
                requestedBy: [
                  'org.springframework.security:spring-security-config:6.5.1',
                  'org.springframework.security:spring-security-core:6.5.1',
                  'org.springframework:spring-context:6.2.7',
                  'io.micrometer:micrometer-observation:1.14.7',
                  'io.micrometer:micrometer-commons:1.14.7',
                ],
              ),
            ],
          ),
          DependencyWarning(
            artifact: 'org.springframework:spring-aop',
            versionConflicts: [
              VersionConflict(
                version: '6.2.8',
                requestedBy: [
                  'org.springframework.boot:spring-boot-starter:3.5.3',
                  'org.springframework.boot:spring-boot-autoconfigure:3.5.3',
                  'org.springframework.boot:spring-boot:3.5.3',
                  'org.springframework:spring-context:6.2.8',
                  'org.springframework:spring-aop:6.2.8',
                ],
              ),
              VersionConflict(
                version: '6.2.7',
                requestedBy: [
                  'org.springframework.security:spring-security-config:6.5.1',
                  'org.springframework.security:spring-security-core:6.5.1',
                  'org.springframework:spring-aop:6.2.7',
                ],
              ),
            ],
          ),
          DependencyWarning(
            artifact: 'org.slf4j:slf4j-api',
            versionConflicts: [
              VersionConflict(
                version: '2.0.16',
                requestedBy: [
                  'org.springframework.boot:spring-boot-starter:3.5.3',
                  'org.springframework.boot:spring-boot-starter-logging:3.5.3',
                  'org.apache.logging.log4j:log4j-to-slf4j:2.24.3',
                  'org.slf4j:slf4j-api:2.0.16',
                ],
              ),
              VersionConflict(
                version: '2.0.17',
                requestedBy: [
                  'org.springframework.boot:spring-boot-starter:3.5.3',
                  'org.springframework.boot:spring-boot-starter-logging:3.5.3',
                  'ch.qos.logback:logback-classic:1.5.18',
                  'org.slf4j:slf4j-api:2.0.17',
                ],
              ),
            ],
          ),
          DependencyWarning(
            artifact: 'org.springframework:spring-core',
            versionConflicts: [
              VersionConflict(
                version: '6.2.8',
                requestedBy: [
                  'org.springframework.boot:spring-boot-starter:3.5.3',
                  'org.springframework.boot:spring-boot-autoconfigure:3.5.3',
                  'org.springframework.boot:spring-boot:3.5.3',
                  'org.springframework:spring-context:6.2.8',
                  'org.springframework:spring-aop:6.2.8',
                  'org.springframework:spring-beans:6.2.8',
                  'org.springframework:spring-core:6.2.8',
                ],
              ),
              VersionConflict(
                version: '6.2.7',
                requestedBy: [
                  'org.springframework.security:spring-security-config:6.5.1',
                  'org.springframework.security:spring-security-core:6.5.1',
                  'org.springframework:spring-aop:6.2.7',
                  'org.springframework:spring-beans:6.2.7',
                  'org.springframework:spring-core:6.2.7',
                ],
              ),
            ],
          ),
          DependencyWarning(
            artifact: 'org.springframework:spring-beans',
            versionConflicts: [
              VersionConflict(
                version: '6.2.8',
                requestedBy: [
                  'org.springframework.boot:spring-boot-starter:3.5.3',
                  'org.springframework.boot:spring-boot-autoconfigure:3.5.3',
                  'org.springframework.boot:spring-boot:3.5.3',
                  'org.springframework:spring-context:6.2.8',
                  'org.springframework:spring-aop:6.2.8',
                  'org.springframework:spring-beans:6.2.8',
                ],
              ),
              VersionConflict(
                version: '6.2.7',
                requestedBy: [
                  'org.springframework.security:spring-security-config:6.5.1',
                  'org.springframework.security:spring-security-core:6.5.1',
                  'org.springframework:spring-aop:6.2.7',
                  'org.springframework:spring-beans:6.2.7',
                ],
              ),
            ],
          ),
          DependencyWarning(
            artifact: 'org.springframework:spring-expression',
            versionConflicts: [
              VersionConflict(
                version: '6.2.8',
                requestedBy: [
                  'org.springframework.boot:spring-boot-starter:3.5.3',
                  'org.springframework.boot:spring-boot-autoconfigure:3.5.3',
                  'org.springframework.boot:spring-boot:3.5.3',
                  'org.springframework:spring-context:6.2.8',
                  'org.springframework:spring-expression:6.2.8',
                ],
              ),
              VersionConflict(
                version: '6.2.7',
                requestedBy: [
                  'org.springframework.security:spring-security-config:6.5.1',
                  'org.springframework.security:spring-security-core:6.5.1',
                  'org.springframework:spring-context:6.2.7',
                  'org.springframework:spring-expression:6.2.7',
                ],
              ),
            ],
          ),
          DependencyWarning(
            artifact: 'io.micrometer:micrometer-observation',
            versionConflicts: [
              VersionConflict(
                version: '1.14.8',
                requestedBy: [
                  'org.springframework.boot:spring-boot-starter:3.5.3',
                  'org.springframework.boot:spring-boot-autoconfigure:3.5.3',
                  'org.springframework.boot:spring-boot:3.5.3',
                  'org.springframework:spring-context:6.2.8',
                  'io.micrometer:micrometer-observation:1.14.8',
                ],
              ),
              VersionConflict(
                version: '1.14.7',
                requestedBy: [
                  'org.springframework.security:spring-security-config:6.5.1',
                  'org.springframework.security:spring-security-core:6.5.1',
                  'org.springframework:spring-context:6.2.7',
                  'io.micrometer:micrometer-observation:1.14.7',
                ],
              ),
            ],
          ),
        ]),
      );
    });
  });
}
