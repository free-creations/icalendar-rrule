# icalendar-rrule
This is an add-on to the [iCalendar Gem](https://github.com/icalendar/icalendar).
It helps to handle calendars in iCalendar format with __repeating events__.

According to the [RFC 5545](https://tools.ietf.org/html/rfc5545) specification, 
repeating events are represented by one single entry, the repetitions being shown by
an attached _repeat rule_. Thus when we iterate through a calendar with, for example,
a daily repeating event, 
we'll only see one single entry in the Calendar.
Although, for a whole month there would be 30 or 31 events in reality.

The _icalendar-rrule gem_ patches an additional function called `scan` into the _iCalendar Gem_. 
The _scan_ shows all events by unrolling the _repeat rule_ for a 
given time period.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'icalendar-rrule'
```

and run `bundle install` from your shell.

## Usage

For explanations on how to parse and process RFC 5545 compatible calendars, please
have a look at the [iCalendar gem](http://github.com/icalendar/icalendar).

To use this gem we'll first have to require it: 

`require 'icalendar-rrule'`

Further we have to declare the use of the "Scannable" namespace. 
This is called a "[Refinement](https://ruby-doc.org/core-2.5.0/doc/syntax/refinements_rdoc.html)",
a _new Ruby core feature_ since Ruby 2.0, that makes "monkey patching" a bit 
more acceptable.

`using Icalendar::Scannable`

Now we can inquire a calendar for all events (or tasks) within in a time span. 

`scan = calendar.scan(begin_time, closing_time)`

Here is a simple example:
```ruby
require 'icalendar-rrule' # this will require all needed GEMS including the icalendar gem

using Icalendar::Scannable # this will make the function Icalendar::Calendar.scan available

# we create a calendar with one single event
calendar = Icalendar::Calendar.new
calendar.event do |e|
  # the event starts on January first and lasts from half past eight to five o' clock
  e.dtstart     =  DateTime.civil(2018, 1, 1, 8, 30)
  e.dtend       =  DateTime.civil(2018, 1, 1, 17, 00)
  e.summary     = 'Working'
  # the event repeats all working days
  e.rrule       = 'FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR'
end

begin_time =   Date.new(2018, 4, 22)
closing_time = Date.new(2018, 4, 29)

# we are interested in the calendar entries in the last week of April
scan = calendar.scan(begin_time, closing_time) # that's where the magic happens


scan.each do |occurrence|
  puts "#{occurrence.start_time.strftime('%a. %b. %d. %k:%M')}-#{occurrence.end_time.strftime('%k:%M')}"
end
```
This will produce:

```
Mon. Apr. 23.  8:30-17:00 
Tue. Apr. 24.  8:30-17:00 
Wed. Apr. 25.  8:30-17:00 
Thu. Apr. 26.  8:30-17:00 
Fri. Apr. 27.  8:30-17:00 
```

For a more elaborate example, please have a look at 
<https://github.com/free-creations/sk_calendar>

## Configuration

### Logging

By default, the gem logs nothing. You can enable logging for debugging timezone issues:

```ruby
# Enable logging to STDOUT
Icalendar::Rrule.logger = Logger.new($stdout)

# Or use Rails logger
Icalendar::Rrule.logger = Rails.logger
```

## Time handling (start/end) and timezones

This gem represents both VEVENTs and VTODOs uniformly as *occurrences* with a
normalised `start_time` and `end_time` (both `ActiveSupport::TimeWithZone`).

### Normalising start_time / end_time

Input components can specify time using `DTSTART`, `DTEND`, `DUE` and/or `DURATION`.
In practice these fields are often incomplete or inconsistent, therefore this gem
derives a sensible time range using the following rules:

- `start_time`
  1. If `DTSTART` is present: `start_time = DTSTART`
  2. Else if `DUE` and `DURATION` are present: `start_time = DUE - DURATION`
  3. Else if only `DUE` is present: `start_time = DUE` (deadline-only / zero-duration)
  4. Else: a null fallback is used (Unix epoch)

- `end_time`
  1. If `DUE` is present: `end_time = DUE`
  2. Else if `DTEND` is present: `end_time = DTEND`
  3. Else if `DTSTART` is present: `end_time = start_time + duration`
  4. Else: `end_time = epoch + duration`

For _all-day VEVENTs_ (`DTSTART` as DATE) without `DTEND`, `DUE` and `DURATION`, the
duration is assumed to be one day (RFC 5545).

### Recurrence semantics (RRULE)

Recurrences are expanded in floating (wall-clock) time. The `RRULE` is unrolled
without applying offsets during expansion; timezone conversion is applied only
after occurrences have been generated.

Rationale:

- By keeping recurrence logic in wall-clock time and deferring timezone application,
  this gem avoids DST-related drift, ambiguous instants and retroactive rule changes,
  while remaining predictable and deterministic.

### Timezone resolution

When mapping values to `ActiveSupport::TimeWithZone`, timezones are resolved with
the following precedence:

1. An explicit timezone on the value itself (`TZID` / `TimeWithZone`)
2. A timezone defined by the parent calendar (`VTIMEZONE` / calendar settings)
3. The system timezone
4. UTC as a final fallback

Floating date-times(i.e. `DATE-TIME` values without `TZID` and without `Z`) are interpreted as 
local time and materialised in the _system time zone_.


## Used Libraries

- [iCalendar Gem](https://github.com/icalendar/icalendar).
- [Ice cube](https://github.com/seejohnrun/ice_cube)
- **Active Support:** see also 
  [How to Load Core Extensions](http://edgeguides.rubyonrails.org/active_support_core_extensions.html#how-to-load-core-extensions)

## Links
- [Wikipedia](https://en.wikipedia.org/wiki/ICalendar) article explaining the _iCalendar_ format.
- [RFC 5545](https://tools.ietf.org/html/rfc5545) Internet 
  Calendaring and Scheduling Core Object Specification.
- The Ruby [iCalendar gem](http://github.com/icalendar/icalendar) is used here as a base for 
  handling ical data.
- [RI_CAL](https://github.com/rubyredrick/ri_cal) is a project similar 
  to this one that aims to 
  "support important things like enumerating occurrences of repeating events".
  A newer fork is available here: [kdgm/ri_cal](https://github.com/kdgm/ri_cal)
- [The deceptively complex world of calendar events and RRULEs](https://www.nylas.com/blog/calendar-events-rrules/).
  A Blog of Jennie Lees.


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/free-creations/icalendar-rrule.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
