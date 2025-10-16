import 'dart:convert';
import 'dart:io';

import '../git_config.dart';

import 'package:args/command_runner.dart';

/// Command for fetching config from remote Git repository.
class FetchCommand extends Command {
  @override
  final name = "fetch";

  @override
  final description = "Download config from remote Git repository.";

  FetchCommand() {
    // Add SSH flag (-s) to use SSH instead of HTTPS.
    argParser.addFlag(
      "ssh",
      abbr: "s",
      negatable: false,
      help: "Use SSH instead of HTTPS",
    );
  }

  @override
  Future<void> run() async {
    // Load the local JSON configuration file.
    final configFile = File("git_config.json");

    // Throw an error if the config file doesn't exist.
    if (!configFile.existsSync()) {
      log(
        "Cannot find 'git_config.json' in the execution path.\n"
        "Required to fetch configuration from the remote Git repository.",
        color: red,
      );
      exit(1);
    }

    final config = jsonDecode(configFile.readAsStringSync());
    final useSsh = argResults?["ssh"] == true;

    // Setup temporary directory and project root directory.
    final tempDir = Directory("temp");
    final rootDir = Directory("./");

    final remote = config["remote"];
    final owner = remote["owner"] as String?;
    final repository = remote["repository"] as String?;

    // Default to 'main' if branch is not specified.
    final branch = (remote["branch"] as String?) ?? "main";

    try {
      log("Fetching private git config...");

      // Clone the GitHub repository into the temporary directory.
      final cloneResult = await Process.run("git", [
        "clone",
        "-b",
        branch,
        useSsh
            ? "git@github.com:$owner/$repository.git"
            : "https://github.com/$owner/$repository.git",
        tempDir.path,
      ]);

      // Handle clone failure
      if (cloneResult.exitCode != 0) {
        log("Git clone failed: ${cloneResult.stderr}", color: red);
        await tempDir.delete(recursive: true);
        exit(1);
      }

      // Copy the fetched files from the temp directory into the project root.
      await for (final entity in tempDir.list(recursive: true)) {
        if (entity is File) {
          // Skip .git files/folders
          if (entity.path.contains(".git")) {
            continue;
          }

          // Determine the relative path and create the file in the project.
          final relativePath = entity.path.replaceFirst(
            "${tempDir.path}${Platform.pathSeparator}",
            "",
          );
          final newFile = File(
            "${rootDir.path}${Platform.pathSeparator}$relativePath",
          )..createSync(recursive: true);
          await entity.copy(newFile.path);
        }
      }

      log("Config files copied into ${rootDir.absolute}", color: green);
    } finally {
      // Clean up the temporary directory after fetching.
      await tempDir.delete(recursive: true);
    }
  }
}
