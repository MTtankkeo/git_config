# Introduction
A Dart CLI to fetch config files from a remote Git repository into the project. It is especially useful for side projects or collaborative environments, automatically adding fetched files to `.gitignore` to help developers avoid accidentally committing sensitive or environment-specific configuration files.

## Why Use This?

| Benefit | Description |
| ------- | ----------- |
| 🔒 Safety | Ensures fetched configuration files are tracked in **.gitignore** to prevent committing sensitive or environment-specific data. |
| ⚡ Setup | Automatically fetches and copies config files from a remote Git repository, removing manual steps. |
| 🤝 Team | Provides a consistent project setup across team members without requiring them to manage or share config files manually. |

## Usage
This section covers the basic usage of this package and how to integrate it into your application.

### ⚙️ Adding Config File
Add a JSON file named `git_config.json` in the project root folder. Adjust the contents from the example as needed.

```json
{
  "remote": {
    "owner": "organization or your name",
    "repository": "repository",
    "branch": "main"
  }
}
```

Next, it’s simple. Run the following command in the terminal at the path where the config file is located. The contents of the repository defined in the config file will then be copied into your project.

### Using HTTPS 💻
```bash
dart run git_config fetch
```

### Using SSH 🔑
```bash
dart run git_config fetch --ssh
```
