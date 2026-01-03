# Contributing to Flow Repo

Thank you for your interest in contributing to Flow Repo! This document provides guidelines for contributing to the project.

## Development Setup

1. **Install Dart SDK** (>= 3.0.0)
   ```bash
   # Visit https://dart.dev/get-dart
   ```

2. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd flow-repo
   ```

3. **Install dependencies**
   ```bash
   dart pub get
   ```

4. **Configure environment**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

## Code Style

### Formatting
- Use `dart format .` before committing
- Follow Dart style guide
- Maximum line length: 80 characters (recommended)

### Comments
- **Language**: English only
- Use dartdoc format for public APIs:
  ```dart
  /// Brief description of the function.
  ///
  /// Detailed explanation if needed.
  ///
  /// Example:
  /// ```dart
  /// final result = await someFunction();
  /// ```
  void someFunction() { }
  ```

### Naming Conventions
- Classes: `PascalCase`
- Functions/Variables: `camelCase`
- Constants: `camelCase` or `SCREAMING_SNAKE_CASE`
- Private members: prefix with `_`

## Commit Guidelines

### Commit Message Format
```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `perf`: Performance improvements
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Maintenance tasks

### Examples
```
feat(chunker): implement content-defined chunking

Implements CDC using Rabin fingerprint algorithm for better
deduplication performance.

Closes #123
```

## Testing

### Running Tests
```bash
dart test
```

### Adding Tests
- Write tests for new features
- Ensure existing tests pass
- Aim for high code coverage

## Pull Request Process

1. **Create a feature branch**
   ```bash
   git checkout -b feat/your-feature-name
   ```

2. **Make your changes**
   - Write clean code
   - Add tests
   - Update documentation

3. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat(scope): description"
   ```

4. **Push to your fork**
   ```bash
   git push origin feat/your-feature-name
   ```

5. **Create Pull Request**
   - Describe your changes
   - Reference related issues
   - Wait for review

## Code Review

- Be respectful and constructive
- Address feedback promptly
- Keep PRs focused and small

## Questions?

Feel free to open an issue for:
- Bug reports
- Feature requests
- Questions about the code
- General discussions

Thank you for contributing! 🎉

