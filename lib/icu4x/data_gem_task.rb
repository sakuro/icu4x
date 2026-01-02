# frozen_string_literal: true

require "erb"
require "fileutils"
require "pathname"
require "rake"
require "rake/tasklib"
require "rubygems"
require "rubygems/package"

module ICU4X
  # Rake task for generating ICU4X data companion gems.
  #
  # @example Basic usage
  #   require "icu4x/data_gem_task"
  #
  #   ICU4X::DataGemTask.new
  #
  # This creates the following tasks:
  # - +icu4x:data_gems:build+ - Build all data gems
  # - +icu4x:data_gems:build:full+ - Build icu4x-data-full gem
  # - +icu4x:data_gems:build:recommended+ - Build icu4x-data-recommended gem
  # - +icu4x:data_gems:build:modern+ - Build icu4x-data-modern gem
  # - +icu4x:data_gems:build:basic+ - Build icu4x-data-basic gem
  # - +icu4x:data_gems:clean+ - Clean data gem build artifacts
  class DataGemTask < ::Rake::TaskLib
    VARIANTS = {
      full: {locales: :full, description: "All CLDR locales (700+)"},
      recommended: {locales: :recommended, description: "Recommended locales (164)"},
      modern: {locales: :modern, description: "Modern coverage locales (103)"},
      basic: {locales: :basic, description: "Basic coverage locales (66)"}
    }.freeze
    public_constant :VARIANTS

    TEMPLATE_DIR = Pathname(__dir__).join("../../templates/data_gem")
    public_constant :TEMPLATE_DIR

    VERSION_FILE = Pathname(__dir__).join("version.rb")
    private_constant :VERSION_FILE

    def initialize
      super
      define_tasks
    end

    private def define_tasks
      namespace "icu4x:data_gems" do
        desc "Build all data gems"
        task build: VARIANTS.keys.map {|v| "build:#{v}" }

        VARIANTS.each do |variant, config|
          desc "Build icu4x-data-#{variant} gem"
          task "build:#{variant}" => :compile do
            build_gem(variant, config)
          end
        end

        desc "Clean data gem build artifacts"
        task :clean do
          VARIANTS.each_key {|v| FileUtils.rm_rf(tmp_dir(v)) }
        end
      end
    end

    private def build_gem(variant, config)
      gem_dir = prepare_gem_structure(variant, config)
      generate_data_blob(gem_dir, variant, config[:locales])
      package_gem(gem_dir, variant)
    end

    private def prepare_gem_structure(variant, config)
      gem_dir = tmp_dir(variant)
      FileUtils.rm_rf(gem_dir)
      gem_dir.mkpath

      # Copy version.rb for gemspec
      lib_icu4x_dir = gem_dir / "lib" / "icu4x"
      lib_icu4x_dir.mkpath
      FileUtils.cp(VERSION_FILE, lib_icu4x_dir / "version.rb")

      # Render templates
      render_template(
        "gemspec.erb",
        gem_dir / "icu4x-data-#{variant}.gemspec",
        variant:,
        config:
      )
      render_template(
        "README.md.erb",
        gem_dir / "README.md",
        variant:,
        config:
      )

      lib_data_dir = gem_dir / "lib" / "icu4x" / "data"
      lib_data_dir.mkpath
      render_template(
        "lib/icu4x/data/variant.rb.erb",
        lib_data_dir / "#{variant}.rb",
        variant:
      )

      # Copy LICENSE
      FileUtils.cp("LICENSE.txt", gem_dir / "LICENSE.txt")

      gem_dir
    end

    private def generate_data_blob(gem_dir, variant, locales)
      data_dir = gem_dir / "data"
      data_dir.mkpath

      require "icu4x"
      ICU4X::DataGenerator.export(
        locales:,
        markers: :all,
        format: :blob,
        output: data_dir / "#{variant}.postcard"
      )
    end

    private def package_gem(gem_dir, variant)
      Dir.chdir(gem_dir) do
        spec = Gem::Specification.load("icu4x-data-#{variant}.gemspec")
        gem_file = Gem::Package.build(spec)
        pkg_dir = Pathname("../../pkg")
        pkg_dir.mkpath
        FileUtils.mv(gem_file, pkg_dir / gem_file)
      end
    end

    private def render_template(template_name, output_path, **locals)
      template = ERB.new(TEMPLATE_DIR.join(template_name).read, trim_mode: "-")
      binding_with_locals = binding
      locals.each {|k, v| binding_with_locals.local_variable_set(k, v) }
      output_path.write(template.result(binding_with_locals))
    end

    private def tmp_dir(variant) = Pathname("tmp/icu4x-data-#{variant}")
  end
end
