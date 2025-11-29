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

sealed class MavenRepo {
  abstract final String url;
}

/// The Sonatype repositories for Maven Central.
///
/// The only API as of 2025 is https://central.sonatype.com/api/v1.
/// Reference: https://central.sonatype.org/publish/publish-portal-api/
///
/// HISTORICAL CONTEXT:
/// Quote from https://central.sonatype.org/publish/publish-manual/:
/// > As of February 2021, all new projects began being provisioned on
/// > https://s01.oss.sonatype.org/.
/// > If your project is not provisioned on https://s01.oss.sonatype.org/,
/// > you will want to login to the legacy host https://oss.sonatype.org/.
enum Sonatype implements MavenRepo {
  /// Default Sonatype Repository for Maven Central.
  s01Oss;

  @override
  String get url => switch (this) {
    Sonatype.s01Oss => 'https://central.sonatype.com/api/v1/publisher/',
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

enum _DeploymentState {
  pending,
  validating,
  validated,
  publishing,
  published,
  failed,
}

_DeploymentState? _deploymentState(Object? value) {
  if (value is! String) return null;
  return switch (value) {
    'PENDING' => .pending,
    'VALIDATING' => .validating,
    'VALIDATED' => .validated,
    'PUBLISHING' => .publishing,
    'PUBLISHED' => .published,
    'FAILED' => .failed,
    _ => null,
  };
}

/// A Maven repository client.
///
/// This client can be used to publish Maven artifacts.
class MavenClient {
  final MavenRepo repo;
  final HttpClientCredentials? _credentials;
  final HttpClient _client;
  final String bundleUpload;
  final String bundleStatus;

  MavenClient(
    this.repo, {
    HttpClientCredentials? credentials,
    this.bundleUpload = 'upload',
    this.bundleStatus = 'status',
  }) : _credentials = credentials,
       _client = HttpClient()
         ..userAgent = "JBuild-$jbVersion"
         ..idleTimeout = Duration(minutes: 5);

  Future<void> publish(Artifact artifact, File bundle) async {
    Uri uri;
    try {
      uri = Uri.parse(repo.url);
    } catch (e) {
      failBuild(reason: 'Repository URI is invalid: "${repo.url}"');
    }
    if (_credentials != null) {
      await _login(uri, _credentials);
    }
    final deploymentId = await _upload(uri, bundle);
    logger.info(
      () =>
          'Successfully created deployment "$deploymentId" '
          'for ${artifact.coordinates()}, '
          'waiting for deployment to complete (this may take a minute).',
    );

    // the deployment was created, wait for the artifact to be published
    final states = <_DeploymentState>{};
    await _tryUntil(
      identity,
      () => _isDeploymentPublished(uri, deploymentId, states),
      error: 'Checking if deployment has been published',
    );

    logger.info(
      () => 'Artifact ${artifact.coordinates()} was published successfully!',
    );
  }

  void close() {
    _client.close(force: true);
  }

  Future<void> _login(Uri repoUri, HttpClientCredentials credentials) async {
    _client.addCredentials(repoUri, 'Maven Central', credentials);
  }

  Future<String> _upload(Uri repoUri, File bundle) async {
    final uploadUri = repoUri
        .resolve(bundleUpload)
        .replace(queryParameters: {'publishingType': 'AUTOMATIC'});
    logger.fine(() => 'Sending bundle upload request: $uploadUri');

    // Create multipart/form-data request
    final boundary = '--------JBUILD${DateTime.now().millisecondsSinceEpoch}';
    final uploadRequest = await _client.postUrl(uploadUri);
    uploadRequest.headers.contentType = ContentType(
      'multipart',
      'form-data',
      parameters: {'boundary': boundary},
    );

    // Build multipart body
    final header =
        '--$boundary\r\n'
        'Content-Disposition: form-data; name="bundle"; '
        'filename="central-bundle.zip"\r\n'
        'Content-Type: application/octet-stream\r\n'
        '\r\n';
    final footer = '\r\n--$boundary--\r\n';

    // Write the multipart request
    uploadRequest.add(utf8.encode(header));
    await uploadRequest.addStream(bundle.openRead());
    uploadRequest.add(utf8.encode(footer));

    final uploadResponse = await uploadRequest.close();
    await _verifySuccess(
      uploadResponse,
      error: 'Failed to upload bundle to Maven repository',
      consumeBody: false,
    );
    return await _parseUploadResponse(uploadResponse);
  }

  Future<bool> _isDeploymentPublished(
    Uri repoUri,
    String deploymentId,
    Set<_DeploymentState> previousStates,
  ) async {
    var statusUri = repoUri
        .resolve(bundleStatus)
        .replace(queryParameters: {'id': deploymentId});
    logger.fine(() => 'Checking repository status: $statusUri');
    final result = await _getJson(statusUri, 'checking status');
    logger.finer(() => 'Repository status: $result');
    if (result is Map) {
      final state = _deploymentState(result['deploymentState']);
      if (state == null) {
        failBuild(reason: 'Expected $repoUri to return JSON object');
      }
      if (state == .failed) {
        failBuild(reason: 'Deployment failed, full server response: $result');
      }
      final newState = previousStates.add(state);
      if (newState) {
        logger.info(() => 'Deployment state: ${state.name}');
      }
      return state == .published;
    }
    failBuild(reason: 'Expected $repoUri to return JSON object');
  }

  Future<String> _parseUploadResponse(HttpClientResponse uploadResponse) async {
    final result = await uploadResponse.transform(utf8.decoder).join();
    logger.fine(() => 'Maven Repository upload response: $result');
    if (result.trim().isEmpty) {
      failBuild(
        reason:
            'Expected upload response to be a deployment ID but it is blank',
      );
    }
    return result;
  }

  Future<dynamic> _getJson(Uri uri, String error) async {
    bool retry = true;
    while (true) {
      final request = await _client.postUrl(uri);
      request.headers.add('Accept', 'application/json');
      final response = await request.close();
      final isSuccess = await _verifySuccess(
        response,
        error: error,
        consumeBody: false,
        fail: !retry,
      );
      if (isSuccess) {
        return await response.jsonBody();
      }
      retry = false;
      logger.fine('Status request failed, retrying in a few seconds...');
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  Future<bool> _verifySuccess(
    HttpClientResponse response, {
    required String error,
    bool consumeBody = true,
    bool fail = true,
  }) async {
    final status = response.statusCode;
    if (_successCodes.contains(status)) {
      logger.finer(() => 'HTTP response status is successful: $status');
      if (consumeBody) {
        await response.toList();
      }
      return true;
    }
    logger.fine(() => 'HTTP Request failed with statusCode $status');
    var reason = 'statusCode = $status';
    try {
      var body = await response.linesUtf8Encoding().join('\n');
      if (body.trim().isNotEmpty) {
        reason = body;
      }
    } catch (e) {
      logger.fine(() => 'Unable to read error response body: $e');
    }
    if (fail) {
      failBuild(reason: '$error: $reason');
    }
    return false;
  }

  Future<T> _tryUntil<T>(
    bool Function(T) check,
    Future<T> Function() action, {
    required String error,
  }) async {
    final endTime = DateTime.now().add(const Duration(minutes: 5));
    do {
      await Future.delayed(const Duration(seconds: 3));
      final result = await action();
      if (check(result)) return result;
      logger.finer(() => 'Trying "$error" again in a few seconds');
    } while (DateTime.now().isBefore(endTime));
    throw TimeoutException('Action took too long: $error');
  }
}

extension on Artifact {
  String coordinates() {
    return '$group:$module:$version';
  }
}

extension on HttpClientResponse {
  Future<dynamic> jsonBody() async {
    final result = await transform(
      const Utf8Decoder(),
    ).transform(json.decoder).toList();
    return result.first;
  }
}
