import 'package:args/command_runner.dart';
import 'command/fetch_command.dart';

// ANSI color codes for console output.
const red = "\x1B[31m";
const green = "\x1B[32m";
const reset = "\x1B[0m";
const gray = "\x1B[90m";
const yellow = "\x1B[33m";

// Simple logger with optional color.
void log(String str, {String color = ""}) {
  print("$color$str$reset");
}

void main(List<String> args) {
  // Setup command runner with the 'fetch' command.
  final runner = CommandRunner("git_config", "Git-based config sync tool")
    ..addCommand(FetchCommand());

  runner.run(args);
}
