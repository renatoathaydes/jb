import 'package:dartle/dartle.dart' show ChangeSet;
import 'package:dartle/dartle_cache.dart' show FileChange;

extension FileChangeToMap on FileChange {
  Map<String, Object?> toMap() {
    return {'path': entity.path, 'kind': kind.name};
  }
}

extension ChangeSetToMap on ChangeSet {
  Map<String, Object?> toMap() {
    return {
      'inputChanges': inputChanges.map((e) => e.toMap()),
      'outputChanges': outputChanges.map((e) => e.toMap()),
    };
  }
}
