# frozen_string_literal: true

require "icu4x/data_gem_task"
require "pathname"
require "tmpdir"

RSpec.describe ICU4X::DataGemTask do
  before do
    Rake.application = Rake::Application.new
  end

  describe "#initialize" do
    it "creates build tasks for all variants" do
      ICU4X::DataGemTask.new

      expect(Rake::Task.task_defined?("icu4x:data_gems:build")).to be true
      expect(Rake::Task.task_defined?("icu4x:data_gems:build:full")).to be true
      expect(Rake::Task.task_defined?("icu4x:data_gems:build:recommended")).to be true
      expect(Rake::Task.task_defined?("icu4x:data_gems:build:modern")).to be true
    end

    it "creates clean task" do
      ICU4X::DataGemTask.new

      expect(Rake::Task.task_defined?("icu4x:data_gems:clean")).to be true
    end
  end

  describe "VARIANTS" do
    it "defines all three variants" do
      expect(ICU4X::DataGemTask::VARIANTS.keys).to contain_exactly(:full, :recommended, :modern)
    end

    it "has locales and description for each variant" do
      ICU4X::DataGemTask::VARIANTS.each do |variant, config|
        expect(config).to have_key(:locales), "#{variant} should have :locales"
        expect(config).to have_key(:description), "#{variant} should have :description"
      end
    end
  end

  describe "TEMPLATE_DIR" do
    it "points to templates directory" do
      expect(ICU4X::DataGemTask::TEMPLATE_DIR.basename.to_s).to eq("data_gem")
    end

    it "contains required templates" do
      template_dir = ICU4X::DataGemTask::TEMPLATE_DIR

      expect(template_dir / "gemspec.erb").to exist
      expect(template_dir / "README.md.erb").to exist
      expect(template_dir / "lib/icu4x/data/variant.rb.erb").to exist
    end
  end

  describe "build task", :slow do
    let(:pkg_dir) { Pathname("pkg") }
    let(:tmp_dir) { Pathname("tmp/icu4x-data-modern") }

    before do
      # Define a dummy compile task since native extension is already loaded
      Rake::Task.define_task(:compile)
      ICU4X::DataGemTask.new
      FileUtils.rm_rf(tmp_dir)
      FileUtils.rm_f(pkg_dir / "icu4x-data-modern-#{ICU4X::VERSION}.gem")
    end

    after do
      FileUtils.rm_rf(tmp_dir)
      FileUtils.rm_f(pkg_dir / "icu4x-data-modern-#{ICU4X::VERSION}.gem")
    end

    it "generates gem file in pkg directory" do
      Rake::Task["icu4x:data_gems:build:modern"].invoke

      gem_file = pkg_dir / "icu4x-data-modern-#{ICU4X::VERSION}.gem"
      expect(gem_file).to exist
    end

    it "includes required files in gem" do
      Rake::Task["icu4x:data_gems:build:modern"].invoke

      gem_file = pkg_dir / "icu4x-data-modern-#{ICU4X::VERSION}.gem"
      output = %x(gem spec #{gem_file} files)
      gem_contents = output.lines.filter_map {|l|
        stripped = l.strip.delete_prefix("- ")
        stripped unless stripped.empty?
      }

      expect(gem_contents).to include("lib/icu4x/data/modern.rb")
      expect(gem_contents).to include("data/modern.postcard")
      expect(gem_contents).to include("LICENSE.txt")
      expect(gem_contents).to include("README.md")
    end
  end

  describe "clean task" do
    let(:tmp_dirs) { ICU4X::DataGemTask::VARIANTS.keys.map {|v| Pathname("tmp/icu4x-data-#{v}") } }

    before do
      ICU4X::DataGemTask.new
      tmp_dirs.each(&:mkpath)
    end

    after do
      tmp_dirs.each {|d| FileUtils.rm_rf(d) }
    end

    it "removes all tmp directories" do
      expect(tmp_dirs).to all(exist)

      Rake::Task["icu4x:data_gems:clean"].invoke

      tmp_dirs.each {|d| expect(d).not_to exist }
    end
  end
end
