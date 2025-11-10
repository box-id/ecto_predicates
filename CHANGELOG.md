# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [unreleased]

## [0.5.1] - 2025-11-10

### Fixed
- Use `ANY()` operator for `in` and `not_in` predicates.

## [0.5.0] - 2025-10-31

### Breaking Changes

- Handle null values for `in` and `not_in` operators to be aligned with `eq`.
- `like`, `ilike`, `starts_with` operators now escape `arg` s.t. `%` and `_` characters are not interpreted as
  placeholders anymore.
- Field names are now converted to atoms using `String.to_existing_atom/1`, failing for unknown field names.

### Added

- `not_eq` operator
- `ends_with` operator

### Deprecated

- `contains` operator for string values: Use `like` instead, as `contains` will only be applicable to collections in the
  future.

### Changed

- `PredicateError`'s message now uses `inspect` on the offending predicate instead of JSON serialization to reduce
  library dependencies

## [0.4.0] - 2025-09-25

### Breaking Changes

- Renamed `Utils` module to `Predicates.Utils` to avoid module name collision

[unreleased]: https://github.com/box-id/ecto_predicates/compare/0.5.1...HEAD
[0.5.1]: https://github.com/box-id/ecto_predicates/compare/0.5.0...0.5.1
[0.5.0]: https://github.com/box-id/ecto_predicates/compare/0.4.0...0.5.0
[0.4.0]: https://github.com/box-id/ecto_predicates/compare/0.3.0...0.4.0
