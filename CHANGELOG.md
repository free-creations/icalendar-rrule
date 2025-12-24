# Changelog

All notable changes to this project will be documented in this file.

## [0.2.0] - 2025-12-24

### Added
- Support for tasks (VTODOs) with RRULE expansion
- New `single_timestamp?` predicate for zero-duration events/deadline-only tasks
- Comprehensive timezone extraction with multiple fallback strategies
- Better system timezone detection (ENV['TZ'], /etc/timezone, TZInfo)

### Changed
- **BREAKING**: Events without explicit timezone now use system timezone instead of UTC
- All-day events without DTEND now correctly compute 1-day duration in date-space
- Relaxed `ice_cube` dependency to >= 0.16 (tested with 0.17.0)
- `all_day?` now returns false for tasks (only applies to events)

### Fixed
- Timezone handling for recurring events (RRULE expansion now preserves timezone)
- Floating time interpretation (DateTime with offset 0 no longer treated as UTC)
- All-day events no longer experience timezone shift errors
- Compatibility with icalendar gem 2.12.1 (DowncasedHash handling)
- Task time handling (zero-duration tasks with only DUE)

### Internal
- Enhanced `_extract_explicit_timezone` for better timezone detection
- Added `_dtstart_is_all_day?` helper
- Improved `_guess_system_timezone` with 5 fallback methods
- Better test coverage (145+ tests, including exotic timezones)

## [0.1.7] - 2020-xx-xx
- Previous stable release