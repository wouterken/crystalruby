module CrystalRuby
  module Template
    Dir[File.join(File.dirname(__FILE__), "templates", "*.cr")].each do |file|
      template_name = File.basename(file, File.extname(file)).split("_").map(&:capitalize).join
      template_value = File.read(file)
      template_value.define_singleton_method(:render) do |context|
        self % context
      end
      const_set(template_name, template_value)
    end
  end
end
