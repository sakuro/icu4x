# frozen_string_literal: true

# YARD documentation for ICU4X Ruby API.
# This file contains only @!parse directives for documentation purposes.
# No actual code is evaluated.

# @!parse
#   # ICU4X provides internationalization (i18n) functionality for Ruby applications.
#   #
#   # This library wraps ICU4X, a Unicode internationalization library written in Rust,
#   # providing locale-aware formatting, parsing, and text processing capabilities.
#   #
#   # @example Configure data path
#   #   ICU4X.configure do |config|
#   #     config.data_path = Pathname.new("data.postcard")
#   #   end
#   #
#   # @example Using environment variable
#   #   # Set ICU4X_DATA_PATH environment variable
#   #   ENV["ICU4X_DATA_PATH"] = "/path/to/data.postcard"
#   #
#   # @see https://github.com/unicode-org/icu4x ICU4X project
#   #
#   module ICU4X
#     # The version of the icu4x gem.
#     VERSION = "0.0.0"
#
#     # Returns the default data provider, lazily loaded from configuration.
#     #
#     # The provider is created from `config.data_path` or the `ICU4X_DATA_PATH`
#     # environment variable. Once created, the provider is cached.
#     #
#     # @return [DataProvider, nil] the default provider, or nil if not configured
#     #
#     # @example
#     #   ICU4X.configure { |c| c.data_path = Pathname.new("data.postcard") }
#     #   provider = ICU4X.default_provider
#     #
#     def self.default_provider; end
#
#     # Resets the cached default data provider.
#     #
#     # After calling this method, the next call to {.default_provider} will
#     # create a new provider from the current configuration.
#     #
#     # @return [void]
#     #
#     def self.reset_default_provider!; end
#
#     # Base error class for all ICU4X errors.
#     #
#     class Error < StandardError; end
#
#     # Raised when a locale identifier is invalid or cannot be parsed.
#     #
#     # @example
#     #   ICU4X::Locale.parse("invalid!!!")  # raises LocaleError
#     #
#     class LocaleError < Error; end
#
#     # Raised when data loading or provider operations fail.
#     #
#     # @example
#     #   ICU4X::DataProvider.from_blob(Pathname.new("nonexistent.postcard"))  # raises DataError
#     #
#     class DataError < Error; end
#
#     # Raised when data generation fails.
#     #
#     class DataGeneratorError < Error; end
#
#     # Provides locale data for ICU4X formatters and other components.
#     #
#     # DataProvider loads precompiled locale data from a binary blob file.
#     # The blob can be generated using {DataGenerator.export}.
#     #
#     # @example Load a data provider
#     #   provider = ICU4X::DataProvider.from_blob(Pathname.new("data.postcard"))
#     #
#     # @example Use with a formatter
#     #   provider = ICU4X::DataProvider.from_blob(Pathname.new("data.postcard"))
#     #   formatter = ICU4X::NumberFormat.new(locale, provider: provider)
#     #
#     class DataProvider
#       # Creates a DataProvider from a binary blob file.
#       #
#       # @param path [Pathname] path to the .postcard blob file
#       # @param priority [Symbol] collation fallback priority, either `:language` or `:region`
#       # @return [DataProvider] a new data provider instance
#       # @raise [DataError] if the file cannot be read or is invalid
#       #
#       # @example
#       #   provider = ICU4X::DataProvider.from_blob(Pathname.new("data.postcard"))
#       #   provider = ICU4X::DataProvider.from_blob(Pathname.new("data.postcard"), priority: :region)
#       #
#       def self.from_blob(path, priority: :language); end
#     end
#
#     # Generates locale data blobs for use with {DataProvider}.
#     #
#     # DataGenerator exports Unicode CLDR data into a compact binary format
#     # that can be loaded at runtime by {DataProvider}.
#     #
#     # @example Generate data for specific locales
#     #   ICU4X::DataGenerator.export(
#     #     locales: ["en", "ja", "de"],
#     #     markers: :all,
#     #     format: :blob,
#     #     output: Pathname.new("data.postcard")
#     #   )
#     #
#     class DataGenerator
#       # Exports locale data to a file.
#       #
#       # The `locales` parameter accepts either a Symbol for predefined locale sets
#       # based on CLDR coverage levels, or an Array of locale identifier strings.
#       # When using `with_descendants`, ancestor locales (including `und`) are
#       # automatically included for fallback support.
#       #
#       # @param locales [Symbol, Array<String>] locale specification:
#       #   - `:full` - all CLDR locales (700+)
#       #   - `:recommended` - locales with basic, moderate, or modern coverage (164)
#       #   - `:modern` - locales with modern coverage only (103)
#       #   - `:moderate` - locales with moderate coverage only
#       #   - `:basic` - locales with basic coverage only
#       #   - `Array<String>` - explicit list of locale identifiers
#       # @param markers [Symbol, Array<String>] data markers to include;
#       #   use `:all` for all markers, or specify individual marker names
#       # @param format [Symbol] output format, currently only `:blob` is supported
#       # @param output [Pathname] path to write the output file
#       # @return [void]
#       # @raise [DataGeneratorError] if export fails
#       #
#       # @example Export all data for Japanese and English
#       #   ICU4X::DataGenerator.export(
#       #     locales: ["ja", "en"],
#       #     markers: :all,
#       #     format: :blob,
#       #     output: Pathname.new("i18n_data.postcard")
#       #   )
#       #
#       # @example Export data for all modern coverage locales
#       #   ICU4X::DataGenerator.export(
#       #     locales: :modern,
#       #     markers: :all,
#       #     format: :blob,
#       #     output: Pathname.new("modern_data.postcard")
#       #   )
#       #
#       # @see .available_markers
#       # @see https://cldr.unicode.org/index/cldr-spec/coverage-levels CLDR Coverage Levels
#       #
#       def self.export(locales:, markers:, format:, output:); end
#
#       # Returns a list of all available data marker names.
#       #
#       # @return [Array<String>] list of marker names
#       #
#       # @example
#       #   markers = ICU4X::DataGenerator.available_markers
#       #   #=> ["CalendarJapaneseExtendedV1", "CalendarJapaneseModernV1", ...]
#       #
#       def self.available_markers; end
#     end
#
#     # Represents a Unicode Locale Identifier (BCP 47).
#     #
#     # Locale provides parsing and access to locale components such as
#     # language, script, region, and extensions.
#     #
#     # @example Parse a locale identifier
#     #   locale = ICU4X::Locale.parse("ja-JP")
#     #   locale.language  #=> "ja"
#     #   locale.region    #=> "JP"
#     #
#     # @example Parse a POSIX locale
#     #   locale = ICU4X::Locale.parse_posix("ja_JP.UTF-8")
#     #   locale.language  #=> "ja"
#     #
#     # @see https://unicode.org/reports/tr35/ Unicode Locale Data Markup Language (LDML)
#     #
#     class Locale
#       # Parses a BCP 47 locale identifier string.
#       #
#       # @param locale_str [String] a BCP 47 locale identifier (e.g., "en-US", "ja-JP-u-ca-japanese")
#       # @return [Locale] a new Locale instance
#       # @raise [LocaleError] if the identifier is invalid
#       #
#       # @example
#       #   locale = ICU4X::Locale.parse("en-US")
#       #   locale = ICU4X::Locale.parse("ja-JP-u-ca-japanese")
#       #
#       def self.parse(locale_str); end
#
#       # Parses a POSIX locale string.
#       #
#       # Converts POSIX-style locale identifiers (e.g., "ja_JP.UTF-8") to
#       # Unicode locale format.
#       #
#       # @param posix_str [String] a POSIX locale string
#       # @return [Locale] a new Locale instance
#       # @raise [LocaleError] if the identifier is invalid
#       #
#       # @example
#       #   locale = ICU4X::Locale.parse_posix("ja_JP.UTF-8")
#       #   locale.language  #=> "ja"
#       #   locale.region    #=> "JP"
#       #
#       def self.parse_posix(posix_str); end
#
#       # Returns the language subtag.
#       #
#       # @return [String, nil] the language subtag (e.g., "en", "ja"), or nil if not set
#       #
#       def language; end
#
#       # Returns the script subtag.
#       #
#       # @return [String, nil] the script subtag (e.g., "Latn", "Jpan"), or nil if not set
#       #
#       # @example
#       #   locale = ICU4X::Locale.parse("zh-Hant-TW")
#       #   locale.script  #=> "Hant"
#       #
#       def script; end
#
#       # Returns the region subtag.
#       #
#       # @return [String, nil] the region subtag (e.g., "US", "JP"), or nil if not set
#       #
#       def region; end
#
#       # Returns the locale extensions.
#       #
#       # @return [Hash] a hash containing extension data with keys:
#       #   - `:unicode` [Hash<String, String>] Unicode extension key-value pairs
#       #   - `:transform` [String, nil] Transform extension string
#       #   - `:private` [Array<String>] Private use extensions
#       #
#       # @example
#       #   locale = ICU4X::Locale.parse("ja-JP-u-ca-japanese")
#       #   locale.extensions[:unicode]  #=> {"ca" => "japanese"}
#       #
#       def extensions; end
#
#       # Returns the string representation of the locale.
#       #
#       # @return [String] the normalized BCP 47 locale identifier
#       #
#       def to_s; end
#
#       # Returns a human-readable representation for debugging.
#       #
#       # @return [String] debug representation
#       #
#       def inspect; end
#
#       # Compares two locales for equality.
#       #
#       # @param other [Locale] the locale to compare with
#       # @return [Boolean] true if the locales are equal
#       #
#       def ==(other); end
#
#       # Compares two locales for equality (used by Hash).
#       #
#       # @param other [Locale] the locale to compare with
#       # @return [Boolean] true if the locales are equal
#       #
#       def eql?(other); end
#
#       # Returns the hash code for this locale.
#       #
#       # @return [Integer] hash code
#       #
#       def hash; end
#
#       # Maximizes the locale in place using the Add Likely Subtags algorithm (UTS #35).
#       #
#       # Adds likely script and region subtags based on the language.
#       # This is useful for language negotiation.
#       #
#       # @return [self, nil] self if the locale was modified, nil if already maximized
#       #
#       # @example
#       #   locale = ICU4X::Locale.parse("en")
#       #   locale.maximize!  #=> locale
#       #   locale.to_s       #=> "en-Latn-US"
#       #
#       # @example Already maximized
#       #   locale = ICU4X::Locale.parse("en-Latn-US")
#       #   locale.maximize!  #=> nil
#       #
#       # @see https://unicode.org/reports/tr35/#Likely_Subtags
#       #
#       def maximize!; end
#
#       # Returns a new locale with likely subtags added.
#       #
#       # Non-destructive version of {#maximize!}. The original locale is unchanged.
#       #
#       # @return [Locale] a new locale with likely subtags added
#       #
#       # @example
#       #   locale = ICU4X::Locale.parse("zh")
#       #   expanded = locale.maximize
#       #   locale.to_s    #=> "zh" (unchanged)
#       #   expanded.to_s  #=> "zh-Hans-CN"
#       #
#       def maximize; end
#
#       # Minimizes the locale in place using the Remove Likely Subtags algorithm (UTS #35).
#       #
#       # Removes redundant script and region subtags that can be inferred.
#       # This is useful for language negotiation.
#       #
#       # @return [self, nil] self if the locale was modified, nil if already minimal
#       #
#       # @example
#       #   locale = ICU4X::Locale.parse("ja-Jpan-JP")
#       #   locale.minimize!  #=> locale
#       #   locale.to_s       #=> "ja"
#       #
#       # @example Already minimal
#       #   locale = ICU4X::Locale.parse("en")
#       #   locale.minimize!  #=> nil
#       #
#       # @see https://unicode.org/reports/tr35/#Likely_Subtags
#       #
#       def minimize!; end
#
#       # Returns a new locale with redundant subtags removed.
#       #
#       # Non-destructive version of {#minimize!}. The original locale is unchanged.
#       #
#       # @return [Locale] a new locale with redundant subtags removed
#       #
#       # @example
#       #   locale = ICU4X::Locale.parse("zh-Hans-CN")
#       #   minimal = locale.minimize
#       #   locale.to_s   #=> "zh-Hans-CN" (unchanged)
#       #   minimal.to_s  #=> "zh"
#       #
#       def minimize; end
#     end
#
#     # Provides locale-aware plural rules for cardinal and ordinal numbers.
#     #
#     # PluralRules determines the appropriate plural category for a given number
#     # based on the locale's pluralization rules.
#     #
#     # @example Cardinal plurals
#     #   rules = ICU4X::PluralRules.new(locale)
#     #   rules.select(1)   #=> :one
#     #   rules.select(2)   #=> :other
#     #
#     # @example Ordinal plurals
#     #   rules = ICU4X::PluralRules.new(locale, type: :ordinal)
#     #   rules.select(1)   #=> :one   (1st)
#     #   rules.select(2)   #=> :two   (2nd)
#     #   rules.select(3)   #=> :few   (3rd)
#     #
#     # @see https://unicode.org/reports/tr35/tr35-numbers.html#Language_Plural_Rules
#     #
#     class PluralRules
#       # Creates a new PluralRules instance.
#       #
#       # @param locale [Locale] the locale for plural rules
#       # @param provider [DataProvider, nil] data provider (uses default if nil)
#       # @param type [Symbol] plural rule type, either `:cardinal` or `:ordinal`
#       # @return [PluralRules] a new instance
#       # @raise [DataError] if data for the locale is unavailable
#       #
#       # @example
#       #   rules = ICU4X::PluralRules.new(locale)
#       #   rules = ICU4X::PluralRules.new(locale, type: :ordinal)
#       #
#       def initialize(locale, provider: nil, type: :cardinal); end
#
#       # Selects the plural category for a number.
#       #
#       # @param number [Integer, Float] the number to categorize
#       # @return [Symbol] one of `:zero`, `:one`, `:two`, `:few`, `:many`, or `:other`
#       #
#       # @example
#       #   rules.select(0)    #=> :other (in English)
#       #   rules.select(1)    #=> :one
#       #   rules.select(2)    #=> :other
#       #   rules.select(1.5)  #=> :other
#       #
#       def select(number); end
#
#       # Selects the plural category for a range of numbers.
#       #
#       # This is equivalent to JavaScript's `Intl.PluralRules.selectRange()`.
#       # The result depends on both the start and end values according to
#       # locale-specific range plural rules.
#       #
#       # @param start_value [Integer, Float] the start of the range
#       # @param end_value [Integer, Float] the end of the range
#       # @return [Symbol] one of `:zero`, `:one`, `:two`, `:few`, `:many`, or `:other`
#       #
#       # @example
#       #   rules.select_range(1, 5)   #=> :other (in English, "1-5 items")
#       #   rules.select_range(0, 1)   #=> :other (in English)
#       #
#       # @example Russian plural ranges
#       #   ru_rules = ICU4X::PluralRules.new(ICU4X::Locale.parse("ru"), provider: provider)
#       #   ru_rules.select_range(1, 2)  #=> :few
#       #   ru_rules.select_range(1, 5)  #=> :many
#       #
#       def select_range(start_value, end_value); end
#
#       # Returns all plural categories available for this locale.
#       #
#       # @return [Array<Symbol>] array of category symbols
#       #
#       # @example
#       #   rules.categories  #=> [:one, :other]
#       #
#       def categories; end
#
#       # Returns the resolved options for this instance.
#       #
#       # @return [Hash] options hash with keys:
#       #   - `:locale` [String] the resolved locale identifier
#       #   - `:type` [Symbol] the plural rule type (`:cardinal` or `:ordinal`)
#       #
#       def resolved_options; end
#     end
#
#     # Formats numbers according to locale-specific conventions.
#     #
#     # NumberFormat supports decimal, percent, and currency formatting
#     # with configurable grouping, fraction digits, and rounding.
#     #
#     # @example Decimal formatting
#     #   formatter = ICU4X::NumberFormat.new(locale)
#     #   formatter.format(1234.56)  #=> "1,234.56" (in en-US)
#     #
#     # @example Currency formatting
#     #   formatter = ICU4X::NumberFormat.new(locale, style: :currency, currency: "JPY")
#     #   formatter.format(1234)  #=> "¥1,234" (in ja-JP)
#     #
#     # @example Percent formatting
#     #   formatter = ICU4X::NumberFormat.new(locale, style: :percent)
#     #   formatter.format(0.42)  #=> "42%"
#     #
#     # @example Han decimal numerals via locale extension
#     #   locale = ICU4X::Locale.parse("ja-JP-u-nu-hanidec")
#     #   formatter = ICU4X::NumberFormat.new(locale, provider: provider)
#     #   formatter.format(1234)  #=> "一,二三四"
#     #
#     class NumberFormat
#       # Creates a new NumberFormat instance.
#       #
#       # @param locale [Locale] the locale for formatting
#       # @param provider [DataProvider, nil] data provider (uses default if nil)
#       # @param style [Symbol] format style: `:decimal`, `:percent`, or `:currency`
#       # @param currency [String, nil] ISO 4217 currency code (required for `:currency` style)
#       # @param use_grouping [Boolean] whether to use grouping separators
#       # @param minimum_integer_digits [Integer, nil] minimum number of integer digits
#       # @param minimum_fraction_digits [Integer, nil] minimum number of fraction digits
#       # @param maximum_fraction_digits [Integer, nil] maximum number of fraction digits
#       # @param rounding_mode [Symbol, nil] rounding mode for excess digits
#       # @return [NumberFormat] a new instance
#       # @raise [DataError] if data for the locale is unavailable
#       #
#       # @example
#       #   formatter = ICU4X::NumberFormat.new(locale, minimum_fraction_digits: 2)
#       #
#       def initialize(locale, provider: nil, style: :decimal, currency: nil,
#                      use_grouping: true, minimum_integer_digits: nil,
#                      minimum_fraction_digits: nil, maximum_fraction_digits: nil,
#                      rounding_mode: nil); end
#
#       # Formats a number according to the configured options.
#       #
#       # @param number [Integer, Float, BigDecimal] the number to format
#       # @return [String] the formatted number string
#       #
#       # @example
#       #   formatter.format(1234567.89)  #=> "1,234,567.89"
#       #
#       def format(number); end
#
#       # Formats a number and returns an array of parts.
#       #
#       # Each part contains a type and value, allowing for custom styling
#       # or processing of individual components.
#       #
#       # @param number [Integer, Float, BigDecimal] the number to format
#       # @return [Array<FormattedPart>] array of formatted parts
#       #
#       # @note For `style: :percent` and `style: :currency`, the current ICU4X
#       #   experimental formatters do not provide part annotations. These styles
#       #   return a single `:literal` part containing the entire formatted string.
#       #
#       # @example
#       #   parts = formatter.format_to_parts(-1234.56)
#       #   # => [
#       #   #   #<ICU4X::FormattedPart type=:minus_sign value="-">,
#       #   #   #<ICU4X::FormattedPart type=:integer value="1,234">,
#       #   #   #<ICU4X::FormattedPart type=:decimal value=".">,
#       #   #   #<ICU4X::FormattedPart type=:fraction value="56">
#       #   # ]
#       #
#       # @example Reconstruct the formatted string
#       #   parts.map(&:value).join  #=> "-1,234.56"
#       #
#       def format_to_parts(number); end
#
#       # Returns the resolved options for this instance.
#       #
#       # @return [Hash] options hash with keys:
#       #   - `:locale` [String] the resolved locale identifier
#       #   - `:style` [Symbol] the format style
#       #   - `:use_grouping` [Boolean] whether grouping is enabled
#       #   - `:currency` [String] currency code (if applicable)
#       #   - `:minimum_integer_digits` [Integer] minimum integer digits
#       #   - `:minimum_fraction_digits` [Integer] minimum fraction digits
#       #   - `:maximum_fraction_digits` [Integer] maximum fraction digits
#       #   - `:rounding_mode` [Symbol] the rounding mode
#       #
#       def resolved_options; end
#     end
#
#     # Formats dates and times according to locale-specific conventions.
#     #
#     # DateTimeFormat supports various date and time styles and calendar systems.
#     # You can use either style options (date_style, time_style) or component options
#     # (year, month, day, weekday, hour, minute, second), but not both.
#     #
#     # @example Format a date with style
#     #   formatter = ICU4X::DateTimeFormat.new(locale, date_style: :long)
#     #   formatter.format(Time.now)  #=> "January 1, 2026"
#     #
#     # @example Format date and time with styles
#     #   formatter = ICU4X::DateTimeFormat.new(locale, date_style: :short, time_style: :short)
#     #   formatter.format(Time.now)  #=> "1/1/26, 12:00 PM"
#     #
#     # @example Format with component options
#     #   formatter = ICU4X::DateTimeFormat.new(locale, year: :numeric, month: :numeric, day: :numeric)
#     #   formatter.format(Time.now)  #=> "Dec 28, 2025"
#     #
#     # @example Use Japanese calendar
#     #   formatter = ICU4X::DateTimeFormat.new(locale, date_style: :long, calendar: :japanese)
#     #   formatter.format(Time.now)  #=> "令和8年1月1日"
#     #
#     # @example Han decimal numerals via locale extension
#     #   locale = ICU4X::Locale.parse("ja-JP-u-nu-hanidec")
#     #   formatter = ICU4X::DateTimeFormat.new(locale, provider: provider, date_style: :long)
#     #   formatter.format(Time.utc(2025, 12, 28))  #=> "二〇二五年一二月二八日"
#     #
#     class DateTimeFormat
#       # Creates a new DateTimeFormat instance.
#       #
#       # You must specify either style options (date_style/time_style) or component options
#       # (year, month, day, weekday, hour, minute, second). These are mutually exclusive.
#       #
#       # @param locale [Locale] the locale for formatting
#       # @param provider [DataProvider, nil] data provider (uses default if nil)
#       # @param date_style [Symbol, nil] date format style: `:full`, `:long`, `:medium`, or `:short`
#       # @param time_style [Symbol, nil] time format style: `:full`, `:long`, `:medium`, or `:short`
#       # @param year [Symbol, nil] year component: `:numeric` or `:two_digit`
#       # @param month [Symbol, nil] month component: `:numeric`, `:two_digit`, `:long`, `:short`, or `:narrow`
#       # @param day [Symbol, nil] day component: `:numeric` or `:two_digit`
#       # @param weekday [Symbol, nil] weekday component: `:long`, `:short`, or `:narrow`
#       # @param hour [Symbol, nil] hour component: `:numeric` or `:two_digit`
#       # @param minute [Symbol, nil] minute component: `:numeric` or `:two_digit`
#       # @param second [Symbol, nil] second component: `:numeric` or `:two_digit`
#       # @param time_zone [String, nil] IANA time zone identifier (e.g., "America/New_York")
#       # @param calendar [Symbol] calendar system to use
#       # @param hour_cycle [Symbol, nil] hour cycle: `:h11` (0-11), `:h12` (1-12), or `:h23` (0-23)
#       # @param hour12 [Boolean, nil] `true` for 12-hour format, `false` for 24-hour format
#       # @return [DateTimeFormat] a new instance
#       # @raise [ArgumentError] if both style and component options are specified
#       # @raise [DataError] if data for the locale is unavailable
#       #
#       # @example With style options
#       #   formatter = ICU4X::DateTimeFormat.new(locale, date_style: :long, time_style: :short)
#       #
#       # @example With component options
#       #   formatter = ICU4X::DateTimeFormat.new(locale, year: :numeric, month: :long, day: :numeric)
#       #
#       # @example With 24-hour format using hour_cycle
#       #   formatter = ICU4X::DateTimeFormat.new(locale, time_style: :short, hour_cycle: :h23)
#       #   formatter.format(Time.utc(2025, 1, 1, 0, 30))  #=> "00:30:00"
#       #
#       # @example With 12-hour format using hour12
#       #   formatter = ICU4X::DateTimeFormat.new(locale, time_style: :short, hour12: true)
#       #   formatter.format(Time.utc(2025, 1, 1, 14, 30))  #=> "2:30:00 PM"
#       #
#       def initialize(locale, provider: nil, date_style: nil, time_style: nil,
#                      year: nil, month: nil, day: nil, weekday: nil,
#                      hour: nil, minute: nil, second: nil,
#                      time_zone: nil, calendar: :gregory, hour_cycle: nil, hour12: nil); end
#
#       # Formats a time value according to the configured options.
#       #
#       # @param time [Time, #to_time] the time to format (or any object responding to #to_time)
#       # @return [String] the formatted date/time string
#       #
#       def format(time); end
#
#       # Formats a time value and returns an array of parts.
#       #
#       # Each part contains a type and value, allowing for custom styling
#       # or processing of individual components.
#       #
#       # @param time [Time, #to_time] the time to format (or any object responding to #to_time)
#       # @return [Array<FormattedPart>] array of formatted parts
#       #
#       # @example
#       #   parts = formatter.format_to_parts(Time.utc(2025, 1, 31))
#       #   # => [
#       #   #   #<ICU4X::FormattedPart type=:month value="January">,
#       #   #   #<ICU4X::FormattedPart type=:literal value=" ">,
#       #   #   #<ICU4X::FormattedPart type=:day value="31">,
#       #   #   #<ICU4X::FormattedPart type=:literal value=", ">,
#       #   #   #<ICU4X::FormattedPart type=:year value="2025">
#       #   # ]
#       #
#       # @example Reconstruct the formatted string
#       #   parts.map(&:value).join  #=> "January 31, 2025"
#       #
#       # @example Japanese calendar with era
#       #   formatter = ICU4X::DateTimeFormat.new(locale, date_style: :long, calendar: :japanese)
#       #   parts = formatter.format_to_parts(Time.utc(2025, 1, 31))
#       #   era_part = parts.find { |p| p.type == :era }
#       #   era_part.value  #=> "令和"
#       #
#       def format_to_parts(time); end
#
#       # Returns the resolved options for this instance.
#       #
#       # @return [Hash] options hash with keys:
#       #   - `:locale` [String] the resolved locale identifier
#       #   - `:calendar` [Symbol] the calendar system
#       #   - `:date_style` [Symbol] the date style (if style options used)
#       #   - `:time_style` [Symbol] the time style (if style options used)
#       #   - `:year` [Symbol] the year component (if component options used)
#       #   - `:month` [Symbol] the month component (if component options used)
#       #   - `:day` [Symbol] the day component (if component options used)
#       #   - `:weekday` [Symbol] the weekday component (if component options used)
#       #   - `:hour` [Symbol] the hour component (if component options used)
#       #   - `:minute` [Symbol] the minute component (if component options used)
#       #   - `:second` [Symbol] the second component (if component options used)
#       #   - `:time_zone` [String] the time zone (if set)
#       #   - `:hour_cycle` [Symbol] the hour cycle (if set)
#       #
#       def resolved_options; end
#     end
#
#     # Formats relative time expressions (e.g., "3 days ago", "in 2 hours").
#     #
#     # @example
#     #   formatter = ICU4X::RelativeTimeFormat.new(locale)
#     #   formatter.format(-1, :day)   #=> "1 day ago"
#     #   formatter.format(2, :hour)   #=> "in 2 hours"
#     #
#     # @example With auto numeric
#     #   formatter = ICU4X::RelativeTimeFormat.new(locale, numeric: :auto)
#     #   formatter.format(-1, :day)   #=> "yesterday"
#     #   formatter.format(0, :day)    #=> "today"
#     #
#     # @example Han decimal numerals via locale extension
#     #   locale = ICU4X::Locale.parse("ja-u-nu-hanidec")
#     #   formatter = ICU4X::RelativeTimeFormat.new(locale, provider: provider)
#     #   formatter.format(-3, :day)  #=> "三 日前"
#     #
#     class RelativeTimeFormat
#       # Creates a new RelativeTimeFormat instance.
#       #
#       # @param locale [Locale] the locale for formatting
#       # @param provider [DataProvider, nil] data provider (uses default if nil)
#       # @param style [Symbol] format style: `:long`, `:short`, or `:narrow`
#       # @param numeric [Symbol] numeric display: `:always` or `:auto`
#       # @return [RelativeTimeFormat] a new instance
#       # @raise [DataError] if data for the locale is unavailable
#       #
#       def initialize(locale, provider: nil, style: :long, numeric: :always); end
#
#       # Formats a relative time value.
#       #
#       # @param value [Integer] the relative time value (negative for past, positive for future)
#       # @param unit [Symbol] time unit: `:second`, `:minute`, `:hour`, `:day`,
#       #   `:week`, `:month`, `:quarter`, or `:year`
#       # @return [String] the formatted relative time string
#       #
#       # @example
#       #   formatter.format(-3, :day)    #=> "3 days ago"
#       #   formatter.format(1, :week)    #=> "in 1 week"
#       #
#       def format(value, unit); end
#
#       # Formats a relative time value and returns an array of parts.
#       #
#       # @param value [Integer] the relative time value (negative for past, positive for future)
#       # @param unit [Symbol] time unit: `:second`, `:minute`, `:hour`, `:day`,
#       #   `:week`, `:month`, `:quarter`, or `:year`
#       # @return [Array<FormattedPart>] array of formatted parts
#       #
#       # @note The current ICU4X experimental RelativeTimeFormatter does not
#       #   provide separate part annotations for the numeric value. The entire
#       #   formatted string is returned as a single `:literal` part.
#       #
#       # @example
#       #   parts = formatter.format_to_parts(-3, :day)
#       #   # => [#<ICU4X::FormattedPart type=:literal value="3 days ago">]
#       #
#       # @example Reconstruct the formatted string
#       #   parts.map(&:value).join  #=> "3 days ago"
#       #
#       def format_to_parts(value, unit); end
#
#       # Returns the resolved options for this instance.
#       #
#       # @return [Hash] options hash with keys:
#       #   - `:locale` [String] the resolved locale identifier
#       #   - `:style` [Symbol] the format style
#       #   - `:numeric` [Symbol] the numeric display mode
#       #
#       def resolved_options; end
#     end
#
#     # Formats lists of items according to locale-specific conventions.
#     #
#     # @example Conjunction (and)
#     #   formatter = ICU4X::ListFormat.new(locale, type: :conjunction)
#     #   formatter.format(["A", "B", "C"])  #=> "A, B, and C"
#     #
#     # @example Disjunction (or)
#     #   formatter = ICU4X::ListFormat.new(locale, type: :disjunction)
#     #   formatter.format(["A", "B", "C"])  #=> "A, B, or C"
#     #
#     # @example Unit list
#     #   formatter = ICU4X::ListFormat.new(locale, type: :unit)
#     #   formatter.format(["5 lb", "12 oz"])  #=> "5 lb, 12 oz"
#     #
#     class ListFormat
#       # Creates a new ListFormat instance.
#       #
#       # @param locale [Locale] the locale for formatting
#       # @param provider [DataProvider, nil] data provider (uses default if nil)
#       # @param type [Symbol] list type: `:conjunction`, `:disjunction`, or `:unit`
#       # @param style [Symbol] format style: `:long`, `:short`, or `:narrow`
#       # @return [ListFormat] a new instance
#       # @raise [DataError] if data for the locale is unavailable
#       #
#       def initialize(locale, provider: nil, type: :conjunction, style: :long); end
#
#       # Formats a list of strings.
#       #
#       # @param list [Array<String>] the list items to format
#       # @return [String] the formatted list string
#       #
#       def format(list); end
#
#       # Formats a list of strings and returns an array of parts.
#       #
#       # Each part contains a type and value, allowing for custom styling
#       # or processing of individual components.
#       #
#       # @param list [Array<String>] the list items to format
#       # @return [Array<FormattedPart>] array of formatted parts
#       #
#       # @example
#       #   parts = formatter.format_to_parts(["Apple", "Banana", "Cherry"])
#       #   # => [
#       #   #   #<ICU4X::FormattedPart type=:element value="Apple">,
#       #   #   #<ICU4X::FormattedPart type=:literal value=", ">,
#       #   #   #<ICU4X::FormattedPart type=:element value="Banana">,
#       #   #   #<ICU4X::FormattedPart type=:literal value=", and ">,
#       #   #   #<ICU4X::FormattedPart type=:element value="Cherry">
#       #   # ]
#       #
#       # @example Reconstruct the formatted string
#       #   parts.map(&:value).join  #=> "Apple, Banana, and Cherry"
#       #
#       def format_to_parts(list); end
#
#       # Returns the resolved options for this instance.
#       #
#       # @return [Hash] options hash with keys:
#       #   - `:locale` [String] the resolved locale identifier
#       #   - `:type` [Symbol] the list type
#       #   - `:style` [Symbol] the format style
#       #
#       def resolved_options; end
#     end
#
#     # Compares strings according to locale-specific collation rules.
#     #
#     # Collator provides locale-aware string comparison for sorting and searching.
#     #
#     # @example Basic comparison
#     #   collator = ICU4X::Collator.new(locale)
#     #   collator.compare("a", "b")  #=> -1
#     #   collator.compare("b", "a")  #=> 1
#     #   collator.compare("a", "a")  #=> 0
#     #
#     # @example Sorting with collator
#     #   collator = ICU4X::Collator.new(locale)
#     #   words.sort { |a, b| collator.compare(a, b) }
#     #
#     # @example Numeric sorting
#     #   collator = ICU4X::Collator.new(locale, numeric: true)
#     #   collator.compare("file2", "file10")  #=> -1  (2 < 10)
#     #
#     class Collator
#       # Creates a new Collator instance.
#       #
#       # @param locale [Locale] the locale for collation rules
#       # @param provider [DataProvider, nil] data provider (uses default if nil)
#       # @param sensitivity [Symbol] comparison sensitivity:
#       #   `:base`, `:accent`, `:case`, or `:variant`
#       # @param numeric [Boolean] whether to compare numeric strings as numbers
#       # @param case_first [Symbol, nil] which case to sort first: `:upper` or `:lower`
#       # @return [Collator] a new instance
#       # @raise [DataError] if data for the locale is unavailable
#       #
#       def initialize(locale, provider: nil, sensitivity: :variant,
#                      numeric: false, case_first: nil); end
#
#       # Compares two strings.
#       #
#       # @param a [String] first string
#       # @param b [String] second string
#       # @return [Integer] -1 if a < b, 0 if a == b, 1 if a > b
#       #
#       def compare(a, b); end
#
#       # Returns the resolved options for this instance.
#       #
#       # @return [Hash] options hash with keys:
#       #   - `:locale` [String] the resolved locale identifier
#       #   - `:sensitivity` [Symbol] the comparison sensitivity
#       #   - `:numeric` [Boolean] whether numeric sorting is enabled
#       #   - `:case_first` [Symbol] which case sorts first (if set)
#       #
#       def resolved_options; end
#     end
#
#     # Provides localized display names for languages, regions, and scripts.
#     #
#     # @example Language names
#     #   names = ICU4X::DisplayNames.new(locale, type: :language)
#     #   names.of("ja")  #=> "Japanese"
#     #   names.of("en")  #=> "English"
#     #
#     # @example Region names
#     #   names = ICU4X::DisplayNames.new(locale, type: :region)
#     #   names.of("JP")  #=> "Japan"
#     #   names.of("US")  #=> "United States"
#     #
#     class DisplayNames
#       # Creates a new DisplayNames instance.
#       #
#       # @param locale [Locale] the locale for display names
#       # @param provider [DataProvider, nil] data provider (uses default if nil)
#       # @param type [Symbol] display name type: `:language`, `:region`, `:script`, or `:locale`
#       # @param style [Symbol] display style: `:long`, `:short`, or `:narrow`
#       # @param fallback [Symbol] fallback behavior: `:code` or `:none`
#       # @return [DisplayNames] a new instance
#       # @raise [DataError] if data for the locale is unavailable
#       #
#       def initialize(locale, provider: nil, type:, style: :long, fallback: :code); end
#
#       # Returns the display name for a code.
#       #
#       # @param code [String] the code to look up (language, region, script, or locale)
#       # @return [String, nil] the localized display name, or nil if not found
#       #   (when fallback is `:none`)
#       #
#       # @example
#       #   names.of("ja")  #=> "Japanese"
#       #   names.of("XX")  #=> "XX" (with fallback: :code)
#       #   names.of("XX")  #=> nil (with fallback: :none)
#       #
#       def of(code); end
#
#       # Returns the resolved options for this instance.
#       #
#       # @return [Hash] options hash with keys:
#       #   - `:locale` [String] the resolved locale identifier
#       #   - `:type` [Symbol] the display name type
#       #   - `:style` [Symbol] the display style
#       #   - `:fallback` [Symbol] the fallback behavior
#       #
#       def resolved_options; end
#     end
#
#     # Segments text into graphemes, words, sentences, or lines.
#     #
#     # Segmenter provides Unicode-compliant text segmentation according to
#     # UAX #29 (Text Segmentation) and UAX #14 (Line Breaking).
#     #
#     # @example Word segmentation
#     #   segmenter = ICU4X::Segmenter.new(granularity: :word)
#     #   segments = segmenter.segment("Hello, world!")
#     #   segments.map(&:segment)  #=> ["Hello", ",", " ", "world", "!"]
#     #
#     # @example Grapheme segmentation
#     #   segmenter = ICU4X::Segmenter.new(granularity: :grapheme)
#     #   segments = segmenter.segment("👨‍👩‍👧")
#     #   segments.size  #=> 1 (family emoji is one grapheme)
#     #
#     class Segmenter
#       # Represents a segment of text.
#       #
#       class Segment
#         # @return [String] the segment text
#         attr_reader :segment
#
#         # @return [Integer] the byte index of this segment in the original string
#         attr_reader :index
#
#         # Returns whether this segment is word-like.
#         #
#         # Only meaningful for word segmentation; returns nil for other granularities.
#         #
#         # @return [Boolean, nil] true if the segment is a word (not punctuation/whitespace),
#         #   nil for non-word segmentation
#         #
#         def word_like?; end
#       end
#
#       # Creates a new Segmenter instance.
#       #
#       # @param granularity [Symbol] segmentation granularity:
#       #   `:grapheme`, `:word`, `:sentence`, or `:line`
#       # @param provider [DataProvider, nil] data provider (uses default if nil)
#       # @return [Segmenter] a new instance
#       # @raise [DataError] if data is unavailable
#       #
#       # @example
#       #   segmenter = ICU4X::Segmenter.new(granularity: :word)
#       #   segmenter = ICU4X::Segmenter.new(granularity: :sentence)
#       #
#       def initialize(granularity:, provider: nil); end
#
#       # Segments text into an array of segments.
#       #
#       # @param text [String] the text to segment
#       # @return [Array<Segment>] array of segment objects
#       #
#       # @example
#       #   segments = segmenter.segment("Hello world")
#       #   segments.each do |seg|
#       #     puts "#{seg.index}: #{seg.segment.inspect}"
#       #   end
#       #
#       def segment(text); end
#
#       # Returns the resolved options for this instance.
#       #
#       # @return [Hash] options hash with keys:
#       #   - `:granularity` [Symbol] the segmentation granularity
#       #
#       def resolved_options; end
#     end
#   end
