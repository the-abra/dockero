## Contributing to Dockero

Thank you for considering contributing to **Dockero**! This guide covers everything you need to know to get started, from reporting issues to submitting pull requests.

---

### Table of Contents

1. [Getting Started](#getting-started)
2. [Project Architecture](#project-architecture)
3. [Reporting Issues](#reporting-issues)
4. [Branching & Workflow](#branching--workflow)
5. [Coding Standards](#coding-standards)
6. [Adding New Commands](#adding-new-commands)
7. [Pull Request Process](#pull-request-process)
8. [License](#license)

---

### Getting Started

1. **Fork** the repository to your GitHub account.
2. **Clone** your fork locally:
   ```bash
   git clone git@github.com:<your-username>/dockero-cli.git
   cd dockero-cli
   ```

---

### Project Architecture

Dockero follows a modular architecture:

- `bin/dockero` - Main entry point and command loader
- `lib/commands/` - Individual subcommand implementations
- `lib/utils/` - Utility libraries (logging, colors, etc.)
- `completions/` - Shell completion scripts
- `docs/` - Documentation files

Each command is implemented as a separate `.sh` file in the `lib/commands/` directory with:
- Main function named after the command
- Help function named `COMMAND_help`
- Proper error handling and logging

---

### Reporting Issues

- Check existing issues to avoid duplicates.
- Use clear, descriptive titles.
- Provide steps to reproduce, expected vs. actual behavior, and relevant logs.
- Tag the issue with appropriate labels (`bug`, `enhancement`, `documentation`).

---

### Branching & Workflow

We follow the **GitHub Flow**:

1. **Create a branch** for your work:
   ```bash
   git checkout -b feature/my-new-feature
   ```
2. **Commit changes** in logical chunks:
   ```bash
   git commit -m "feat(run): support custom commands in existing containers"
   ```
   - Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages.
3. **Push** your branch to GitHub:
   ```bash
   git push origin feature/my-new-feature
   ```

---

### Coding Standards

- **Style Guide**: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html):
  - `#!/usr/bin/env bash` at top of all scripts not sourced by dockero.
  - Indent with **2 spaces**, not tabs.
  - Quote variables: `"$var"`.
  - Limit line length to 80 characters where possible.
  - Prefer to use functions under `lib/utils/`.

---

### Adding New Commands

To add a new command:

1. **Create** a new file in `lib/commands/` named `commandname.sh`
2. **Implement** a function with the same name as your command
3. **Add** a corresponding help function `commandname_help()` inside your new file (help functions are now dynamically loaded from each command script!)
4. **Compile** your changes into the standalone executable by running `make build` (or `make test` to compile and run tests)
5. **Test** your command works by executing `./dist/dockero commandname`
6. **Update** documentation and the man page [dockero.1](https://github.com/the-abra/dockero/blob/main/docs/man/dockero.1) as needed

---

### Pull Request Process

1. **Open a PR** against the `dev` branch.
2. **Link issues** by using keywords (e.g., "Closes #123").
3. **Describe** your changes and any relevant context.
4. **Ensure** all CI checks pass.
5. **Request Reviewers** from the team.

---

### License

By contributing, you agree that your contributions will be licensed under the project's [GNU License](LICENSE).

---

Thank you for helping make Dockero better!