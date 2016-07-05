# -*- ruby -*-
# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'purecdb/version'

Gem::Specification.new do |spec|
  spec.name          = "purecdb"
  spec.version       = PureCDB::VERSION
  spec.authors       = ["Vidar Hokstad"]
  spec.email         = ["vidar@hokstadconsulting.com"]

  spec.summary       = %q{A Pure Ruby CDB reader/writer w/64 bit extensions}
  spec.description   = spec.summary
  spec.homepage      = "https://github.com/hokstadconsulting/purecdb"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com' to prevent pushes to rubygems.org, or delete to allow pushes to any server."
  end

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rdoc"
end
