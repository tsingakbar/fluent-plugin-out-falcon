# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = "fluent-plugin-out-falcon"
  gem.version       = "0.1.5"
  gem.authors       = ["Marica Odagaki"]
  gem.email         = ["ento.entotto@gmail.com"]
  gem.summary       = %q{A Fluentd output plugin to send logs to falcon's push api}
  gem.description   = gem.summary
  gem.homepage      = "https://github.com/tsingakbar/fluent-plugin-out-falcon"
  gem.licenses      = ["Apache-2.0"]

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "yajl-ruby", "~> 1.0"
  gem.add_runtime_dependency "fluentd", [">= 0.10.0", "< 2"]
  gem.add_development_dependency "bundler"
  gem.add_development_dependency "rake"
  gem.add_development_dependency "test-unit", ">= 3.1.0"
end
