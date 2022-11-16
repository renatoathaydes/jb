import 'package:dartle/dartle.dart';

/// The 'create' command options.
class CreateOptions {
  final List<String> arguments;

  const CreateOptions(this.arguments);
}

class JBuildCliOptions {
  final List<String> dartleArgs;
  final String? rootDirectory;
  final CreateOptions? createOptions;

  const JBuildCliOptions(
      this.dartleArgs, this.rootDirectory, this.createOptions);

  static JBuildCliOptions parseArgs(List<String> arguments) {
    if (arguments.isEmpty) return const JBuildCliOptions([], null, null);
    final dartleArgs = <String>[];
    final createArgs = <String>[];
    var currentArgs = dartleArgs;
    CreateOptions? createOptions;
    String? rootDir;
    bool waitingForRootDir = false;
    for (final arg in arguments) {
      if (waitingForRootDir) {
        if (rootDir != null) {
          throw DartleException(
              message: 'Cannot pass more than one -p option.');
        }
        waitingForRootDir = false;
        rootDir = arg;
      } else if (arg == '-p') {
        waitingForRootDir = true;
      } else if (arg == 'create') {
        createOptions = CreateOptions(createArgs);
        currentArgs = createArgs;
      } else {
        currentArgs.add(arg);
      }
    }
    if (waitingForRootDir) {
      throw DartleException(message: '-p option requires an argument.');
    }
    if (dartleArgs.isNotEmpty && createOptions != null) {
      throw DartleException(
          message: 'The "create" command cannot be used with other tasks.');
    }
    return JBuildCliOptions(dartleArgs, rootDir, createOptions);
  }
}
