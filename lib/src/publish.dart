import 'dart:async';
import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle.dart'
    show ArgsCount, DartleException, homeDir, failBuild;
import 'package:path/path.dart' as p;

import 'config.dart';
import 'pom.dart';
import 'resolved_dependency.dart';
import 'utils.dart';

// See https://central.sonatype.org/publish/publish-manual/#close-and-drop-or-release-your-staging-repository
const _mavenRepo = 'https://s01.oss.sonatype.org/service/local';

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

    if (destination == '-m') {
      return await _publishHttp(_mavenRepo);
    }
    if (destination.startsWith('http://') ||
        destination.startsWith('https://')) {
      return await _publishHttp(destination);
    }
    await _publishLocal(destination);
  }

  Future<void> _publishLocal(String repoPath) async {
    final theArtifact = switch (artifact) {
      Ok(value: var a) => a,
      Fail(exception: var e) => throw e,
    };

    final destination = Directory(_pathFor(theArtifact, repoPath));
    await _putPublicationOn(destination, theArtifact);
  }

  Future<void> _putPublicationOn(
      Directory destination, Artifact artifact) async {
    // ignore error intentionally
    await catching(() => destination.delete(recursive: true));
    // create an empty directory
    await destination.create(recursive: true);
    // the jar is verified by the publicationCompile task,
    // so this should never fail
    final jarFile = jar.ifBlank(() => 'Cannot publish, jar was not provided');

    logger.info(() => 'Publishing artifacts to ${destination.path}');

    final pom = createPom(artifact, dependencies, localDependencies);
    await File(p.join(destination.path, _fileFor(artifact, extension: '.pom')))
        .writeAsString(pom.toString());
    await File(jarFile).copy(p.join(destination.path, _fileFor(artifact)));
    await File(jarFile.replaceExtension('-sources.jar')).rename(
        p.join(destination.path, _fileFor(artifact, qualifier: '-sources')));
    await File(jarFile.replaceExtension('-javadoc.jar')).rename(
        p.join(destination.path, _fileFor(artifact, qualifier: '-javadoc')));
  }

  Future<void> _publishHttp(String repoUri) async {
    throw DartleException(
        message: 'Publishing to HTTP repositories is not supported yet');
  }
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
