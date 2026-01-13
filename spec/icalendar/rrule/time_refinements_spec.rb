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