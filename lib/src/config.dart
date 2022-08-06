import 'package:freezed_annotation/freezed_annotation.dart';

part 'config.freezed.dart';
part 'config.g.dart';

@freezed
class CompileConfiguration with _$CompileConfiguration {
  const factory CompileConfiguration({
    @Default({'src/main/java', 'src'}) Set<String> sourceDirs,
    @Default({}) Set<String> classpath,
    @Default(CompileOutput.dir('out')) CompileOutput output,
    @Default({'src/main/resources', 'resources'}) Set<String> resourceDirs,
    @Default('') String mainClass,
    @Default([]) List<String> javacArgs,
    @Default({}) Set<String> dependencies,
  }) = _Config;

  const CompileConfiguration._();

  factory CompileConfiguration.fromJson(Map<String, Object?> json) =>
      _$CompileConfigurationFromJson(json);

  List<String> asArgs() {
    final result = <String>[];
    result.addAll(sourceDirs);
    for (final cp in classpath) {
      result.addAll(['-cp', cp]);
    }
    output.when(
        dir: (d) => result.addAll(['-d', d]),
        jar: (j) => result.addAll(['-j', j]));
    for (final r in resourceDirs) {
      result.addAll(['-r', r]);
    }
    if (mainClass.isNotEmpty) {
      result.addAll(['-m', mainClass]);
    }
    if (javacArgs.isNotEmpty) {
      result.add('--');
      result.addAll(javacArgs);
    }
    return result;
  }
}

@freezed
class CompileOutput with _$CompileOutput {
  const factory CompileOutput.dir(String directory) = Dir;

  const factory CompileOutput.jar(String jar) = Jar;

  factory CompileOutput.fromJson(Map<String, Object?> json) =>
      _$CompileOutputFromJson(json);
}
