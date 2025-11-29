import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:conveniently/conveniently.dart';
import 'package:crypto/crypto.dart';
import 'package:dartle/dartle.dart'
    show
        ArgsValidator,
        homeDir,
        failBuild,
        execProc,
        profile,
        tempDir,
        tempFile;
import 'package:path/path.dart' as p;

import 'config.dart';
import 'dependencies/deps_cache.dart';
import 'maven_client.dart';
import 'optional_arg_validator.dart';
import 'pom.dart';
import 'resolved_dependency.dart';
import 'utils.dart';

/// A Maven repository publisher.
class Publisher {
  static final ArgsValidator argsValidator = const OptionalArgValidator(
    'One argument may be provided: '
    'a local dir, a http(s) URL, or '
    ':-m for Maven Central',
  );

  final Result<Artifact> artifact;
  final DepsCache depsCache;
  final File depsFile;
  final ResolvedLocalDependencies localDependencies;
  final String? jar;

  Publisher(
    this.artifact,
    this.depsFile,
    this.depsCache,
    this.localDependencies,
    this.jar,
  );

  /// The `publish` task action.
  Future<void> call(List<String> args) async {
    final theArtifact = _getArtifact();

    final destination = args.isEmpty ? _mavenHome() : args[0];

    final mavenClient = MavenClient(switch (destination) {
      '-m' => Sonatype.s01Oss,
      _ => CustomMavenRepo(destination),
    }, credentials: _mavenCredentials());

    final stopwatch = Stopwatch()..start();

    if (destination == '-m') {
      return await _publishHttp(mavenClient, theArtifact, stopwatch);
    }
    if (destination.startsWith('http://') ||
        destination.startsWith('https://')) {
      return await _publishHttp(mavenClient, theArtifact, stopwatch);
    }
    await _publishLocal(theArtifact, destination, depsCache, stopwatch);
  }

  String _mavenHome() {
    final mavenHome = Platform.environment['MAVEN_HOME'];
    if (mavenHome != null) {
      return mavenHome;
    }
    logger.finer(
      () =>
          'MAVEN_HOME environment variable is not set, will use ~/.m2/repository',
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
    DepsCache depsCache,
    Stopwatch stopwatch,
  ) async {
    final destination = Directory(_pathFor(theArtifact, parent: repoPath));
    logger.info(() => 'Publishing artifacts to ${destination.path}');
    await _publishArtifactToDir(destination, theArtifact, depsCache, stopwatch);
  }

  Future<void> _publishHttp(
    MavenClient mavenClient,
    Artifact theArtifact,
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
      'Parsed dependencies file in ${stopwatch.elapsedMilliseconds} ms',
    );
    stopwatch.reset();

    final pom = createPom(artifact, deps.dependencies, localDependencies);

    logger.log(
      profile,
      () => 'Created POM in ${stopwatch.elapsedMilliseconds} ms',
    );
    stopwatch.reset();

    await _publishFiles(destination, artifact, pom, jarFile);

    logger.log(
      profile,
      () =>
          'Created publication artifacts in '
          '${stopwatch.elapsedMilliseconds} ms',
    );
  }

  Future<void> _publishFiles(
    Directory destination,
    Artifact artifact,
    String pom,
    String jarFile,
  ) async {
    await File(
      p.join(destination.path, _fileFor(artifact, extension: '.pom')),
    ).writeAsString(pom).then(_createChecksumsAndSign);
    await File(jarFile)
        .copy(p.join(destination.path, _fileFor(artifact)))
        .then(_createChecksumsAndSign);
    await File(jarFile.replaceExtension('-sources.jar'))
        .rename(
          p.join(destination.path, _fileFor(artifact, qualifier: '-sources')),
        )
        .then(_createChecksumsAndSign);
    await File(jarFile.replaceExtension('-javadoc.jar'))
        .rename(
          p.join(destination.path, _fileFor(artifact, qualifier: '-javadoc')),
        )
        .then(_createChecksumsAndSign);
  }

  Future<void> _createChecksumsAndSign(File file) async {
    final bytes = await file.readAsBytes();
    final f1 = _signFile(file);
    final f2 = _shaFile(file.path, bytes);
    final f3 = _md5File(file.path, bytes);
    await Future.wait(<Future<Object?>>[f1, f2, f3]);
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
          'Created publication bundle at ${bundle.path} in '
          '${stopwatch.elapsedMilliseconds} ms.',
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
  logger.info(
    'No HTTP credentials provided (set either SONATYPE_USER_TOKEN '
    'or MAVEN_USER and MAVEN_PASSWORD to provide it)',
  );
  return null;
}

Future<void> _shaFile(String file, List<int> bytes) async {
  logger.finer(() => 'Computing SHA1 of $file');
  await File('$file.sha1').writeAsString(sha1.convert(bytes).toString());
  logger.finer(() => 'Computed SHA1 of $file');
}

Future<void> _md5File(String file, List<int> bytes) async {
  logger.finer(() => 'Computing MD5 of $file');
  await File('$file.md5').writeAsString(md5.convert(bytes).toString());
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
