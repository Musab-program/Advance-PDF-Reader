import 'dart:io';

class ToolTaskResult {
  final bool isSuccess;
  final String? message;
  final String? errorMessage;
  final List<File> outputFiles;
  final String? outputDirectory;
  final Duration? duration;

  ToolTaskResult({
    required this.isSuccess,
    this.message,
    this.errorMessage,
    this.outputFiles = const [],
    this.outputDirectory,
    this.duration,
  });

  File? get primaryFile => outputFiles.isNotEmpty ? outputFiles.first : null;
}
