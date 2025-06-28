# Contributing to TaskWire

## Development Guidelines

### Commit Messages
Use [Conventional Commits](https://www.conventionalcommits.org/) format:
```
type(scope): description

feat: add new printer settings page
fix: resolve task deletion issue
ui: adjusted theme colors to improve contrast
chore: updated pubspec
docs: update README
```

The scope is optional.


### Pre-commit Checklist
1. Run `flutter analyze` to check for issues
2. Test on mobile device/emulator
3. Test on Windows desktop
4. Ensure all tests pass

### Version Management
- CI runs are triggered by tags in format: `v1.0.0.50` (where 50 is build number)
- Run `dart setup_version_hook.dart` to set up automatic build number increment on commit

### Getting Started
1. Fork the repository
2. Create a feature branch
3. Make your changes following the guidelines above
4. Submit a pull request
