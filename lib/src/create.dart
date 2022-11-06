import 'package:dartle/dartle.dart';

Future<void> createNewProject(List<String> arguments) async {
  if (arguments.length > 1) {
    throw DartleException(
        message: 'create command does not accept any arguments');
  }
  print('New Project!!!');
}
