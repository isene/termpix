Gem::Specification.new do |s|
  s.name        = 'termpix'
  s.version     = '0.2.0'
  s.licenses    = ['Unlicense']
  s.summary     = "Modern terminal image display with multiple protocol support"
  s.description = "Termpix v0.2.0: EXIF auto-orient support preserves correct image orientation. Provides clean API for displaying images in terminal using best available protocol (Sixel or w3m). Auto-detects terminal capabilities and falls back gracefully."
  s.authors     = ["Geir Isene"]
  s.email       = 'g@isene.com'
  s.files       = ["lib/termpix.rb", "lib/termpix/version.rb", "lib/termpix/protocols.rb", "README.md"]
  s.homepage    = 'https://github.com/isene/termpix'
  s.metadata    = { "source_code_uri" => "https://github.com/isene/termpix" }
  s.required_ruby_version = '>= 2.7.0'
end
