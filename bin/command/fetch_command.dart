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

    final options = config["options"];
    final remote = config["remote"];
    final owner = remote["owner"] as String?;
    final repository = remote["repository"] as String?;

    // Default to 'main' if branch is not specified.
    final branch = (remote["branch"] as String?) ?? "main";

    // Determines whether fetched files should be automatically added to `.gitignore`.
    // Defaults to true to prevent unintentional commits of remote configuration files.
    final gitignore = options?["gitignore"] ?? true;

    // List of all fetched file paths (for later gitignore update)
    final fetchedFiles = <String>[];

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

          // Track copied file for potential .gitignore addition.
          fetchedFiles.add(relativePath);
        }
      }

      log("Config files copied into ${rootDir.absolute}", color: green);

      if (fetchedFiles.isNotEmpty) {
        await ensureGitignored(fetchedFiles, gitignore);
      }
    } finally {
      // Clean up the temporary directory after fetching.
      await tempDir.delete(recursive: true);
    }
  }

  /// Ensures that the given files are listed in `.gitignore`.
  /// Adds missing entries to prevent accidental commits
  /// of fetched config files.
  Future<void> ensureGitignored(
    List<String> files,
    bool isAllowModify,
  ) async {
    final gitignoreFile = File('.gitignore');

    // Create `.gitignore` only when modification is allowed.
    if (isAllowModify && !gitignoreFile.existsSync()) {
      gitignoreFile.createSync();
    }

    final newEntries = <String>[];

    // Check which files are not yet ignored by Git.
    for (final file in files) {
      final normalized = file.replaceAll('\\', '/');
      final result = await Process.run(
        "git",
        ["check-ignore", "-v", normalized],
        workingDirectory: Directory.current.path,
      );

      // When the file is not ignored.
      if (result.exitCode == 1) {
        newEntries.add(normalized);
      }
    }

    // If there are files that need to be ignored.
    if (newEntries.isNotEmpty) {
      // Append missing entries to `.gitignore`.
      if (isAllowModify) {
        gitignoreFile.writeAsStringSync(
          "${newEntries.join("\n")}\n",
          mode: FileMode.append,
        );

        if (newEntries.length > 1) {
          log(
            "Added ${newEntries.length} new ${newEntries.length == 1 ? "entry" : "entries"} to .gitignore:",
            color: green,
          );
        } else {
          log("Added '${newEntries.first}' to .gitignore", color: green);
        }
      }

      // Log results for both added and untracked files.
      for (final entry in newEntries) {
        if (isAllowModify) {
          if (newEntries.length > 1) log("  - $entry", color: gray);
        } else {
          log("Warning: '$entry' is not tracked by .gitignore", color: yellow);
        }
      }
    }
  }
}
