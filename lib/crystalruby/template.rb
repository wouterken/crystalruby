module CrystalRuby
  module Template
    Dir[File.join(File.dirname(__FILE__), "templates", "*.cr")].each do |file|
      template_name = File.basename(file, File.extname(file)).split("_").map(&:capitalize).join
      const_set(template_name, File.read(file))
    end

    def self.render(template, context)
      template % context
    end
  end
end
