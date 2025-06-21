import 'ansi.dart';
import 'config.dart';
import 'maven_metadata.dart'
    show DeveloperExtension, SourceControlManagementExtension;

class ToYaml {
  final AnsiColor color;

  ToYaml(bool noColor) : color = createAnsiColor(noColor);

  String call(JbConfiguration config) {
    final extension = _extrasToYaml(config.extras);
    return '''
${color('''
######################## Full jb configuration ########################

### For more information, visit https://github.com/renatoathaydes/jb
''', commentColor)}
${color('# Maven artifact groupId', commentColor)}
group: ${_quote(config.group)}
${color('# Module name (Maven artifactId)', commentColor)}
module: ${_quote(config.module)}
${color('# Human readable name of this project', commentColor)}
name: ${_quote(config.name)}
${color('# Maven version', commentColor)}
version: ${_quote(config.version)}
${color('# Description for this project', commentColor)}
description: ${_quote(config.description)}
${color('# URL of this project', commentColor)}
url: ${_quote(config.url)}
${color('# Licenses this project uses', commentColor)}
licenses: [${config.licenses.map((lic) => _quote(lic)).join(', ')}]
${color('# Developers who have contributed to this project', commentColor)}
developers:${_developersToYaml(config.developers)}
${color('# Source control management', commentColor)}
scm:${_scmToYaml(config.scm)}
${color('# List of source directories', commentColor)}
source-dirs: [${config.sourceDirs.map(_quote).join(', ')}]
${color('# List of resource directories (assets)', commentColor)}
resource-dirs: [${config.resourceDirs.map(_quote).join(', ')}]
${color('# Output directory (class files)', commentColor)}
output-dir: ${_quote(config.outputDir)}
${color('# Output jar (may be used instead of output-dir)', commentColor)}
output-jar: ${_quote(config.outputJar)}
${color('# Java Main class name', commentColor)}
main-class: ${_quote(config.mainClass)}
${color('# Manifest file to include in the jar', commentColor)}
manifest: ${_quote(config.manifest)}
${color('# Java Compiler arguments', commentColor)}
javac-args: [${config.javacArgs.map(_quote).join(', ')}]
${color('# Java Compiler environment variables', commentColor)}
javac-env:${_mapToYaml(config.javacEnv)}
${color('# Java Runtime arguments', commentColor)}
run-java-args: [${config.runJavaArgs.map(_quote).join(', ')}]
${color('# Java Runtime environment variables', commentColor)}
run-java-env:${_mapToYaml(config.runJavaEnv)}
${color('# Java Test run arguments', commentColor)}
test-java-args: [${config.javacArgs.map(_quote).join(', ')}]
${color('# Java Test environment variables', commentColor)}
test-java-env:${_mapToYaml(config.testJavaEnv)}
${color('# Maven repositories (URLs or directories)', commentColor)}
repositories: [${config.repositories.map(_quote).join(', ')}]
${color('# Maven dependencies', commentColor)}
dependencies:${_depsToYaml(config.allDependencies)}
${color('# Dependency exclusions (regular expressions)', commentColor)}
dependency-exclusion-patterns:${_multilineList(config.dependencyExclusionPatterns.map(_quote))}
${color('# Annotation processor Maven dependencies', commentColor)}
processor-dependencies:${_depsToYaml(config.allProcessorDependencies)}
${color('# Annotation processor dependency exclusions (regular expressions)', commentColor)}
processor-dependency-exclusion-patterns:${_multilineList(config.processorDependencyExclusionPatterns.map(_quote))}
${color('# Compile-time libs output dir', commentColor)}
compile-libs-dir: ${_quote(config.compileLibsDir)}
${color('# Runtime libs output dir', commentColor)}
runtime-libs-dir: ${_quote(config.runtimeLibsDir)}
${color('# Test reports output dir', commentColor)}
test-reports-dir: ${_quote(config.testReportsDir)}
${color('# jb extension project path (for custom tasks)', commentColor)}
extension-project: ${_quote(config.extensionProject)}
$extension''';
  }

  String _quote(String? value) =>
      value == null ? color('null', kwColor) : color('"$value"', strColor);

  String _multilineList(Iterable<String> lines, {bool isMap = false}) {
    if (lines.isEmpty) {
      if (isMap) return ' {}';
      return ' []';
    }
    final dash = isMap ? '' : '- ';
    return '\n${lines.map((line) => '  $dash$line').join('\n')}';
  }

  String _depsToYaml(Iterable<MapEntry<String, DependencySpec>> deps) {
    return _multilineList(
      deps.map(
        (dep) => '${_quote(dep.key)}:\n${dep.value.toYaml(color, '    ')}',
      ),
      isMap: true,
    );
  }

  String _developersToYaml(Iterable<Developer> developers) {
    return _multilineList(developers.map((dev) => dev.toYaml(color, '    ')));
  }

  String _scmToYaml(SourceControlManagement? scm) {
    if (scm == null) return color(' null', kwColor);
    return '\n  ${scm.toYaml(color, '  ')}';
  }

  String _valueToYaml(
    Object? value, {
    String indent = '  ',
    bool useSpace = true,
  }) {
    final space = useSpace ? ' ' : '';
    return switch (value) {
      null => '$space${color('null', kwColor)}',
      String s => '$space${_quote(s)}',
      bool b => '$space${color(b.toString(), kwColor)}',
      num n => '$space${color(n.toString(), numColor)}',
      Iterable<Object?> iter =>
        '$space[${iter.map((e) => _valueToYaml(e, indent: ' $indent', useSpace: false)).join(', ')}]',
      Map<String, Object?> map => _mapToYaml(
        map,
        indent: '  $indent',
        useSpace: useSpace,
      ),
      _ => value.toString(),
    };
  }

  String _mapToYaml(
    Map<String, Object?> map, {
    String indent = '  ',
    bool useSpace = true,
  }) {
    if (map.isEmpty) return '${useSpace ? ' ' : ''}{}';
    return '\n${map.entries.map((e) => '$indent${_quote(e.key)}:'
        '${_valueToYaml(e.value, indent: '  $indent')}').join('\n')}';
  }

  String _extrasToYaml(Map<String, Object?> extras) {
    if (extras.isEmpty) return '';
    final header = color(
      '############################\n'
      '# Custom tasks configuration\n'
      '############################',
      commentColor,
    );
    final taskEntries = [
      for (final e in extras.entries)
        '${_quote(e.key)}:'
            '${_mapToYaml(e.value as Map<String, Object?>)}',
    ].join('\n');
    return '$header\n$taskEntries\n';
  }
}
