require "tmpdir"
require "shellwords"
require "timeout"

module CrystalRuby
  module Compilation
    class CompilationFailedError < StandardError; end

    # Simple wrapper around invocation of the Crystal compiler
    # @param src [String] path to the source file
    # @param lib [String] path to the library file
    # @param verbose [Boolean] whether to print the compiler output
    # @param debug [Boolean] whether to compile in debug mode
    # @raise [CompilationFailedError] if the compilation fails
    # @return [void]
    def self.compile!(
      src:,
      lib:,
      verbose: CrystalRuby.config.verbose,
      debug: CrystalRuby.config.debug
    )
      compile_command = build_compile_command(verbose: verbose, debug: debug, lib: lib, src: src)
      CrystalRuby.log_debug "Compiling Crystal code #{verbose ? ": #{compile_command}" : ""}"
      IO.popen(compile_command, chdir: File.dirname(src), &:read)
      raise CompilationFailedError, "Compilation failed in #{src}" unless $?&.success?
    end

    # Builds the command to compile the Crystal source file
    # @param verbose [Boolean] whether to print the compiler output
    # @param debug [Boolean] whether to compile in debug mode
    # @param lib [String] path to the library file
    # @param src [String] path to the source file
    # @return [String] the command to compile the Crystal source file
    def self.build_compile_command(verbose:, debug:, lib:, src:)
      verbose_flag = verbose ? "--verbose --progress" : ""
      debug_flag = debug ? "" : "--release --no-debug"
      redirect_output = " > /dev/null " unless verbose
      lib, src = [lib, src].map(&Shellwords.method(:escape))
      %(crystal build #{verbose_flag} #{debug_flag} --single-module --link-flags "-shared" -o #{lib} #{src}#{redirect_output})
    end

    # Trigger the shards install command in the given source directory
    def self.install_shards!(src_dir)
      CrystalRuby.log_debug "Running shards install inside #{src_dir}"
      output = IO.popen("shards update", chdir: src_dir, &:read)
      CrystalRuby.log_debug output if CrystalRuby.config.verbose
      raise CompilationFailedError, "Shards install failed" unless $?&.success?
    end

    # Return whether the shards check command succeeds in the given source directory
    def self.shard_check?(src_dir)
      IO.popen("shards check", chdir: src_dir, &:read)
      $?&.success?
    end
  end
end
