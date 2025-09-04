class NestedDirectoryException implements Exception {
  final String directory;
  final Object cause;
  final StackTrace stackTrace;

  const NestedDirectoryException._(this.directory, this.cause, this.stackTrace);

  factory NestedDirectoryException(
    String directory,
    Object cause,
    StackTrace stackTrace,
  ) {
    return NestedDirectoryException._(directory, cause, stackTrace);
  }

  @override
  String toString() {
    return 'at: $directory, cause: $cause, stackTrace: $stackTrace';
  }
}
