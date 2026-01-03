# ICU4X Ruby Gem

Ruby bindings for ICU4X, providing Unicode internationalization support.

## Project Structure

- `lib/` - Ruby source code
- `ext/icu4x/` - Rust extension (Magnus-based FFI)
- `spec/` - RSpec tests
- `doc/` - Documentation markdown files

## Code Style

### Ruby
- Use endless method definitions for single-line methods
- Access scope (private, etc.) on each method individually
- Data classes: define without block, reopen for methods
- Accept only Pathname for file path arguments, never String
- RSpec: never use `described_class`

### Rust
- Follow standard Rust conventions
- Use Magnus for Ruby bindings

## Testing

- Run tests: `bundle exec rake spec`
- Run linter: `bundle exec rake rubocop`
- Build extension: `bundle exec rake compile`

## Important Notes

- No backward compatibility concerns until v1.0
- YARD documentation uses markdown markup
