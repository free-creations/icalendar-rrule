# frozen_string_literal: true

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