Gem::Specification.new do |s|
  s.name        = 'termpix'
  s.version     = '0.1.0'
  s.licenses    = ['Unlicense']
  s.summary     = "Modern terminal image display with multiple protocol support"
  s.description = "Termpix provides a clean API for displaying images in the terminal using the best available protocol (Kitty, Sixel, Überzug++, or w3m). Auto-detects terminal capabilities and falls back gracefully."
  s.authors     = ["Geir Isene"]
  s.email       = 'g@isene.com'
  s.files       = ["lib/termpix.rb", "lib/termpix/version.rb", "lib/termpix/protocols.rb", "README.md"]
  s.homepage    = 'https://github.com/isene/termpix'
  s.metadata    = { "source_code_uri" => "https://github.com/isene/termpix" }
  s.required_ruby_version = '>= 2.7.0'
end
