# Change Log

All notable changes to this project will be documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com), and this project adheres to [Semantic Versioning](https://semver.org).

## [1.0.0] - 19-06-2026

### Added

- Support for multiple BRINs via `AuthBrinKeys` (JSON array with authorization key and BRIN combinations).
- Support for certificate input as `CertificateBase64` for cloud PowerShell flows.
- Extended person mappings.

### Changed

- Configuration changed from single `Autorisatiesleutel`/`brinIdentifiers` to `AuthBrinKeys`.
- SOAP request default XSD version updated from `2.2` to `2.3`.
- Contract end date calculation changed from `YYYY-08-01` to `YYYY-07-31`.
- Increased person output JSON depth from `3` to `10` to preserve nested data.

### Fixed

- Fixed web request splatting variable name (`$spatWebrequest` to `$splatWebrequest`) in persons retrieval.
- Added validation and clear error handling when no certificate is configured.


## [0.5.0-beta] - 21-08-2023

This is the first changelog of this existing connector.
