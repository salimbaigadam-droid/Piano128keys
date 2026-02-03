# Contributing to Piano 128 Keys

Thank you for your interest in contributing! 🎹

## How to Contribute

### Reporting Bugs
- Use the GitHub issue tracker
- Include steps to reproduce
- Specify which backend (Python/C++/Rust) is affected
- Include error logs if applicable

### Suggesting Features
- Open an issue with the "enhancement" label
- Describe the feature and its use case
- Explain which backend would handle it

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly (all three backends if applicable)
5. Commit with clear messages (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Setup

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/piano-128-keys.git
cd piano-128-keys

# Run setup
chmod +x setup.sh
./setup.sh
```

## Code Style

### Python
- Follow PEP 8
- Use type hints
- Add docstrings to functions

### C++
- Follow C++17 standards
- Use smart pointers
- Comment complex DSP algorithms

### Rust
- Run `cargo fmt` before committing
- Run `cargo clippy` and fix warnings
- Follow Rust naming conventions

### React/JavaScript
- Use ES6+ features
- Follow React best practices
- Use functional components with hooks

## Testing

Before submitting:
```bash
# Test Python backend
curl http://localhost:8001/api/python/health

# Test C++ backend
curl http://localhost:8002/api/cpp/health

# Test Rust backend
curl http://localhost:8003/api/rust/health

# Test database
psql -U piano_user -d piano_db -c "SELECT COUNT(*) FROM users;"
```

## Architecture Guidelines

When adding features:
- **Python**: ML/Analytics features (pattern recognition, predictions)
- **C++**: Real-time audio features (effects, DSP)
- **Rust**: Concurrency features (parallel processing, state management)
- **Database**: Ensure data persists across restarts

## Documentation

- Update README.md for user-facing changes
- Update ARCHITECTURE.md for structural changes
- Add inline comments for complex logic
- Update API documentation

## Questions?

Open an issue or start a discussion!

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
