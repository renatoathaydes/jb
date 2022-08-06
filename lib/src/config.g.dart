// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Config _$$_ConfigFromJson(Map<String, dynamic> json) => _$_Config(
      sourceDirs: (json['sourceDirs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const {'src/main/java', 'src'},
      classpath: (json['classpath'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const {},
      output: json['output'] == null
          ? const CompileOutput.dir('out')
          : CompileOutput.fromJson(json['output'] as Map<String, dynamic>),
      resourceDirs: (json['resourceDirs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const {'src/main/resources', 'resources'},
      mainClass: json['mainClass'] as String? ?? '',
      javacArgs: (json['javacArgs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      dependencies: (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          const {},
    );

Map<String, dynamic> _$$_ConfigToJson(_$_Config instance) => <String, dynamic>{
      'sourceDirs': instance.sourceDirs.toList(),
      'classpath': instance.classpath.toList(),
      'output': instance.output,
      'resourceDirs': instance.resourceDirs.toList(),
      'mainClass': instance.mainClass,
      'javacArgs': instance.javacArgs,
      'dependencies': instance.dependencies.toList(),
    };

_$Dir _$$DirFromJson(Map<String, dynamic> json) => _$Dir(
      json['directory'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$DirToJson(_$Dir instance) => <String, dynamic>{
      'directory': instance.directory,
      'runtimeType': instance.$type,
    };

_$Jar _$$JarFromJson(Map<String, dynamic> json) => _$Jar(
      json['jar'] as String,
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$$JarToJson(_$Jar instance) => <String, dynamic>{
      'jar': instance.jar,
      'runtimeType': instance.$type,
    };
