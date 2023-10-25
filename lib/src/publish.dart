import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:crypto/crypto.dart';
import 'package:dartle/dartle.dart'
    show ArgsCount, homeDir, failBuild, execProc, profile, tempDir, tempFile;
import 'package:path/path.dart' as p;

import 'config.dart';
import 'pom.dart';
import 'resolved_dependency.dart';
import 'utils.dart';

// See https://central.sonatype.org/publish/publish-manual/#close-and-drop-or-release-your-staging-repository
const _mavenCentralUrl = 'https://s01.oss.sonatype.org/service/local';

const _successCodes = {200, 201, 202, 203, 204};

class Publisher {
  static final argsValidator = ArgsCount.range(min: 0, max: 1);

  final Result<Artifact> artifact;
  final Map<String, DependencySpec> dependencies;
  final ResolvedLocalDependencies localDependencies;
  final String? jar;

  Publisher(this.artifact, this.dependencies, this.localDependencies, this.jar);

  Future<void> call(List<String> args) async {
    final home = homeDir()
        .orThrow(() => failBuild(reason: 'Cannot find home directory'));

    final destination =
        args.isEmpty ? p.join(home, '.m2', 'repository') : args[0];

    final stopwatch = Stopwatch()..start();

    if (destination == '-m') {
      return await _publishHttp(_mavenCentralUrl, stopwatch);
    }

    if (destination.startsWith('http://') ||
        destination.startsWith('https://')) {
      return await _publishHttp(destination, stopwatch);
    }
    await _publishLocal(destination, stopwatch);
  }

  Artifact _getArtifact() {
    final theArtifact = switch (artifact) {
      Ok(value: var a) => a,
      Fail(exception: var e) => throw e,
    };
    return theArtifact;
  }

  Future<void> _publishLocal(String repoPath, Stopwatch stopwatch) async {
    final theArtifact = _getArtifact();

    final destination = Directory(_pathFor(theArtifact, repoPath));
    logger.info(() => 'Publishing artifacts to ${destination.path}');
    await _publishArtifactToDir(destination, theArtifact, stopwatch);
  }

  Future<void> _publishHttp(String repoUri, Stopwatch stopwatch) async {
    Uri uri;
    try {
      uri = Uri.parse(repoUri);
    } catch (e) {
      failBuild(reason: 'Repository URI is invalid: "$repoUri"');
    }
    final destination = tempDir(suffix: '-jb-publish');
    logger.fine(() => 'Creating publication artifacts at ${destination.path}');
    await _publishArtifactToDir(destination, _getArtifact(), stopwatch);
    logger.fine(() => 'Creating bundle.jar with publication artifacts');
    final bundle = await _createBundleJar(destination, stopwatch);
    stopwatch.reset();
    logger.log(
        profile,
        () => 'Publication bundle created at ${bundle.path} in '
            '${stopwatch.elapsedMilliseconds} ms');
    logger.info(() => 'Publishing artifacts to $repoUri');
    await _httpPost(uri, bundle, _mavenCredentials());
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
      StringBuffer pom, String jarFile) async {
    await File(p.join(destination.path, _fileFor(artifact, extension: '.pom')))
        .writeAsString(pom.toString())
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

  Future<void> _httpPost(
      Uri repoUri, File bundle, HttpClientBasicCredentials? credentials) async {
    final client = HttpClient();
    if (credentials != null) {
      await _login(repoUri, client, credentials);
    }
    final uploadRequest =
        await client.postUrl(repoUri.resolve('staging/bundle_upload'));
    await uploadRequest.addStream(bundle.openRead());
    final uploadResponse = await uploadRequest.close();
    await _verifySuccess(uploadResponse,
        error: 'Failed to upload bundle to Maven repository');
    final publicationIds = await _parseUploadResponse(uploadResponse);
    if (publicationIds.isEmpty) {
      logger.warning(() => 'The Maven repository did not return the staging ID '
          'so the publication could not be finalized. '
          'You must manually release from staging!');
      return;
    }
    logger.fine('Closing publication');
    final promoteRequest =
        await client.postUrl(repoUri.resolve('staging/bulk/promote'));
    promoteRequest.add(utf8.encode(jsonEncode({
      'autoDropAfterRelease': true,
      'stagedRepositoryIds': publicationIds,
      'description': 'jbuild publication',
    })));
    final promoteResponse = await promoteRequest.close();
    await _verifySuccess(promoteResponse,
        error: 'All artifacts published, but failed to finalize publication');
    logger.info('Successfully published artifact');
  }

  Future<void> _login(Uri repoUri, HttpClient client,
      HttpClientBasicCredentials credentials) async {
    final loginUri = repoUri.resolve('authentication/login');
    client.addCredentials(
        loginUri,
        'Sonatype Nexus Repository Manager API (specialized auth)',
        credentials);
    final loginRequest = await client.getUrl(loginUri);
    final loginResponse = await loginRequest.close();
    await _verifySuccess(loginResponse,
        error: 'Could not login to Maven repository');
    logger.fine('Successfully logged in to Maven repository');
  }
}

Future<Iterable<String>> _parseUploadResponse(
    HttpClientResponse uploadResponse) async {
  final dynamic result = await uploadResponse
      .transform(const Utf8Decoder())
      .transform(json.decoder)
      .first;
  logger.fine(() => 'Maven Repository upload response: $result');
  final Iterable<String> repositoryUris = result['repositoryUris'];
  return repositoryUris
      .map((uri) => Uri.parse(uri).pathSegments)
      .where((path) => path.isNotEmpty)
      .map((path) => path.last);
}

HttpClientBasicCredentials? _mavenCredentials() {
  final mavenUser = Platform.environment['MAVEN_USER'];
  final mavenPassword = Platform.environment['MAVEN_PASSWORD'];
  if (mavenUser != null && mavenPassword != null) {
    logger.fine('Using MAVEN_USER and MAVEN_PASSWORD for HTTP credentials');
    return HttpClientBasicCredentials(mavenUser, mavenPassword);
  }
  logger.fine('No HTTP credentials provided');
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
    logger.finer(() => 'Signing $file');
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
      logger.info(
          'Unable to sign artifacts as "gpg" does not seem to be installed.');
      logger.fine(() => 'GPG failed with: $e');
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

Future<void> _verifySuccess(HttpClientResponse response,
    {required String error}) async {
  final status = response.statusCode;
  if (!_successCodes.contains(status)) {
    logger.fine(() => 'HTTP Request failed with statusCode $status');
    var body = await response.lines().join('\n');
    if (body.trim().isEmpty) {
      body = 'statusCode = $status';
    }
    failBuild(reason: '$error: $body');
  }
}
