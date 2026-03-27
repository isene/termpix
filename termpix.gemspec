Gem::Specification.new do |s|
  s.name        = 'termpix'
  s.version     = '0.4.1'
  s.licenses    = ['Unlicense']
  s.summary     = "Modern terminal image display with multiple protocol support"
  s.description = "Termpix v0.4.1: Kitty protocol now supports multiple simultaneous images. Track array of active image IDs instead of single image. clear() removes all active images at once."
  s.authors     = ["Geir Isene"]
  s.email       = 'g@isene.com'
  s.files       = ["lib/termpix.rb", "lib/termpix/version.rb", "lib/termpix/protocols.rb", "README.md"]
  s.homepage    = 'https://github.com/isene/termpix'
  s.metadata    = { "source_code_uri" => "https://github.com/isene/termpix" }
  s.required_ruby_version = '>= 2.7.0'
end
