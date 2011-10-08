# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
 
require 'filterkit/version'
 
Gem::Specification.new do |s|
  s.name        = "filterkit"
  s.version     = FilterKit::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Ewout van Troostenberghe"]
  s.email       = ["<todo>"]
  s.homepage    = "https://github.com/devwout/filterkit"
  s.summary     = "<todo>"
  s.description = "<todo>"
 
  s.add_development_dependency "rspec"
 
  s.files        = Dir.glob("{bin,lib}/**/*")
  s.require_path = 'lib'
end

