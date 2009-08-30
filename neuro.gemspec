    Gem::Specification.new do |s|
      s.name = 'neuro'
      s.version = '0.4.1'
      s.summary = "Neural Network Extension for Ruby"
      s.description = <<EOF
A Ruby extension that provides a 2-Layer Back Propagation Neural Network, which
can be used to categorize datasets of arbitrary size.
EOF

      s.files = ["CHANGES", "Rakefile", "VERSION", "examples", "examples/ocr.rb", "ext", "ext/extconf.rb", "ext/neuro.c", "install.rb", "lib", "lib/neuro", "lib/neuro.so", "lib/neuro/display.rb", "lib/neuro/version.rb", "neuro.gemspec", "tests", "tests/test_even_odd.rb", "tests/test_parity.rb"]

      s.extensions = "ext/extconf.rb"

      s.require_paths << 'ext' << 'lib'

      s.has_rdoc = true
      s.extra_rdoc_files << 'doc-main.txt'
      s.rdoc_options << '--main' << 'doc-main.txt' << '--title' << 'Neural Network Extension for Ruby'
      s.test_files.concat ["tests/test_even_odd.rb", "tests/test_parity.rb"]

      s.author = "Florian Frank"
      s.email = "flori@ping.de"
      s.homepage = "http://neuro.rubyforge.org"
      s.rubyforge_project = 'neuro'
    end
