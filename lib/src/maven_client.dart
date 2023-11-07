import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:conveniently/conveniently.dart';
import 'package:dartle/dartle_dart.dart' show failBuild;
import 'package:jb/src/version.g.dart';

import 'config.dart';
import 'pom.dart';
import 'utils.dart';

const _successCodes = {200, 201, 202, 203, 204};

const _evaluationRules = {
  'sources-staging': 'Sources Validation',
  'checksum-staging': 'Checksum Validation',
  'no-traversal-paths-in-archive-file':
      'Archives must not contain insecure paths',
  'sbom-report': 'SBOM Report',
  'pom-staging': 'POM Validation',
  'profile-target-matching-staging': 'Profile target matcher',
  'javadoc-staging': 'Javadoc Validation',
  'signature-staging': 'Signature Validation',
};

sealed class MavenRepo {
  abstract final String url;
}

/// The Sonatype repositories for Maven Central.
///
/// Quote from https://central.sonatype.org/publish/publish-manual/:
/// > As of February 2021, all new projects began being provisioned on
/// > https://s01.oss.sonatype.org/.
/// > If your project is not provisioned on https://s01.oss.sonatype.org/,
/// > you will want to login to the legacy host https://oss.sonatype.org/.
enum Sonatype implements MavenRepo {
  /// Default Sonatype Repository for Maven Central.
  s01Oss,

  /// Older Sonatype Repository for Maven Central.
  oss,
  ;

  @override
  String get url => switch (this) {
        Sonatype.s01Oss => 'https://s01.oss.sonatype.org/service/local/',
        Sonatype.oss => 'https://oss.sonatype.org/service/local/',
      };
}

/// A custom Maven repository.
///
/// Publishing to custom repositories will only work if the repository
/// follows the same protocol as Sonatype repositories.
final class CustomMavenRepo implements MavenRepo {
  @override
  final String url;

  const CustomMavenRepo(this.url);
}

String _checkActivityPath(String repoId) =>
    'staging/repository/$repoId/activity';

String _getRepositoryPath(String repoId) => 'staging/repository/$repoId';

/// A Maven repository client.
///
/// This client can be used to publish Maven artifacts.
class MavenClient {
  final MavenRepo repo;
  final HttpClientCredentials? _credentials;
  final HttpClient _client;
  final String loginPath;
  final String bundleUpload;
  final String promotePath;
  final String Function(String repoId) checkActivityPath;
  final String Function(String repoId) getRepositoryPath;

  MavenClient(
    this.repo, {
    HttpClientCredentials? credentials,
    this.loginPath = 'authentication/login',
    this.bundleUpload = 'staging/bundle_upload',
    this.promotePath = 'staging/bulk/promote',
    this.checkActivityPath = _checkActivityPath,
    this.getRepositoryPath = _getRepositoryPath,
  })  : _credentials = credentials,
        _client = HttpClient()
          ..userAgent = "JBuild-$jbVersion"
          ..idleTimeout = Duration(minutes: 5);

  Future<void> publish(Artifact artifact, File bundleJar) async {
    Uri uri;
    try {
      uri = Uri.parse(repo.url);
    } catch (e) {
      failBuild(reason: 'Repository URI is invalid: "${repo.url}"');
    }
    final cookies = await _credentials.vmapOr(
        (c) => _login(uri, c), () async => const <Cookie>[]);
    final publicationId = await _upload(uri, bundleJar, cookies);
    if (publicationId == null) return;
    logger.info(() => 'Successfully created publication "$publicationId", '
        'waiting for repository checks (this may take minutes).');

    // inspired by https://gist.github.com/romainbsl/0d0bb2149ce7f34246ec6ab0733a07f1
    {
      final closingMonitor = _ClosingActivitiesMonitor();
      await _tryUntil(closingMonitor.allCloseRulesPass,
          () => _getCloseStatus(uri, publicationId, cookies),
          error: 'Closing publication with ID "$publicationId"');
    }

    // the repository is "transitioning" now, wait for that to stop
    await _tryUntil((transitioning) => transitioning == false,
        () => _isRepositoryTransitioning(uri, publicationId, cookies),
        error: 'Checking if repository is transitioning');

    logger.info(() => 'Repository closed successfully, requesting the '
        'release of the published artifacts.');
    try {
      await _promote(uri, artifact, publicationId, cookies);
      logger.info(
          () => 'Artifact ${artifact.coordinates()} released successfully!');
    } catch (e) {
      logger.warning('A problem occurred when trying to release artifact in '
          'staging repository, the release may not have completed: $e');
    }
  }

  void close() {
    _client.close(force: true);
  }

  Future<List<Cookie>> _login(
      Uri repoUri, HttpClientCredentials credentials) async {
    final loginUri = repoUri.resolve(loginPath);
    _client.addCredentials(
        loginUri,
        'Sonatype Nexus Repository Manager API (specialized auth)',
        credentials);
    logger.fine(() => 'Sending login request: $loginUri');
    final loginRequest = await _client.getUrl(loginUri);
    final loginResponse = await loginRequest.close();
    await _verifySuccess(loginResponse,
        error: 'Could not login to Maven repository');
    logger.fine('Successfully logged in to Maven repository');
    return loginResponse.cookies;
  }

  Future<String?> _upload(
      Uri repoUri, File bundle, List<Cookie> cookies) async {
    final uploadUri = repoUri.resolve(bundleUpload);
    logger.fine(() => 'Sending bundle upload request: $uploadUri');
    final uploadRequest = await _client.postUrl(uploadUri);
    uploadRequest.cookies.addAll(cookies);
    await uploadRequest.addStream(bundle.openRead());
    final uploadResponse = await uploadRequest.close();
    await _verifySuccess(uploadResponse,
        error: 'Failed to upload bundle to Maven repository',
        consumeBody: false);
    final publicationIds = await _parseUploadResponse(uploadResponse);
    if (publicationIds.isEmpty) {
      logger.warning(() => 'The Maven repository did not return the staging ID '
          'so the publication could not be finalized. '
          'You must manually release from staging!');
      return null;
    }
    return publicationIds.first;
  }

  Future<Map?> _getCloseStatus(
      Uri repoUri, String publicationId, List<Cookie> cookies) async {
    var statusUri = repoUri.resolve(checkActivityPath(publicationId));
    logger.fine(() => 'Checking publication status: $statusUri');
    final result = await _getJson(statusUri, cookies, '');
    logger.finer(() => 'Publication status: $result');
    if (result is List) {
      return result.where((action) => action['name'] == 'close').firstOrNull;
    }
    failBuild(reason: 'Expected $repoUri to return JSON array');
  }

  Future<bool> _isRepositoryTransitioning(
      Uri repoUri, String publicationId, List<Cookie> cookies) async {
    var statusUri = repoUri.resolve(getRepositoryPath(publicationId));
    logger.fine(() => 'Checking repository status: $statusUri');
    final result = await _getJson(statusUri, cookies, '');
    logger.finer(() => 'Repository status: $result');
    if (result is Map) {
      return result['transitioning'] ?? true;
    }
    failBuild(reason: 'Expected $repoUri to return JSON object');
  }

  Future<void> _promote(Uri repoUri, Artifact theArtifact, String publicationId,
      List<Cookie> cookies) async {
    var promoteUri = repoUri.resolve(promotePath);
    logger.fine(() => 'Sending promote request: $promoteUri');
    final result = await _postJson(
        promoteUri,
        cookies,
        {
          'data': {
            'autoDropAfterRelease': true,
            'stagedRepositoryIds': [publicationId],
            'description': 'JBuild releasing ${theArtifact.coordinates()}',
          },
        },
        'All artifacts published, but failed to release publication!');
    logger.finer(() => 'Promote response: $result');
  }

  Future<Iterable<String>> _parseUploadResponse(
      HttpClientResponse uploadResponse) async {
    final results = await uploadResponse
        .transform(const Utf8Decoder())
        .transform(json.decoder)
        .toList();
    final dynamic result = results[0];
    logger.fine(() => 'Maven Repository upload response: $result');
    final repositoryUris = result['repositoryUris'];
    if (repositoryUris is! List) {
      failBuild(
          reason: 'Expected upload response to contain "repositoryUris array');
    }
    return repositoryUris
        .map<List<String>>((uri) => Uri.parse(uri).pathSegments)
        .where((path) => path.isNotEmpty)
        .map((path) => path.last);
  }

  Future<dynamic> _getJson(Uri uri, List<Cookie> cookies, String error) async {
    final request = await _client.getUrl(uri);
    request.headers.add('Accept', 'application/json');
    request.cookies.addAll(cookies);
    final response = await request.close();
    await _verifySuccess(response, error: error, consumeBody: false);
    return await response.jsonBody();
  }

  Future<String> _postJson(
      Uri uri, List<Cookie> cookies, Object body, String error) async {
    final request = await _client.postUrl(uri);
    request.headers.add('Content-Type', 'application/json');
    request.cookies.addAll(cookies);
    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close();
    await _verifySuccess(response, error: error, consumeBody: false);
    return response.transform(const Utf8Decoder()).join('');
  }

  Future<void> _verifySuccess(HttpClientResponse response,
      {required String error, bool consumeBody = true}) async {
    final status = response.statusCode;
    if (_successCodes.contains(status)) {
      logger.finer(() => 'HTTP response status is successful: $status');
      if (consumeBody) {
        await response.toList();
      }
    } else {
      logger.fine(() => 'HTTP Request failed with statusCode $status');
      var reason = 'statusCode = $status';
      try {
        var body = await response.lines().join('\n');
        if (body.trim().isNotEmpty) {
          reason = body;
        }
      } catch (e) {
        logger.fine(() => 'Unable to read error response body: $e');
      }
      failBuild(reason: '$error: $reason');
    }
  }

  Future<T> _tryUntil<T>(bool Function(T) check, Future<T> Function() action,
      {required String error}) async {
    final endTime = DateTime.now().add(const Duration(minutes: 5));
    do {
      final result = await action();
      if (check(result)) return result;
      logger.finer(() => 'Trying "$error" again in a few seconds');
      await Future.delayed(const Duration(seconds: 3));
    } while (DateTime.now().isBefore(endTime));
    throw TimeoutException('Action took too long: $error');
  }
}

class _ClosingActivitiesMonitor {
  final _reportedRules = <String>{};

  bool allCloseRulesPass(Map? result) {
    if (result == null) return false;
    final events = result['events'];
    if (events == null) return false;
    if (events is! List) {
      failBuild(
          reason: 'Expected repository close status to contain events array');
    }
    var repositoryClosed = false;
    for (final event in events) {
      if (event is Map) {
        switch (event['name']) {
          case 'rulePassed':
            _reportRuleResult(event, passed: true);
          case 'rulesPassed':
            _reportAllPassed();
          case 'ruleFailed':
            _reportRuleResult(event, passed: false);
          case 'email':
            _reportEmail(event);
          case 'rulesFailed':
            failBuild(reason: 'Maven Repository did not accept publication.');
          case 'repositoryClosed':
            repositoryClosed = true;
        }
      }
    }

    // we're only done when the 'repositoryClosed' event exists.
    return repositoryClosed;
  }

  void _reportRuleResult(Map rule, {required bool passed}) {
    final properties = rule['properties'];
    if (properties is List) {
      final typeProp = properties
          .whereType<Map>()
          .where((e) => e['name'] == 'typeId' && e.containsKey('value'))
          .firstOrNull;
      if (typeProp != null) {
        final ruleName = typeProp['value'];
        final ruleDescription = _evaluationRules[ruleName] ?? ruleName;
        if (_reportedRules.add(ruleDescription)) {
          if (passed) {
            logger.info(() => 'Repository check OK: $ruleDescription');
          } else {
            logger.warning(() => 'Repository check FAILED: $ruleDescription');
          }
        }
      }
    }
  }

  void _reportAllPassed() {
    if (_reportedRules.add('ALL_OK')) {
      logger.info('Repository checks ALL OK!');
    }
  }

  void _reportEmail(Map event) {
    final properties = event['properties'];
    if (properties is Map &&
        properties['name'] == 'to' &&
        properties.containsKey('value')) {
      final email = properties['value'];
      if (_reportedRules.add('EMAIL:$email')) {
        logger.info(() => 'Repository sending email notifications to $email');
      }
    }
  }
}

extension on Artifact {
  String coordinates() {
    return '$group:$module:$version';
  }
}

extension on HttpClientResponse {
  Future<dynamic> jsonBody() async {
    final result =
        await transform(const Utf8Decoder()).transform(json.decoder).toList();
    return result.first;
  }
}
