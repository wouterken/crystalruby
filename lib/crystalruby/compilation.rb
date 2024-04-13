require "open3"
require "tmpdir"
require "shellwords"

module CrystalRuby
  module Compilation
    def self.compile!(
      src: CrystalRuby.config.crystal_src_dir_abs / CrystalRuby.config.crystal_main_file,
      lib: CrystalRuby.config.crystal_lib_dir_abs / CrystalRuby.config.crystal_lib_name,
      verbose: CrystalRuby.config.verbose,
      debug: CrystalRuby.config.debug
    )
      Dir.chdir(CrystalRuby.config.crystal_src_dir_abs) do
        compile_command = compile_command!(verbose: verbose, debug: debug, lib: lib, src: src)
        link_command = link_cmd!(verbose: verbose, lib: lib, src: src)

        CrystalRuby.log_debug "Compiling Crystal code: #{compile_command}"
        unless system(compile_command)
          CrystalRuby.log_error "Failed to build Crystal object file."
          return false
        end

        CrystalRuby.log_debug "Linking Crystal code: #{link_command}"
        unless system(link_command)
          CrystalRuby.log_error "Failed to link Crystal library."
          return false
        end
        CrystalRuby.log_info "Compilation successful"
      end

      true
    end

    def self.compile_command!(verbose:, debug:, lib:, src:)
      @compile_command ||= begin
        verbose_flag = verbose ? "--verbose" : ""
        debug_flag = debug ? "" : "--release --no-debug"
        redirect_output = " > /dev/null " unless verbose

        src = Shellwords.escape(src)
        lib = Shellwords.escape(lib)

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
          CrystalRuby.log_debug "Building link command"
          src = Shellwords.escape(src)
          lib_dir = Shellwords.escape(CrystalRuby.config.crystal_src_dir_abs / "lib")
          escaped_output_path = Shellwords.escape(Pathname.new(tmp) / "main")

          command = "timeout -k 2s 2s bash -c \"export CRYSTAL_PATH=$(crystal env CRYSTAL_PATH):#{lib_dir} && crystal build --verbose #{src} -o #{escaped_output_path} \""

          output = ""
          pid = nil

          CrystalRuby.log_debug "Running command: #{command}"

          Open3.popen2e(command) do |_stdin, stdout_and_stderr, _wait_thr|
            while line = stdout_and_stderr.gets
              puts line if verbose
              output += line # Capture the output
            end
          end

          CrystalRuby.log_debug "Parsing link command"

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
    rescue StandardError
      ""
    end
  end
end
