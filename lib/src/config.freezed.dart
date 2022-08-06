// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target

part of 'config.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

CompileConfiguration _$CompileConfigurationFromJson(Map<String, dynamic> json) {
  return _Config.fromJson(json);
}

/// @nodoc
mixin _$CompileConfiguration {
  Set<String> get sourceDirs => throw _privateConstructorUsedError;
  Set<String> get classpath => throw _privateConstructorUsedError;
  CompileOutput get output => throw _privateConstructorUsedError;
  Set<String> get resourceDirs => throw _privateConstructorUsedError;
  String get mainClass => throw _privateConstructorUsedError;
  List<String> get javacArgs => throw _privateConstructorUsedError;
  Set<String> get dependencies => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $CompileConfigurationCopyWith<CompileConfiguration> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CompileConfigurationCopyWith<$Res> {
  factory $CompileConfigurationCopyWith(CompileConfiguration value,
          $Res Function(CompileConfiguration) then) =
      _$CompileConfigurationCopyWithImpl<$Res>;
  $Res call(
      {Set<String> sourceDirs,
      Set<String> classpath,
      CompileOutput output,
      Set<String> resourceDirs,
      String mainClass,
      List<String> javacArgs,
      Set<String> dependencies});

  $CompileOutputCopyWith<$Res> get output;
}

/// @nodoc
class _$CompileConfigurationCopyWithImpl<$Res>
    implements $CompileConfigurationCopyWith<$Res> {
  _$CompileConfigurationCopyWithImpl(this._value, this._then);

  final CompileConfiguration _value;
  // ignore: unused_field
  final $Res Function(CompileConfiguration) _then;

  @override
  $Res call({
    Object? sourceDirs = freezed,
    Object? classpath = freezed,
    Object? output = freezed,
    Object? resourceDirs = freezed,
    Object? mainClass = freezed,
    Object? javacArgs = freezed,
    Object? dependencies = freezed,
  }) {
    return _then(_value.copyWith(
      sourceDirs: sourceDirs == freezed
          ? _value.sourceDirs
          : sourceDirs // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      classpath: classpath == freezed
          ? _value.classpath
          : classpath // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      output: output == freezed
          ? _value.output
          : output // ignore: cast_nullable_to_non_nullable
              as CompileOutput,
      resourceDirs: resourceDirs == freezed
          ? _value.resourceDirs
          : resourceDirs // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      mainClass: mainClass == freezed
          ? _value.mainClass
          : mainClass // ignore: cast_nullable_to_non_nullable
              as String,
      javacArgs: javacArgs == freezed
          ? _value.javacArgs
          : javacArgs // ignore: cast_nullable_to_non_nullable
              as List<String>,
      dependencies: dependencies == freezed
          ? _value.dependencies
          : dependencies // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }

  @override
  $CompileOutputCopyWith<$Res> get output {
    return $CompileOutputCopyWith<$Res>(_value.output, (value) {
      return _then(_value.copyWith(output: value));
    });
  }
}

/// @nodoc
abstract class _$$_ConfigCopyWith<$Res>
    implements $CompileConfigurationCopyWith<$Res> {
  factory _$$_ConfigCopyWith(_$_Config value, $Res Function(_$_Config) then) =
      __$$_ConfigCopyWithImpl<$Res>;
  @override
  $Res call(
      {Set<String> sourceDirs,
      Set<String> classpath,
      CompileOutput output,
      Set<String> resourceDirs,
      String mainClass,
      List<String> javacArgs,
      Set<String> dependencies});

  @override
  $CompileOutputCopyWith<$Res> get output;
}

/// @nodoc
class __$$_ConfigCopyWithImpl<$Res>
    extends _$CompileConfigurationCopyWithImpl<$Res>
    implements _$$_ConfigCopyWith<$Res> {
  __$$_ConfigCopyWithImpl(_$_Config _value, $Res Function(_$_Config) _then)
      : super(_value, (v) => _then(v as _$_Config));

  @override
  _$_Config get _value => super._value as _$_Config;

  @override
  $Res call({
    Object? sourceDirs = freezed,
    Object? classpath = freezed,
    Object? output = freezed,
    Object? resourceDirs = freezed,
    Object? mainClass = freezed,
    Object? javacArgs = freezed,
    Object? dependencies = freezed,
  }) {
    return _then(_$_Config(
      sourceDirs: sourceDirs == freezed
          ? _value._sourceDirs
          : sourceDirs // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      classpath: classpath == freezed
          ? _value._classpath
          : classpath // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      output: output == freezed
          ? _value.output
          : output // ignore: cast_nullable_to_non_nullable
              as CompileOutput,
      resourceDirs: resourceDirs == freezed
          ? _value._resourceDirs
          : resourceDirs // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      mainClass: mainClass == freezed
          ? _value.mainClass
          : mainClass // ignore: cast_nullable_to_non_nullable
              as String,
      javacArgs: javacArgs == freezed
          ? _value._javacArgs
          : javacArgs // ignore: cast_nullable_to_non_nullable
              as List<String>,
      dependencies: dependencies == freezed
          ? _value._dependencies
          : dependencies // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_Config extends _Config {
  const _$_Config(
      {final Set<String> sourceDirs = const {'src/main/java', 'src'},
      final Set<String> classpath = const {},
      this.output = const CompileOutput.dir('out'),
      final Set<String> resourceDirs = const {
        'src/main/resources',
        'resources'
      },
      this.mainClass = '',
      final List<String> javacArgs = const [],
      final Set<String> dependencies = const {}})
      : _sourceDirs = sourceDirs,
        _classpath = classpath,
        _resourceDirs = resourceDirs,
        _javacArgs = javacArgs,
        _dependencies = dependencies,
        super._();

  factory _$_Config.fromJson(Map<String, dynamic> json) =>
      _$$_ConfigFromJson(json);

  final Set<String> _sourceDirs;
  @override
  @JsonKey()
  Set<String> get sourceDirs {
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_sourceDirs);
  }

  final Set<String> _classpath;
  @override
  @JsonKey()
  Set<String> get classpath {
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_classpath);
  }

  @override
  @JsonKey()
  final CompileOutput output;
  final Set<String> _resourceDirs;
  @override
  @JsonKey()
  Set<String> get resourceDirs {
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_resourceDirs);
  }

  @override
  @JsonKey()
  final String mainClass;
  final List<String> _javacArgs;
  @override
  @JsonKey()
  List<String> get javacArgs {
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_javacArgs);
  }

  final Set<String> _dependencies;
  @override
  @JsonKey()
  Set<String> get dependencies {
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_dependencies);
  }

  @override
  String toString() {
    return 'CompileConfiguration(sourceDirs: $sourceDirs, classpath: $classpath, output: $output, resourceDirs: $resourceDirs, mainClass: $mainClass, javacArgs: $javacArgs, dependencies: $dependencies)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_Config &&
            const DeepCollectionEquality()
                .equals(other._sourceDirs, _sourceDirs) &&
            const DeepCollectionEquality()
                .equals(other._classpath, _classpath) &&
            const DeepCollectionEquality().equals(other.output, output) &&
            const DeepCollectionEquality()
                .equals(other._resourceDirs, _resourceDirs) &&
            const DeepCollectionEquality().equals(other.mainClass, mainClass) &&
            const DeepCollectionEquality()
                .equals(other._javacArgs, _javacArgs) &&
            const DeepCollectionEquality()
                .equals(other._dependencies, _dependencies));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_sourceDirs),
      const DeepCollectionEquality().hash(_classpath),
      const DeepCollectionEquality().hash(output),
      const DeepCollectionEquality().hash(_resourceDirs),
      const DeepCollectionEquality().hash(mainClass),
      const DeepCollectionEquality().hash(_javacArgs),
      const DeepCollectionEquality().hash(_dependencies));

  @JsonKey(ignore: true)
  @override
  _$$_ConfigCopyWith<_$_Config> get copyWith =>
      __$$_ConfigCopyWithImpl<_$_Config>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_ConfigToJson(
      this,
    );
  }
}

abstract class _Config extends CompileConfiguration {
  const factory _Config(
      {final Set<String> sourceDirs,
      final Set<String> classpath,
      final CompileOutput output,
      final Set<String> resourceDirs,
      final String mainClass,
      final List<String> javacArgs,
      final Set<String> dependencies}) = _$_Config;
  const _Config._() : super._();

  factory _Config.fromJson(Map<String, dynamic> json) = _$_Config.fromJson;

  @override
  Set<String> get sourceDirs;
  @override
  Set<String> get classpath;
  @override
  CompileOutput get output;
  @override
  Set<String> get resourceDirs;
  @override
  String get mainClass;
  @override
  List<String> get javacArgs;
  @override
  Set<String> get dependencies;
  @override
  @JsonKey(ignore: true)
  _$$_ConfigCopyWith<_$_Config> get copyWith =>
      throw _privateConstructorUsedError;
}

CompileOutput _$CompileOutputFromJson(Map<String, dynamic> json) {
  switch (json['runtimeType']) {
    case 'dir':
      return Dir.fromJson(json);
    case 'jar':
      return Jar.fromJson(json);

    default:
      throw CheckedFromJsonException(json, 'runtimeType', 'CompileOutput',
          'Invalid union type "${json['runtimeType']}"!');
  }
}

/// @nodoc
mixin _$CompileOutput {
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String directory) dir,
    required TResult Function(String jar) jar,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult Function(String directory)? dir,
    TResult Function(String jar)? jar,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String directory)? dir,
    TResult Function(String jar)? jar,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Dir value) dir,
    required TResult Function(Jar value) jar,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult Function(Dir value)? dir,
    TResult Function(Jar value)? jar,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Dir value)? dir,
    TResult Function(Jar value)? jar,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CompileOutputCopyWith<$Res> {
  factory $CompileOutputCopyWith(
          CompileOutput value, $Res Function(CompileOutput) then) =
      _$CompileOutputCopyWithImpl<$Res>;
}

/// @nodoc
class _$CompileOutputCopyWithImpl<$Res>
    implements $CompileOutputCopyWith<$Res> {
  _$CompileOutputCopyWithImpl(this._value, this._then);

  final CompileOutput _value;
  // ignore: unused_field
  final $Res Function(CompileOutput) _then;
}

/// @nodoc
abstract class _$$DirCopyWith<$Res> {
  factory _$$DirCopyWith(_$Dir value, $Res Function(_$Dir) then) =
      __$$DirCopyWithImpl<$Res>;
  $Res call({String directory});
}

/// @nodoc
class __$$DirCopyWithImpl<$Res> extends _$CompileOutputCopyWithImpl<$Res>
    implements _$$DirCopyWith<$Res> {
  __$$DirCopyWithImpl(_$Dir _value, $Res Function(_$Dir) _then)
      : super(_value, (v) => _then(v as _$Dir));

  @override
  _$Dir get _value => super._value as _$Dir;

  @override
  $Res call({
    Object? directory = freezed,
  }) {
    return _then(_$Dir(
      directory == freezed
          ? _value.directory
          : directory // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$Dir implements Dir {
  const _$Dir(this.directory, {final String? $type}) : $type = $type ?? 'dir';

  factory _$Dir.fromJson(Map<String, dynamic> json) => _$$DirFromJson(json);

  @override
  final String directory;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'CompileOutput.dir(directory: $directory)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Dir &&
            const DeepCollectionEquality().equals(other.directory, directory));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(directory));

  @JsonKey(ignore: true)
  @override
  _$$DirCopyWith<_$Dir> get copyWith =>
      __$$DirCopyWithImpl<_$Dir>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String directory) dir,
    required TResult Function(String jar) jar,
  }) {
    return dir(directory);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult Function(String directory)? dir,
    TResult Function(String jar)? jar,
  }) {
    return dir?.call(directory);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String directory)? dir,
    TResult Function(String jar)? jar,
    required TResult orElse(),
  }) {
    if (dir != null) {
      return dir(directory);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Dir value) dir,
    required TResult Function(Jar value) jar,
  }) {
    return dir(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult Function(Dir value)? dir,
    TResult Function(Jar value)? jar,
  }) {
    return dir?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Dir value)? dir,
    TResult Function(Jar value)? jar,
    required TResult orElse(),
  }) {
    if (dir != null) {
      return dir(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$DirToJson(
      this,
    );
  }
}

abstract class Dir implements CompileOutput {
  const factory Dir(final String directory) = _$Dir;

  factory Dir.fromJson(Map<String, dynamic> json) = _$Dir.fromJson;

  String get directory;
  @JsonKey(ignore: true)
  _$$DirCopyWith<_$Dir> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$JarCopyWith<$Res> {
  factory _$$JarCopyWith(_$Jar value, $Res Function(_$Jar) then) =
      __$$JarCopyWithImpl<$Res>;
  $Res call({String jar});
}

/// @nodoc
class __$$JarCopyWithImpl<$Res> extends _$CompileOutputCopyWithImpl<$Res>
    implements _$$JarCopyWith<$Res> {
  __$$JarCopyWithImpl(_$Jar _value, $Res Function(_$Jar) _then)
      : super(_value, (v) => _then(v as _$Jar));

  @override
  _$Jar get _value => super._value as _$Jar;

  @override
  $Res call({
    Object? jar = freezed,
  }) {
    return _then(_$Jar(
      jar == freezed
          ? _value.jar
          : jar // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$Jar implements Jar {
  const _$Jar(this.jar, {final String? $type}) : $type = $type ?? 'jar';

  factory _$Jar.fromJson(Map<String, dynamic> json) => _$$JarFromJson(json);

  @override
  final String jar;

  @JsonKey(name: 'runtimeType')
  final String $type;

  @override
  String toString() {
    return 'CompileOutput.jar(jar: $jar)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$Jar &&
            const DeepCollectionEquality().equals(other.jar, jar));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(jar));

  @JsonKey(ignore: true)
  @override
  _$$JarCopyWith<_$Jar> get copyWith =>
      __$$JarCopyWithImpl<_$Jar>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(String directory) dir,
    required TResult Function(String jar) jar,
  }) {
    return jar(this.jar);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult Function(String directory)? dir,
    TResult Function(String jar)? jar,
  }) {
    return jar?.call(this.jar);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(String directory)? dir,
    TResult Function(String jar)? jar,
    required TResult orElse(),
  }) {
    if (jar != null) {
      return jar(this.jar);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(Dir value) dir,
    required TResult Function(Jar value) jar,
  }) {
    return jar(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult Function(Dir value)? dir,
    TResult Function(Jar value)? jar,
  }) {
    return jar?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(Dir value)? dir,
    TResult Function(Jar value)? jar,
    required TResult orElse(),
  }) {
    if (jar != null) {
      return jar(this);
    }
    return orElse();
  }

  @override
  Map<String, dynamic> toJson() {
    return _$$JarToJson(
      this,
    );
  }
}

abstract class Jar implements CompileOutput {
  const factory Jar(final String jar) = _$Jar;

  factory Jar.fromJson(Map<String, dynamic> json) = _$Jar.fromJson;

  String get jar;
  @JsonKey(ignore: true)
  _$$JarCopyWith<_$Jar> get copyWith => throw _privateConstructorUsedError;
}
