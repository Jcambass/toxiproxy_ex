# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.1] - 2025-07-29
### Changed
- Updated `tesla` dependency to `~> 1.3` to ensure compatibility
- Updated `jason` dependency to `~> 1.0` to ensure compatibility
- Updated `castore` dependency to `~> 1.0` to ensure compatibility
- Updated `mint` dependency to `~> 1.0` to ensure compatibility

## [2.0.0] - 2024-02-04
Starting with this version we will align our releases with the Toxiproxy server version. This means that the major version of this library will be the same as the major version of the Toxiproxy server it supports.
### Fixed
- Fixed bug where `ToxiproxyEx.apply!` wouldn't propely destroy toxics when the passed block raised an error.
- Fixed bug where `ToxiproxyEx.down!` wouldn't propely re-enable the proxies when the passed block raised an error.
- Fixed [compatibility with Toxiproxy 2.6.0 version endpoint](https://github.com/Jcambass/toxiproxy_ex/pull/22/commits/0b2cb5b763e3abcfb0f3058e21c63fba4fe51d9d). See [Toxiproxy 2.6.0 Bug report](https://github.com/Shopify/toxiproxy/pull/538).
### Changed
- Changed the format of the `ServerError` message. Now includes the HTTP method and URL that failed.

## [1.1.1] - 2023-08-06

### Fixed
- Fixed [intermittent ServerError](https://github.com/Jcambass/toxiproxy_ex/issues/7).


## [1.1.0] - 2021-06-29
### Added
- New `host` application config to specify the address of the toxiproxy server to use.

### Fixed
- Fixed missing `!` in `ToxiproxyEx.populate!` in Readme.

## [1.0.0] - 2020-10-19
- Initial Release
