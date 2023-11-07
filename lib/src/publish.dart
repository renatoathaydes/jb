import 'dart:async';
import 'dart:io';

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
import 'maven_client.dart';
import 'optional_arg_validator.dart';
import 'pom.dart';
import 'resolved_dependency.dart';
import 'utils.dart';

/// A Maven repository publisher.
class Publisher {
  static final ArgsValidator argsValidator =
      const OptionalArgValidator('One argument may be provided: '
          'a local dir, a http(s) URL, or '
          ':-m (or :-n for the older repo) for Maven Central');

  final Result<Artifact> artifact;
  final Map<String, DependencySpec> dependencies;
  final ResolvedLocalDependencies localDependencies;
  final String? jar;

  Publisher(this.artifact, this.dependencies, this.localDependencies, this.jar);

  /// The `publish` task action.
  Future<void> call(List<String> args) async {
    final theArtifact = _getArtifact();
    final home = homeDir()
        .orThrow(() => failBuild(reason: 'Cannot find home directory'));

    final destination =
        args.isEmpty ? p.join(home, '.m2', 'repository') : args[0];

    final mavenClient = MavenClient(
        switch (destination) {
          '-m' => Sonatype.s01Oss,
          '-n' => Sonatype.oss,
          _ => CustomMavenRepo(destination),
        },
        credentials: _mavenCredentials());

    final stopwatch = Stopwatch()..start();

    if (destination == '-m') {
      return await _publishHttp(mavenClient, theArtifact, stopwatch);
    }
    if (destination == '-n') {
      return await _publishHttp(mavenClient, theArtifact, stopwatch);
    }
    if (destination.startsWith('http://') ||
        destination.startsWith('https://')) {
      return await _publishHttp(mavenClient, theArtifact, stopwatch);
    }
    await _publishLocal(theArtifact, destination, stopwatch);
  }

  Artifact _getArtifact() {
    return switch (artifact) {
      Ok(value: var a) => a,
      Fail(exception: var e) => throw e,
    };
  }

  Future<void> _publishLocal(
      Artifact theArtifact, String repoPath, Stopwatch stopwatch) async {
    final destination = Directory(_pathFor(theArtifact, repoPath));
    logger.info(() => 'Publishing artifacts to ${destination.path}');
    await _publishArtifactToDir(destination, theArtifact, stopwatch);
  }

  Future<void> _publishHttp(MavenClient mavenClient, Artifact theArtifact,
      Stopwatch stopwatch) async {
    final destination = tempDir(suffix: '-jb-publish');
    logger.info(() => 'Creating publication artifacts at ${destination.path}, '
        'will publish to ${mavenClient.repo.url}');
    await _publishArtifactToDir(destination, _getArtifact(), stopwatch);
    logger.fine(() => 'Creating bundle.jar with publication artifacts');
    final bundle = await _createBundleJar(destination, stopwatch);
    logger.info(() => 'Publishing artifacts to ${mavenClient.repo.url}');
    try {
      await mavenClient.publish(theArtifact, bundle);
    } finally {
      mavenClient.close();
    }
  }

  Future<void> _publishArtifactToDir(
      Directory destination, Artifact artifact, Stopwatch stopwatch) async {
    stopwatch.reset();

    // ignore error intentionally
    await catching(() => destination.delete(recursive: true));
    // create an empty directory
    await destination.create(recursive: true);
    // the jar is verified by the publicationCompile task,
    // so this should never fail
    final jarFile = jar.ifBlank(() => 'Cannot publish, jar was not provided');

    final pom = createPom(artifact, dependencies, localDependencies);

    logger.log(
        profile, () => 'Created POM in ${stopwatch.elapsedMilliseconds} ms');
    stopwatch.reset();

    await _publishFiles(destination, artifact, pom, jarFile);

    logger.log(
        profile,
        () => 'Created publication artifacts in '
            '${stopwatch.elapsedMilliseconds} ms');
  }

  Future<void> _publishFiles(Directory destination, Artifact artifact,
      String pom, String jarFile) async {
    await File(p.join(destination.path, _fileFor(artifact, extension: '.pom')))
        .writeAsString(pom)
        .then(_signFile)
        .then(_shaFile);
    await File(jarFile)
        .copy(p.join(destination.path, _fileFor(artifact)))
        .then(_signFile)
        .then(_shaFile);
    await File(jarFile.replaceExtension('-sources.jar'))
        .rename(
            p.join(destination.path, _fileFor(artifact, qualifier: '-sources')))
        .then(_signFile)
        .then(_shaFile);
    await File(jarFile.replaceExtension('-javadoc.jar'))
        .rename(
            p.join(destination.path, _fileFor(artifact, qualifier: '-javadoc')))
        .then(_signFile)
        .then(_shaFile);
  }

  Future<File> _createBundleJar(
      Directory directory, Stopwatch stopwatch) async {
    // jar --create --file target/bundle.jar -C target/deploy .
    final bundleJar = tempFile(extension: '.jar');
    logger.fine(() => 'Creating publication bundle jar at ${bundleJar.path}');
    stopwatch.reset();
    await execProc(Process.start('jar',
        ['--create', '--file', bundleJar.path, '-C', directory.path, '.']));
    logger.log(
        profile,
        () => 'Created publication bundle jar at ${bundleJar.path} in '
            '${stopwatch.elapsedMilliseconds} ms.');
    return bundleJar;
  }
}

HttpClientCredentials? _mavenCredentials() {
  final mavenUser = Platform.environment['MAVEN_USER'];
  final mavenPassword = Platform.environment['MAVEN_PASSWORD'];
  if (mavenUser != null && mavenPassword != null) {
    logger.info('Using MAVEN_USER and MAVEN_PASSWORD for HTTP credentials');
    return HttpClientBasicCredentials(mavenUser, mavenPassword);
  }
  logger.info('No HTTP credentials provided '
      '(set MAVEN_USER and MAVEN_PASSWORD to provide it)');
  return null;
}

Future<void> _shaFile(File file) async {
  logger.finer(() => 'Computing SHA1 of ${file.path}');
  await File('${file.path}.sha1')
      .writeAsString(sha1.convert(await file.readAsBytes()).toString());
  logger.finer(() => 'Computed SHA1 of ${file.path}');
}

// remember if GPG fails so we don't try again
bool _gpgExists = true;

Future<File> _signFile(File file) async {
  if (_gpgExists) {
    logger.info(() => 'Signing $file');
    try {
      await execProc(Process.start('gpg', [
        '--armor',
        '--detach-sign',
        '--pinentry-mode',
        'loopback',
        file.path,
      ]));
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

String _pathFor(Artifact artifact, String parent) {
  return p.joinAll([
    parent,
    ...artifact.group.split('.'),
    artifact.module,
    artifact.version,
  ]);
}

String _fileFor(Artifact artifact,
        {String qualifier = '', String extension = '.jar'}) =>
    '${artifact.module}-${artifact.version}$qualifier$extension';
