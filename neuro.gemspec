# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "neuro"
  s.version = "0.4.3"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Florian Frank"]
  s.date = "2011-12-01"
  s.description = "A Ruby extension that provides a 2-Layer Back Propagation Neural Network, which\ncan be used to categorize datasets of arbitrary size.\n"
  s.email = "flori@ping.de"
  s.extensions = ["ext/extconf.rb"]
  s.extra_rdoc_files = ["README.rdoc", "lib/neuro/version.rb", "lib/neuro/display.rb", "ext/neuro.c"]
  s.files = [".gitignore", ".travis.yml", "CHANGES", "Gemfile", "README.rdoc", "Rakefile", "VERSION", "examples/ocr.rb", "ext/extconf.rb", "ext/neuro.c", "install.rb", "lib/neuro/display.rb", "lib/neuro/version.rb", "neuro.gemspec", "tests/test_even_odd.rb", "tests/test_parity.rb"]
  s.homepage = "http://flori.github.com/neuro"
  s.rdoc_options = ["--title", "Neuro - Neural Network Extension for Ruby", "--main", "README.rdoc"]
  s.require_paths = ["lib", "ext"]
  s.rubygems_version = "1.8.11"
  s.summary = "Neural Network Extension for Ruby"
  s.test_files = ["tests/test_even_odd.rb", "tests/test_parity.rb"]

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<gem_hadar>, ["~> 0.1.3"])
      s.add_development_dependency(%q<test-unit>, ["~> 2.4"])
    else
      s.add_dependency(%q<gem_hadar>, ["~> 0.1.3"])
      s.add_dependency(%q<test-unit>, ["~> 2.4"])
    end
  else
    s.add_dependency(%q<gem_hadar>, ["~> 0.1.3"])
    s.add_dependency(%q<test-unit>, ["~> 2.4"])
  end
end
