import 'package:dartle/dartle.dart';

/// The 'create' command options.
class CreateOptions {
  final List<String> arguments;

  const CreateOptions(this.arguments);
}

class JbCliOptions {
  final List<String> dartleArgs;
  final String? rootDirectory;
  final CreateOptions? createOptions;

  const JbCliOptions(this.dartleArgs, this.rootDirectory, this.createOptions);

  static JbCliOptions parseArgs(List<String> arguments) {
    if (arguments.isEmpty) return const JbCliOptions([], null, null);
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
    return JbCliOptions(dartleArgs, rootDir, createOptions);
  }
}

Options copyDartleOptions(Options options, List<String> tasksInvocation) {
  return Options(
      logLevel: options.logLevel,
      colorfulLog: options.colorfulLog,
      forceTasks: options.forceTasks,
      parallelizeTasks: options.parallelizeTasks,
      resetCache: options.resetCache,
      logBuildTime: false,
      runPubGet: options.runPubGet,
      disableCache: options.disableCache,
      tasksInvocation: tasksInvocation);
}
