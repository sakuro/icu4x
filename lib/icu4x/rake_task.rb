# frozen_string_literal: true

require "rake"
require "rake/clean"
require "rake/tasklib"

module ICU4X
  # Rake task for generating ICU4X data blobs.
  #
  # @example Basic usage
  #   require "icu4x/rake_task"
  #
  #   ICU4X::RakeTask.new do |t|
  #     t.output = "data/icu4x.postcard"
  #   end
  #
  # @example Custom task name and locales
  #   ICU4X::RakeTask.new("myapp:generate_data") do |t|
  #     t.locales = %w[en ja de]
  #     t.output = "data/icu4x.postcard"
  #   end
  class RakeTask < ::Rake::TaskLib
    # @return [String] The name of the task
    attr_reader :name

    # @return [Symbol, Array<String>] Locale specifier or array of locale strings
    #   Defaults to `:recommended`
    attr_accessor :locales

    # @return [Symbol, Array<String>] Data markers to include
    #   Defaults to `:all`
    attr_accessor :markers

    # @return [Pathname, String] Output path relative to Rakefile
    attr_accessor :output

    # Creates a new RakeTask.
    #
    # @param name [String] Task name (default: "icu4x:data:generate")
    # @yield [self] Configuration block
    # @yieldparam task [RakeTask] The task instance for configuration
    def initialize(name="icu4x:data:generate")
      super()
      @name = name
      @locales = :recommended
      @markers = :all
      @output = nil

      yield self if block_given?

      raise ArgumentError, "output is required" if @output.nil?

      define_tasks
    end

    private def define_tasks
      output_path = Pathname(@output)

      desc "Generate ICU4X data blob"
      file output_path.to_s do
        require "icu4x"
        output_path.dirname.mkpath
        ICU4X::DataGenerator.export(
          locales: @locales,
          markers: @markers,
          format: :blob,
          output: output_path
        )
      end

      desc "Generate ICU4X data blob"
      task @name => output_path.to_s

      CLOBBER.include(output_path.to_s)
    end
  end
end
