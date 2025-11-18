## Contributing to Dockero

Thank you for considering contributing to **Dockero**! This guide covers everything you need to know to get started, from reporting issues to submitting pull requests.

---

### 📋 Table of Contents

1. [Getting Started](#getting-started)  
2. [Reporting Issues](#reporting-issues)  
3. [Branching & Workflow](#branching--workflow)  
4. [Coding Standards](#coding-standards)  
5. [Pull Request Process](#pull-request-process)  
6. [License](#license)  

---

### 🛠️ Getting Started

1. **Fork** the repository to your GitHub account.  
2. **Clone** your fork locally:  
   ```bash
   git clone git@github.com:<your-username>/dockero-cli.git
   cd dockero-cli
   ```  
---

### 🐛 Reporting Issues

- Check existing issues to avoid duplicates.  
- Use clear, descriptive titles.  
- Provide steps to reproduce, expected vs. actual behavior, and relevant logs.  
- Tag the issue with appropriate labels (`bug`, `enhancement`, `documentation`).

---

### 🌿 Branching & Workflow

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

### 🔍 Coding Standards

- **Style Guide**: Follow [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html):  
  - `#!/usr/bin/env bash` at top of all scripts not sourced by dockero.sh.  
  - Indent with **2 spaces**, not tabs.  
  - Quote variables: `"$var"`.  
  - Limit line length to 80 characters where possible.
  - Prefer to use functions under `extra/`.

---

### 🚀 Pull Request Process

1. **Open a PR** against the `dev` branch.  
2. **Link issues** by using keywords (e.g., “Closes #123”).  
3. **Describe** your changes and any relevant context.  
4. **Ensure** all CI checks pass.  
5. **Request Reviewers** from the team.  

---

### 📜 License

By contributing, you agree that your contributions will be licensed under the project’s [GNU License](LICENSE).

---

Thank you for helping make Dockero better! 🎉