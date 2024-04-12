require "open3"
require "tmpdir"

module CrystalRuby
  module Compilation
    def self.compile!(
      src: config.crystal_src_dir_abs / config.crystal_main_file,
      lib: config.crystal_lib_dir_abs / config.crystal_lib_name,
      verbose: config.verbose,
      debug: config.debug
    )
      Dir.chdir(config.crystal_src_dir_abs) do
        compile_command = compile_command!(verbose: verbose, debug: debug, lib: lib, src: src)
        link_command = link_cmd!(verbose: verbose, lib: lib, src: src)

        puts "[crystalruby] Compiling Crystal code: #{compile_command}" if verbose
        unless system(compile_command)
          puts "Failed to build Crystal object file."
          return false
        end

        puts "[crystalruby] Linking Crystal code: #{link_command}" if verbose
        unless system(link_command)
          puts "Failed to link Crystal library."
          return false
        end
      end

      true
    end

    def self.compile_command!(verbose:, debug:, lib:, src:)
      @compile_command ||= begin
        verbose_flag = verbose ? "--verbose" : ""
        debug_flag = debug ? "" : "--release --no-debug"
        redirect_output = " > /dev/null " unless verbose

        %(crystal build #{verbose_flag} #{debug_flag} --cross-compile -o #{lib} #{src}#{redirect_output})
      end
    end

    # Here we misuse the crystal compiler to build a valid linking command
    # with all of the platform specific flags that we need.
    # We then use this command to link the object file that we compiled in the previous step.
    # This is not robust and is likely to need revision in the future.
    def self.link_cmd!(verbose:, lib:, src:)
      @link_cmd ||= begin
        result = nil

        Dir.mktmpdir do |tmp|
          output, status = Open3.capture2("crystal build --verbose #{src} -o #{Pathname.new(tmp) / "main"}")
          unless status.success?
            puts "Failed to compile the Crystal code."
            exit 1
          end

          # Parse the output to find the last invocation of the C compiler, which is likely the linking stage
          # and strip off the targets that the crystal compiler added.
          link_command_suffix = output.lines.select { |line| line.strip.start_with?("cc") }.last.strip[/.*(-o.*)/, 1]

          # Replace the output file with the path to the object file we compiled
          link_command_suffix.gsub!(
            /-o.*main/,
            "-o #{lib}"
          )
          result = %(cc #{lib}.o -shared #{link_command_suffix})
          result << " > /dev/null 2>&1" unless verbose
          result
        end

        result
      end
    end
  end
end
