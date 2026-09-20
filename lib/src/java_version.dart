/// Java version representation.
final class JavaVersion(final int major, final int minor, final int patch)
    implements Comparable<JavaVersion> {
  static final _digits = RegExp(r'(\d{1,4}).*');

  /// Parse a Java version.
  ///
  /// The String is assumed to contain 3 numeric parts separated by `.`.
  /// If that's not the case, this method will still succeed but replace the
  /// invalid parts with `0`.
  static JavaVersion parse(String version) {
    final parts = version.split('.');
    final major = parts.isEmpty ? 0 : _parsePart(parts[0]);
    final minor = parts.length > 1 ? _parsePart(parts[1]) : 0;
    final patch = parts.length > 2 ? _parsePart(parts[2]) : 0;
    return JavaVersion(major, minor, patch);
  }

  static int _parsePart(String part) {
    final match = _digits.matchAsPrefix(part);
    if (match == null) return 0;
    return int.tryParse(match.group(1)!) ?? 0;
  }

  @override
  int compareTo(JavaVersion other) {
    final a = major.compareTo(other.major);
    if (a != 0) return a;
    final b = minor.compareTo(other.minor);
    if (b != 0) return b;
    return patch.compareTo(other.patch);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JavaVersion &&
          runtimeType == other.runtimeType &&
          compareTo(other) == 0);

  bool operator >(JavaVersion other) {
    return compareTo(other) > 0;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() {
    return 'JavaVersion{major: $major, minor: $minor, patch: $patch}';
  }
}
