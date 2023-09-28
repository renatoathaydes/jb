import 'package:io/ansi.dart' as ansi;

/// String color.
const strColor = ansi.blue;

/// Keyword color.
const kwColor = ansi.magenta;

/// Comments color.
const commentColor = ansi.darkGray;

typedef AnsiColor = String Function(String text, ansi.AnsiCode code);

String _noColor(String text, ansi.AnsiCode code) => text;

String _color(String text, ansi.AnsiCode code) => code.wrap(text) ?? text;

AnsiColor createAnsiColor(bool noColor) => noColor ? _noColor : _color;
