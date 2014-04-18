# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'sec_statement_parser/version'

Gem::Specification.new do |spec|
  spec.name          = "sec_statement_parser"
  spec.version       = SecStatementParser::VERSION
  spec.authors       = ["Stanley Chu"]
  spec.email         = ["icarus4.chu@gmail.com"]
  spec.description   = %q{A gem for parsing stock financial statement from SEC Edgar}
  spec.summary       = %q{A gem for parsing stock financial statement from SEC Edgar}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", "~> 10.3.0"
  spec.add_development_dependency "rspec", "~> 2.14.0"
  spec.add_development_dependency "nokogiri", "~> 1.6.1"
  spec.add_development_dependency "faraday", "~> 0.9.0"
  spec.add_development_dependency "colorize", "~> 0.7.2"
end
