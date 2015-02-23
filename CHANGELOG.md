# Change Log

All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).



## [v1.2.0] - 2015-02-23

### Added

- Getters for various action properties.


## [v1.1.0] - 2015-02-17

### Added

- Support for iterating over all actions in an event via the
  `allActions()` and `forEachAction()` methods.

- This change log.

### Changed

- Unit tests no longer call `print()`, eliminating unnecessary output.

- `make tests` now runs [busted][] with an explicit root and pattern
  setting since the recent version of busted no longer reads the
  `.busted` file.

### Fixed

- Documentation for three method signatures.  The README incorrectly
  omitted the second argument for those methods.

- Failing unit test for `setActionInterval()`.


## [v1.0.0] - 2013-09-14

First public release.



[v1.2.0]: https://github.com/ejmr/Luvent/releases/tag/v1.2.0
[v1.1.0]: https://github.com/ejmr/Luvent/releases/tag/v1.1.0
[v1.0.0]: https://github.com/ejmr/Luvent/releases/tag/v1.0.0
[busted]: http://olivinelabs.com/busted/
