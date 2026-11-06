import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:args/args.dart';
import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart'
    show
        ArgsValidator,
        homeDir,
        failBuild,
        execProc,
        profile,
        tempDir,
        tempFile,
        elapsedTime;
import 'package:jb/src/crypto.dart';
import 'package:path/path.dart' as p;

import 'config.dart';
import 'dependencies/deps_cache.dart';
import 'maven_client.dart';
import 'optional_arg_validator.dart';
import 'pom.dart';
import 'resolved_dependency.dart';
import 'utils.dart';

/// A Maven repository publisher.
class Publisher(
  final Result<Artifact> artifact,
  final File depsFile,
  final DepsCache depsCache,
  final ResolvedLocalDependencies localDependencies,
  final String? jar,
) {
  static final ArgsValidator argsValidator = const OptionalArgValidator(
    'The following arguments may be provided:\n'
    '  * local dir or http(s) URL,\n'
    '  * -m for Maven Central\n'
    '  * --no-sign to skip signing artifacts.',
  );

  static const _signFlag = 'sign';
  static const _mavenCentralFlag = 'maven-central';

  static final _argParser = ArgParser()
    ..addFlag(
      _mavenCentralFlag,
      abbr: 'm',
      negatable: false,
      defaultsTo: false,
      help: 'Publish to Maven Central',
    )
    ..addFlag(
      _signFlag,
      negatable: true,
      defaultsTo: true,
      help: 'Sign artifacts before publishing',
    );

  /// The `publish` task action.
  Future<void> call(List<String> args) async {
    final theArtifact = _getArtifact();

    final argResults = _argParser.parse(args);
    final sign = argResults.flag(_signFlag);
    final toMavenCentral = argResults.flag(_mavenCentralFlag);
    final rest = argResults.rest;
    final destination = switch (rest.length) {
      0 => _mavenHome(),
      1 => rest[0],
      _ => throw ArgumentError(
        'Too many arguments: $rest.\n${_argParser.usage}',
      ),
    };

    final credentials = _mavenCredentials();

    final mavenClient = MavenClient(switch (destination) {
      '-m' => Sonatype.s01Oss,
      _ => CustomMavenRepo(destination),
    }, credentials: credentials);

    final toHttpRepo =
        !toMavenCentral &&
        (destination.startsWith('http://') ||
            destination.startsWith('https://'));

    final stopwatch = Stopwatch()..start();

    if (toMavenCentral || toHttpRepo) {
      if (credentials == null) {
        logger.info(
          'No HTTP credentials provided (set either SONATYPE_USER_TOKEN '
          'or MAVEN_USER and MAVEN_PASSWORD to provide it)',
        );
      }
      return await _publishHttp(mavenClient, theArtifact, sign, stopwatch);
    }
    await _publishLocal(theArtifact, destination, sign, depsCache, stopwatch);
  }

  String _mavenHome() {
    final mavenHome = Platform.environment['MAVEN_LOCAL_HOME'];
    if (mavenHome != null) {
      logger.finer(
        () =>
            'MAVEN_LOCAL_HOME environment variable will be used for publishing: $mavenHome',
      );
      return mavenHome;
    }
    logger.finer(
      () =>
          'MAVEN_HOME environment variable is not set, will use '
          '~/.m2/repository for publishing',
    );
    final home = homeDir().orThrow(
      () => failBuild(reason: 'Cannot find home directory'),
    );
    return p.join(home, '.m2', 'repository');
  }

  Artifact _getArtifact() {
    return switch (artifact) {
      Ok(value: var a) => a,
      Fail(exception: var e) => throw e,
    };
  }

  Future<void> _publishLocal(
    Artifact theArtifact,
    String repoPath,
    bool sign,
    DepsCache depsCache,
    Stopwatch stopwatch,
  ) async {
    final destination = Directory(_pathFor(theArtifact, parent: repoPath));
    logger.info(() => 'Publishing artifacts to ${destination.path}');
    await _publishArtifactToDir(
      destination,
      theArtifact,
      sign,
      depsCache,
      stopwatch,
    );
  }

  Future<void> _publishHttp(
    MavenClient mavenClient,
    Artifact theArtifact,
    bool sign,
    Stopwatch stopwatch,
  ) async {
    final destination = tempDir(suffix: '-jb-publish');
    logger.info(
      () =>
          'Creating publication artifacts at ${destination.path}, '
          'will publish to ${mavenClient.repo.url}',
    );
    await _publishArtifactToDir(
      destination,
      _getArtifact(),
      sign,
      depsCache,
      stopwatch,
    );
    logger.fine(() => 'Creating bundle.jar with publication artifacts');
    final bundle = await _createBundle(_getArtifact(), destination, stopwatch);
    logger.info(() => 'Publishing artifacts to ${mavenClient.repo.url}');
    try {
      await mavenClient.publish(theArtifact, bundle);
    } finally {
      mavenClient.close();
    }
  }

  Future<void> _publishArtifactToDir(
    Directory destination,
    Artifact artifact,
    bool sign,
    DepsCache depsCache,
    Stopwatch stopwatch,
  ) async {
    // ignore error intentionally
    await catching(() => destination.delete(recursive: true));
    // create an empty directory
    await destination.create(recursive: true);
    // the jar is verified by the publicationCompile task,
    // so this should never fail
    final jarFile = jar.ifBlank(() => 'Cannot publish, jar was not provided');

    stopwatch.reset();
    final deps = await depsCache.send(GetDeps(depsFile.path));
    logger.log(
      profile,
      'Parsed dependencies file in ${elapsedTime(stopwatch)}.',
    );
    stopwatch.reset();

    final pom = createPom(artifact, deps.dependencies, localDependencies);

    logger.log(profile, () => 'Created POM in ${elapsedTime(stopwatch)}.');
    stopwatch.reset();

    await _publishFiles(destination, artifact, sign, pom, jarFile);

    logger.log(
      profile,
      () => 'Created publication artifacts in ${elapsedTime(stopwatch)}.',
    );
  }

  Future<void> _publishFiles(
    Directory destination,
    Artifact artifact,
    bool sign,
    String pom,
    String jarFile,
  ) async {
    final postProcess = parallelize([_createChecksums, if (sign) _signFile]);
    await File(p.join(destination.path, _fileFor(artifact, extension: '.pom')))
        .writeAsString(pom)
        .then(postProcess);
    await File(jarFile)
        .copy(p.join(destination.path, _fileFor(artifact)))
        .then(postProcess);
    await File(jarFile.replaceExtension('-sources.jar'))
        .rename(
          p.join(destination.path, _fileFor(artifact, qualifier: '-sources')),
        )
        .then(postProcess);
    await File(jarFile.replaceExtension('-javadoc.jar'))
        .rename(
          p.join(destination.path, _fileFor(artifact, qualifier: '-javadoc')),
        )
        .then(postProcess);
  }

  Future<void> _createChecksums(File file) async {
    final bytes = await file.readAsBytes();
    final f1 = _shaFile(file.path, bytes);
    final f2 = _md5File(file.path, bytes);
    await Future.wait(<Future<Object?>>[f1, f2]);
  }

  Future<File> _createBundle(
    Artifact artifact,
    Directory directory,
    Stopwatch stopwatch,
  ) async {
    final bundle = tempFile(extension: '.zip');
    logger.fine(() => 'Creating publication bundle at ${bundle.path}');
    stopwatch.reset();

    final encoder = ZipFileEncoder();
    encoder.create(bundle.path);

    final zipRootDir = _pathFor(artifact, osSeparator: false);
    try {
      await for (final entity in directory.list()) {
        if (entity is File) {
          await encoder.addFile(
            entity,
            '$zipRootDir/${p.basename(entity.path)}',
          );
        }
      }
    } finally {
      await encoder.close();
    }

    logger.log(
      profile,
      () =>
          'Created publication bundle at ${bundle.path} '
          'in ${elapsedTime(stopwatch)}.',
    );

    return bundle;
  }
}

HttpClientCredentials? _mavenCredentials() {
  final mavenUser = Platform.environment['MAVEN_USER'];
  final mavenPassword = Platform.environment['MAVEN_PASSWORD'];
  String? token;
  if (mavenUser != null && mavenPassword != null) {
    logger.info('Using MAVEN_USER and MAVEN_PASSWORD for HTTP credentials');
    token = base64Encode(utf8.encode("$mavenUser:$mavenPassword"));
  }
  if (token == null) {
    token = Platform.environment['SONATYPE_USER_TOKEN'];
    if (token != null) {
      logger.info('Using SONATYPE_USER_TOKEN for HTTP credentials');
    }
  }
  if (token != null) {
    return HttpClientBearerCredentials(token);
  }
  return null;
}

Future<void> _shaFile(String file, List<int> bytes) async {
  logger.finer(() => 'Computing SHA1 of $file');
  await File('$file.sha1').writeAsString(await computeSha1(file));
  logger.finer(() => 'Computed SHA1 of $file');
}

Future<void> _md5File(String file, List<int> bytes) async {
  logger.finer(() => 'Computing MD5 of $file');
  await File('$file.md5').writeAsString(await computeMd5(file));
  logger.finer(() => 'Computed MD5 of $file');
}

// remember if GPG fails so we don't try again
bool _gpgExists = true;

Future<File> _signFile(File file) async {
  if (_gpgExists) {
    logger.info(() => 'Signing $file');
    try {
      await execProc(
        Process.start('gpg', [
          '--armor',
          '--detach-sign',
          '--pinentry-mode',
          'loopback',
          file.path,
        ]),
      );
      logger.finer(() => 'Signed $file');
    } catch (e) {
      logger.warning('Unable to sign artifacts as "gpg" failed ($e)!');
      _gpgExists = false;
    }
  } else {
    logger.finer(() => 'Skipping "gpg" signature for $file.');
  }
  return file;
}

String _pathFor(Artifact artifact, {String? parent, bool osSeparator = true}) {
  return [
    ?parent,
    ...artifact.group.split('.'),
    artifact.module,
    artifact.version,
  ].join(osSeparator ? Platform.pathSeparator : '/');
}

String _fileFor(
  Artifact artifact, {
  String qualifier = '',
  String extension = '.jar',
}) => '${artifact.module}-${artifact.version}$qualifier$extension';
