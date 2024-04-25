require "tmpdir"
require "shellwords"

module CrystalRuby
  module Compilation
    class CompilationFailedError < StandardError; end

    def self.compile!(
      src:,
      lib:,
      verbose: CrystalRuby.config.verbose,
      debug: CrystalRuby.config.debug
    )
      compile_command = build_compile_command(verbose: verbose, debug: debug, lib: lib, src: src)
      CrystalRuby.log_debug "Compiling Crystal code #{verbose ? ": #{compile_command}" : ""}"
      raise CompilationFailedError, "Compilation failed" unless system(compile_command)
    end

    def self.build_compile_command(verbose:, debug:, lib:, src:)
      verbose_flag = verbose ? "--verbose --progress" : ""
      debug_flag = debug ? "" : "--release --no-debug"
      redirect_output = " &> /dev/null " unless verbose
      lib, src, lib_dir = [lib, src, File.dirname(src)].map(&Shellwords.method(:escape))
      %(cd #{lib_dir} && crystal build #{verbose_flag} #{debug_flag} --single-module --link-flags "-shared" -o #{lib} #{src}#{redirect_output})
    end
  end
end
