typedef Properties = Map<String, Object?>;

class MapWithProperties {
  final Map<String, Object?> map;
  final Properties properties;

  const MapWithProperties(this.map, this.properties);
}

MapWithProperties resolvePropertiesFromMap(Map map) {
  final p = map['properties'];
  Properties properties = p is Map ? resolveProperties(p, const {}) : const {};
  Properties result = resolveProperties(map, properties);
  return MapWithProperties(result, properties);
}

Map<String, Object?> resolveProperties(Map map, Properties properties) {
  if (properties.isEmpty) {
    return map.map((Object? key, Object? value) {
      return MapEntry('$key', _resolveValue(value, properties));
    });
  }
  return map.map((Object? key, Object? value) {
    return MapEntry(_resolveValue('$key', properties) as String,
        _resolveValue(value, properties));
  });
}

Object? _resolveValue(Object? value, Properties properties) {
  if (value == null) return null;
  if (value is String) return resolveString(value, properties);
  if (value is List) return _resolveList(value, properties);
  if (value is Map) return resolveProperties(value, properties);
  return value;
}

String? resolveOptionalString(String? string, Properties properties) {
  if (string == null) return null;
  return resolveString(string, properties);
}

String resolveString(String string, Properties properties) {
  if (string.length < 4 || properties.isEmpty) return string;
  final startIndex = string.indexOf('{{');
  if (startIndex < 0) return string;
  final endIndex = string.indexOf('}}', startIndex + 2);
  if (endIndex < 0) return string;
  final key = string.substring(startIndex + 2, endIndex);
  final value = _lookup(key, properties);
  if (value == null) {
    return string.substring(0, endIndex) +
        resolveString(string.substring(endIndex), properties).toString();
  }
  return string.substring(0, startIndex) +
      value +
      resolveString(string.substring(endIndex + 2), properties).toString();
}

List<Object?> _resolveList(List list, Properties properties) {
  return list
      .map((item) => _resolveValue(item, properties))
      .toList(growable: false);
}

String? _lookup(String key, Properties properties) {
  if (!key.contains('.')) return properties[key]?.toString();
  Object? value;
  var parts = key.split('.').iterator;
  if (!parts.moveNext()) return null;
  while (true) {
    value = properties[parts.current];
    if (!parts.moveNext()) return value?.toString();
    if (value is Map<String, Object?>) {
      properties = value;
    } else {
      return null;
    }
  }
}
