# Changelog

All notable changes to Termpix will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2025-10-27

### Added
- EXIF auto-orient support for w3m protocol - images with EXIF rotation data now display with correct orientation
- Automatic creation and cleanup of rotated temporary files

### Fixed
- Images with EXIF orientation metadata (e.g., phone photos) now display correctly instead of rotated
- Aspect ratio preservation now works correctly for rotated images
- Sixel protocol aspect ratio preservation with ImageMagick '>' flag

### Changed
- Kitty graphics protocol conclusively disabled after extensive testing (fundamentally incompatible with curses)
- Documented architectural limitations with Kitty protocol

## [0.1.0] - 2025-10-26

### Initial Release
- Multi-protocol terminal image display library
- Sixel protocol support (mlterm, xterm, foot)
- w3m protocol support (urxvt, kitty, most terminals)
- Automatic protocol detection
- Clean API for curses-based applications
