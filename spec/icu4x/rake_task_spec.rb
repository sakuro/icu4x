# frozen_string_literal: true

require "icu4x/rake_task"
require "pathname"
require "tmpdir"

RSpec.describe ICU4X::RakeTask do
  let(:output_dir) { Pathname.new(Dir.mktmpdir) }
  let(:output_path) { output_dir / "test-data.postcard" }

  before do
    Rake.application = Rake::Application.new
    CLOBBER.clear
  end

  after do
    FileUtils.rm_rf(output_dir)
  end

  describe "#initialize" do
    it "creates a task with default name" do
      ICU4X::RakeTask.new {|t| t.output = output_path }

      expect(Rake::Task.task_defined?("icu4x:data:generate")).to be true
    end

    it "creates a task with custom name" do
      ICU4X::RakeTask.new("custom:generate") {|t| t.output = output_path }

      expect(Rake::Task.task_defined?("custom:generate")).to be true
    end

    it "raises ArgumentError when output is not specified" do
      expect { ICU4X::RakeTask.new }.to raise_error(ArgumentError, /output is required/)
    end

    it "has default locales of :recommended" do
      task = ICU4X::RakeTask.new {|t| t.output = output_path }

      expect(task.locales).to eq(:recommended)
    end

    it "has default markers of :all" do
      task = ICU4X::RakeTask.new {|t| t.output = output_path }

      expect(task.markers).to eq(:all)
    end

    it "allows custom locales" do
      task = ICU4X::RakeTask.new do |t|
        t.locales = %w[en ja]
        t.output = output_path
      end

      expect(task.locales).to eq(%w[en ja])
    end

    it "allows custom markers" do
      task = ICU4X::RakeTask.new do |t|
        t.markers = %w[PluralsCardinalV1]
        t.output = output_path
      end

      expect(task.markers).to eq(%w[PluralsCardinalV1])
    end
  end

  describe "file task" do
    it "creates output file when invoked", :slow do
      ICU4X::RakeTask.new do |t|
        t.locales = %w[en]
        t.markers = %w[PluralsCardinalV1]
        t.output = output_path
      end

      Rake::Task["icu4x:data:generate"].invoke

      expect(output_path).to exist
      expect(output_path.size).to be > 0
    end

    it "creates parent directories if needed", :slow do
      nested_path = output_dir / "nested" / "dir" / "data.postcard"

      ICU4X::RakeTask.new do |t|
        t.locales = %w[en]
        t.markers = %w[PluralsCardinalV1]
        t.output = nested_path
      end

      Rake::Task["icu4x:data:generate"].invoke

      expect(nested_path).to exist
    end

    it "skips generation if file already exists", :slow do
      ICU4X::RakeTask.new do |t|
        t.locales = %w[en]
        t.markers = %w[PluralsCardinalV1]
        t.output = output_path
      end

      Rake::Task["icu4x:data:generate"].invoke
      original_mtime = output_path.mtime

      sleep 0.1
      Rake::Task["icu4x:data:generate"].reenable
      Rake::Task[output_path.to_s].reenable
      Rake::Task["icu4x:data:generate"].invoke

      expect(output_path.mtime).to eq(original_mtime)
    end
  end

  describe "CLOBBER" do
    it "includes output path in CLOBBER" do
      ICU4X::RakeTask.new {|t| t.output = output_path }

      expect(CLOBBER).to include(output_path.to_s)
    end
  end
end
