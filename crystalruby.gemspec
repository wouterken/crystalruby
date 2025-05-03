# frozen_string_literal: true

require_relative "lib/crystalruby/version"

Gem::Specification.new do |spec|
  spec.name = "crystalruby"
  spec.version = CrystalRuby::VERSION
  spec.authors = ["Wouter Coppieters"]
  spec.email = ["wc@pico.net.nz"]

  spec.summary = "Embed Crystal code directly in Ruby."
  spec.description = "Embed Crystal code directly in Ruby."
  spec.homepage = "https://github.com/wouterken/crystalruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"
  spec.add_dependency "digest"
  spec.add_dependency "ffi"
  spec.add_dependency "fileutils", "~> 1.7"
  spec.add_dependency "prism", ">= 1.3.0", "< 1.5.0"
  spec.add_dependency "logger"
  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
