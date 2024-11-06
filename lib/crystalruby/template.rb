module CrystalRuby
  module Template
    class Renderer < Struct.new(:raw_value)
      require 'erb'
      def render(context)
        if context.kind_of?(::Hash)
          raw_value % context
        else
          ERB.new(raw_value, trim_mode: "%").result(context)
        end
      end
    end

    (
      Dir[File.join(File.dirname(__FILE__), "templates", "**", "*.cr")] +
      Dir[File.join(File.dirname(__FILE__), "types", "**", "*.cr")]
    ).each do |file|
      template_name = File.basename(file, File.extname(file)).split("_").map(&:capitalize).join
      template_value = File.read(file)
      const_set(template_name, Renderer.new(template_value))
    end
  end
end
