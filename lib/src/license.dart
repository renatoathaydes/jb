/// A SPDX License.
///
/// See https://github.com/spdx/license-list-data.
final class License {
  final String licenseId;
  final String name;
  final Uri uri;
  final bool isOsiApproved;
  final bool isFsfLibre;

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
