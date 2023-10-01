import 'ansi.dart';

/// A SPDX License.
///
/// See https://github.com/spdx/license-list-data.
final class License {
  final String licenseId;
  final String name;
  final String uri;
  final bool? isOsiApproved;
  final bool? isFsfLibre;

  const License(
      {required this.licenseId,
      required this.name,
      required this.uri,
      required this.isOsiApproved,
      required this.isFsfLibre});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is License && licenseId == other.licenseId;

  @override
  int get hashCode => licenseId.hashCode;

  @override
  String toString() {
    return 'License{licenseId: $licenseId, name: $name, uri: $uri, '
        'isOsiApproved: $isOsiApproved, isFsfLibre: $isFsfLibre}';
  }
}

/// Developers that have contributed to this project.
final class Developer {
  final String name;
  final String email;
  final String organization;
  final String organizationUrl;

  const Developer(
      {required this.name,
      required this.email,
      required this.organization,
      required this.organizationUrl});

  String toYaml(AnsiColor color, String ident) {
    return 'name: ${color('"$name"', strColor)}\n'
        '${ident}email: ${color('"$email"', strColor)}\n'
        '${ident}organization: ${color('"$organization"', strColor)}\n'
        '${ident}organization-url: ${color('"$organizationUrl"', strColor)}';
  }

  @override
  String toString() {
    return 'Developer{name: $name, email: $email, organization: $organization,'
        ' organizationUrl: $organizationUrl}';
  }
}

/// Source control Management settings.
final class SourceControlManagement {
  final String connection;
  final String developerConnection;
  final String url;

  const SourceControlManagement(
      {required this.connection,
      required this.developerConnection,
      required this.url});

  String toYaml(AnsiColor color, String ident) {
    return 'connection: ${color('"$connection"', strColor)}\n'
        '${ident}developer-connection: ${color('"$developerConnection"', strColor)}\n'
        '${ident}url: ${color('"$url"', strColor)}';
  }

  @override
  String toString() {
    return 'SourceControlManagement{connection: $connection, '
        'developerConnection: $developerConnection, url: $url}';
  }
}
