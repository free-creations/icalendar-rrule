# frozen_string_literal: true
require 'icalendar-rrule'
##
# Tests for Time refinements that support iCalendar time concepts.
#
# These tests verify the floating? method which detects "floating time" -
# wall-clock time without timezone information.
#
RSpec.describe 'Icalendar::Rrule::TimeRefinements' do
  using Icalendar::Rrule::TimeRefinements

  describe Time do
    describe '#floating?' do
      context 'when Time has offset 0 and zone is nil (floating time)' do
        subject(:floating_time) { Time.new(2026, 1, 7, 14, 30, 0, 0) }

        it 'returns true' do
          expect(floating_time.floating?).to be true
        end

        it 'has zone == nil' do
          expect(floating_time.zone).to be_nil
        end

        it 'has utc_offset == 0' do
          expect(floating_time.utc_offset).to eq(0)
        end

        it 'is not utc?' do
          expect(floating_time.utc?).to be false
        end
      end

      context 'when Time is UTC' do
        subject(:utc_time) { Time.utc(2026, 1, 7, 14, 30, 0) }

        it 'returns false' do
          expect(utc_time.floating?).to be false
        end

        it 'has zone == "UTC"' do
          expect(utc_time.zone).to eq('UTC')
        end

        it 'is utc?' do
          expect(utc_time.utc?).to be true
        end
      end

      context 'when Time has explicit positive offset' do
        subject(:zoned_time) { Time.new(2026, 1, 7, 14, 30, 0, '+01:00') }

        it 'returns false' do
          expect(zoned_time.floating?).to be false
        end

        it 'has a nil zone (unfortunately)' do
          expect(zoned_time.zone).to be_nil
        end

        it 'has utc_offset == 3600' do
          expect(zoned_time.utc_offset).to eq(3600)
        end
      end

      context 'when Time has explicit negative offset' do
        subject(:zoned_time) { Time.new(2026, 1, 7, 14, 30, 0, '-05:00') }

        it 'returns false' do
          expect(zoned_time.floating?).to be false
        end

        it 'has a nil zone (unfortunately)' do
          expect(zoned_time.zone).to be_nil
        end

        it 'has utc_offset == -18000' do
          expect(zoned_time.utc_offset).to eq(-18000)
        end
      end

      context 'when Time is local system time' do
        subject(:local_time) { Time.new(2026, 1, 7, 14, 30, 0) }

        it 'returns false (local time has a zone)' do
          expect(local_time.floating?).to be false
        end

        it 'has a non-nil zone (system timezone abbreviation)' do
          # Zone will be something like "CET", "EST", etc.
          expect(local_time.zone).not_to be_nil
        end
      end

      context 'when Time is created with Time.now' do
        subject(:now_time) { Time.now }

        it 'returns false' do
          expect(now_time.floating?).to be false
        end
      end

      context 'edge cases' do
        it 'handles midnight floating time' do
          midnight = Time.new(2026, 1, 1, 0, 0, 0, 0)
          expect(midnight.floating?).to be true
        end

        it 'handles end of day floating time' do
          end_of_day = Time.new(2026, 12, 31, 23, 59, 59, 0)
          expect(end_of_day.floating?).to be true
        end

        it 'handles leap year date' do
          leap_day = Time.new(2024, 2, 29, 12, 0, 0, 0)
          expect(leap_day.floating?).to be true
        end
      end
    end

    describe '#to_floating' do
      context 'when given a valid floating time object' do
        it 'returns the object unchanged (same object_id)' do
          f_time = Time.new(2026, 1, 10, 17, 5, 21, 0)
          result = f_time.to_floating

          expect(result).to equal(f_time) # same object
          expect(result.floating?).to be true
        end
      end

      context 'when given a time with positive offset' do
        it 'converts to floating time preserving wall-clock components' do
          zoned_time = Time.new(2026, 1, 10, 17, 5, 21, '+02:00')
          result = zoned_time.to_floating

          expect(result.year).to eq(2026)
          expect(result.month).to eq(1)
          expect(result.day).to eq(10)
          expect(result.hour).to eq(17)
          expect(result.min).to eq(5)
          expect(result.sec).to eq(21)
          expect(result.utc_offset).to eq(0)
          expect(result.zone).to be_nil
          expect(result.floating?).to be true
        end
      end

      context 'when given a time with negative offset' do
        it 'converts to floating time preserving wall-clock components' do
          zoned_time = Time.new(2026, 7, 15, 9, 30, 0, '-05:00')
          result = zoned_time.to_floating

          expect(result.year).to eq(2026)
          expect(result.month).to eq(7)
          expect(result.day).to eq(15)
          expect(result.hour).to eq(9)
          expect(result.min).to eq(30)
          expect(result.sec).to eq(0)
          expect(result.floating?).to be true
        end
      end

      context 'when given a UTC time' do
        it 'converts to floating time' do
          utc_time = Time.utc(2026, 3, 20, 12, 0, 0)
          result = utc_time.to_floating

          expect(result.hour).to eq(12)
          expect(result.utc?).to be false
          expect(result.floating?).to be true
        end
      end

      context 'when given a local system time' do
        it 'converts to floating time preserving wall-clock components' do
          local_time = Time.new(2026, 1, 10, 17, 5, 21)
          result = local_time.to_floating

          expect(result.year).to eq(2026)
          expect(result.month).to eq(1)
          expect(result.day).to eq(10)
          expect(result.hour).to eq(17)
          expect(result.min).to eq(5)
          expect(result.sec).to eq(21)
          expect(result.floating?).to be true
        end
      end
    end

    describe '#ensure_floating' do
      context 'when given a valid floating time object' do
        it 'returns the object unchanged (same object_id)' do
          f_time = Time.new(2026, 1, 10, 17, 5, 21, 0)
          result = f_time.ensure_floating

          expect(result).to equal(f_time) # same object
        end

        it 'does not log a warning' do
          log_output = StringIO.new
          logger = Logger.new(log_output)
          Icalendar::Rrule.logger = logger

          f_time = Time.new(2026, 1, 10, 17, 5, 21, 0)
          f_time.ensure_floating

          expect(log_output.string).to be_empty

          # Reset logger to silent
          Icalendar::Rrule.logger = Logger.new(File::NULL)
        end
      end

      context 'when given a time with offset' do
        it 'converts to floating time and logs a warning' do
          log_output = StringIO.new
          logger = Logger.new(log_output)
          Icalendar::Rrule.logger = logger

          faulty_time = Time.new(2026, 1, 10, 17, 5, 21, '+02:00')
          result = faulty_time.ensure_floating

          expect(result.year).to eq(2026)
          expect(result.month).to eq(1)
          expect(result.day).to eq(10)
          expect(result.hour).to eq(17)
          expect(result.min).to eq(5)
          expect(result.sec).to eq(21)
          expect(result.utc_offset).to eq(0)
          expect(result.zone).to be_nil
          expect(result.floating?).to be true

          expect(log_output.string).to include('should be floating')
          expect(log_output.string).to include('converting')

          # Reset logger to silent
          Icalendar::Rrule.logger = Logger.new(File::NULL)
        end
      end

      context 'when given a UTC time' do
        it 'converts to floating time and logs a warning' do
          log_output = StringIO.new
          logger = Logger.new(log_output)
          Icalendar::Rrule.logger = logger

          utc_time = Time.utc(2026, 1, 10, 17, 5, 21)
          result = utc_time.ensure_floating

          expect(result.floating?).to be true
          expect(log_output.string).to include('should be floating')

          # Reset logger to silent
          Icalendar::Rrule.logger = Logger.new(File::NULL)
        end
      end
    end

    describe '#into_timezone' do
      # Use exotic timezones to avoid system-TZ conflicts
      let(:kathmandu_tz) { ActiveSupport::TimeZone['Asia/Kathmandu'] } # UTC+5:45, no DST
      let(:adelaide_tz) { ActiveSupport::TimeZone['Adelaide'] }        # UTC+9:30/+10:30, has DST
      let(:newfoundland_tz) { ActiveSupport::TimeZone['Newfoundland'] } # UTC-3:30/-2:30, has DST

      context 'when called on floating time' do
        it 'embeds into Kathmandu timezone correctly' do
          floating = Time.new(2026, 3, 30, 10, 0, 0, 0)
          result = floating.into_timezone(kathmandu_tz)

          expect(result).to be_a(ActiveSupport::TimeWithZone)
          expect(result.year).to eq(2026)
          expect(result.month).to eq(3)
          expect(result.day).to eq(30)
          expect(result.hour).to eq(10)
          expect(result.min).to eq(0)
          expect(result.time_zone.name).to eq('Asia/Kathmandu')
          expect(result.utc_offset).to eq(20700) # +05:45 in seconds
        end

        it 'embeds into Adelaide timezone during DST (summer)' do
          # Adelaide DST is active from October to April
          floating = Time.new(2026, 1, 15, 14, 30, 0, 0)
          result = floating.into_timezone(adelaide_tz)

          expect(result).to be_a(ActiveSupport::TimeWithZone)
          expect(result.hour).to eq(14)
          expect(result.min).to eq(30)
          expect(result.time_zone.name).to eq('Adelaide')
          expect(result.utc_offset).to eq(37800) # +10:30 (DST active)
        end

        it 'embeds into Adelaide timezone during winter (no DST)' do
          # Adelaide standard time (no DST) in June
          floating = Time.new(2026, 6, 15, 14, 30, 0, 0)
          result = floating.into_timezone(adelaide_tz)

          expect(result).to be_a(ActiveSupport::TimeWithZone)
          expect(result.hour).to eq(14)
          expect(result.min).to eq(30)
          expect(result.time_zone.name).to eq('Adelaide')
          expect(result.utc_offset).to eq(34200) # +09:30 (no DST)
        end

        it 'embeds into Newfoundland timezone with negative half-hour offset' do
          floating = Time.new(2026, 7, 1, 16, 45, 0, 0)
          result = floating.into_timezone(newfoundland_tz)

          expect(result).to be_a(ActiveSupport::TimeWithZone)
          expect(result.hour).to eq(16)
          expect(result.min).to eq(45)
          expect(result.time_zone.name).to eq('Newfoundland')
          # Newfoundland DST: UTC-2:30 = -9000 seconds
          expect(result.utc_offset).to eq(-9000)
        end

        it 'accepts timezone as string' do
          floating = Time.new(2026, 5, 10, 12, 0, 0, 0)
          result = floating.into_timezone('Asia/Kathmandu')

          expect(result).to be_a(ActiveSupport::TimeWithZone)
          expect(result.hour).to eq(12)
          expect(result.time_zone.name).to eq('Asia/Kathmandu')
        end

        it 'accepts timezone as ActiveSupport::TimeZone object' do
          floating = Time.new(2026, 5, 10, 12, 0, 0, 0)
          result = floating.into_timezone(kathmandu_tz)

          expect(result).to be_a(ActiveSupport::TimeWithZone)
          expect(result.hour).to eq(12)
          expect(result.time_zone).to eq(kathmandu_tz)
        end

        it 'handles midnight correctly' do
          floating = Time.new(2026, 1, 1, 0, 0, 0, 0)
          result = floating.into_timezone(kathmandu_tz)

          expect(result.hour).to eq(0)
          expect(result.min).to eq(0)
          expect(result.time_zone.name).to eq('Asia/Kathmandu')
        end

        it 'handles end-of-day correctly' do
          floating = Time.new(2026, 12, 31, 23, 59, 59, 0)
          result = floating.into_timezone(adelaide_tz)

          expect(result.hour).to eq(23)
          expect(result.min).to eq(59)
          expect(result.sec).to eq(59)
        end
      end

      context 'when called on non-floating time' do
        it 'raises ArgumentError for UTC time' do
          utc_time = Time.utc(2026, 1, 10, 12, 0, 0)

          expect { utc_time.into_timezone(kathmandu_tz) }.to raise_error(
                                                               ArgumentError,
                                                               /into_timezone can only be called on floating time/
                                                             )
        end

        it 'raises ArgumentError for time with positive offset' do
          zoned_time = Time.new(2026, 1, 10, 12, 0, 0, '+02:00')

          expect { zoned_time.into_timezone(kathmandu_tz) }.to raise_error(
                                                                 ArgumentError,
                                                                 /into_timezone can only be called on floating time/
                                                               )
        end

        it 'raises ArgumentError for time with negative offset' do
          zoned_time = Time.new(2026, 1, 10, 12, 0, 0, '-05:00')

          expect { zoned_time.into_timezone(adelaide_tz) }.to raise_error(
                                                                ArgumentError,
                                                                /into_timezone can only be called on floating time/
                                                              )
        end

        it 'raises ArgumentError for local system time' do
          local_time = Time.new(2026, 1, 10, 12, 0, 0)

          expect { local_time.into_timezone(kathmandu_tz) }.to raise_error(
                                                                 ArgumentError,
                                                                 /into_timezone can only be called on floating time/
                                                               )
        end
      end

      context 'when given invalid timezone' do
        it 'falls back to UTC and logs warning' do
          log_output = StringIO.new
          logger = Logger.new(log_output)
          Icalendar::Rrule.logger = logger

          floating = Time.new(2026, 5, 10, 14, 30, 0, 0)
          result = floating.into_timezone('FooBar/BazQux')

          expect(result).to be_a(ActiveSupport::TimeWithZone)
          expect(result.time_zone.name).to eq('UTC')
          expect(result.hour).to eq(14) # Wall-clock time preserved
          expect(log_output.string).to include('Invalid timezone')
          expect(log_output.string).to include('FooBar/BazQux')

          # Reset logger to silent
          Icalendar::Rrule.logger = Logger.new(File::NULL)
        end
      end

      context 'round-trip conversion (to_floating → into_timezone)' do
        it 'preserves wall-clock time in Kathmandu' do
          original = kathmandu_tz.local(2026, 3, 30, 10, 15, 30)
          floating = original.to_time.to_floating
          result = floating.into_timezone(kathmandu_tz)

          expect(result.year).to eq(2026)
          expect(result.month).to eq(3)
          expect(result.day).to eq(30)
          expect(result.hour).to eq(10)
          expect(result.min).to eq(15)
          expect(result.sec).to eq(30)
          expect(result.time_zone.name).to eq('Asia/Kathmandu')
        end

        it 'preserves wall-clock time across DST boundary in Adelaide' do
          # March 30, 2026: DST ends in Adelaide (03:00 → 02:00)
          original = adelaide_tz.local(2026, 3, 30, 10, 0, 0)
          floating = original.to_time.to_floating
          result = floating.into_timezone(adelaide_tz)

          expect(result.hour).to eq(10)
          expect(result.min).to eq(0)
          expect(result.time_zone.name).to eq('Adelaide')
        end
      end
    end
  end


  describe 'semantic difference between floating time and UTC' do
    let(:floating) { Time.new(2026, 6, 15, 14, 30, 0, 0) }
    let(:utc) { Time.utc(2026, 6, 15, 14, 30, 0) }

    it 'both have the same wall-clock components' do
      expect(floating.year).to eq(utc.year)
      expect(floating.month).to eq(utc.month)
      expect(floating.day).to eq(utc.day)
      expect(floating.hour).to eq(utc.hour)
      expect(floating.min).to eq(utc.min)
      expect(floating.sec).to eq(utc.sec)
    end

    it 'both have utc_offset == 0' do
      expect(floating.utc_offset).to eq(0)
      expect(utc.utc_offset).to eq(0)
    end

    it 'differ in zone' do
      expect(floating.zone).to be_nil
      expect(utc.zone).to eq('UTC')
    end

    it 'differ in utc?' do
      expect(floating.utc?).to be false
      expect(utc.utc?).to be true
    end

    it 'differ in floating?' do
      expect(floating.floating?).to be true
      expect(utc.floating?).to be false
    end
  end
end