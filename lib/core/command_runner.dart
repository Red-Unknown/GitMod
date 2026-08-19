import 'dart:async';
import 'dart:convert';
import 'dart:io';

class CommandResult {
  const CommandResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  final int exitCode;
  final String stdout;
  final String stderr;
}

abstract interface class CommandRunner {
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    required Map<String, String> environment,
    required Duration timeout,
  });
}

class ProcessCommandRunner implements CommandRunner {
  const ProcessCommandRunner();

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    required Map<String, String> environment,
    required Duration timeout,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: true,
      runInShell: false,
    );
    try {
      final output = await Future.wait<String>(<Future<String>>[
        process.stdout.transform(utf8.decoder).join(),
        process.stderr.transform(utf8.decoder).join(),
      ]).timeout(timeout);
      final exitCode = await process.exitCode;
      return CommandResult(
        exitCode: exitCode,
        stdout: output[0],
        stderr: output[1],
      );
    } on TimeoutException {
      process.kill(ProcessSignal.sigterm);
      await process.exitCode;
      throw const CommandTimeoutException();
    }
  }
}

class CommandTimeoutException implements Exception {
  const CommandTimeoutException();
}
