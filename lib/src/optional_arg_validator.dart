import 'package:dartle/dartle.dart' show ArgsCount;

class OptionalArgValidator extends ArgsCount {
  final String help;

  const OptionalArgValidator(this.help) : super.range(min: 0, max: 1);

  @override
  String helpMessage() => help;
}
