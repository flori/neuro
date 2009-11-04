# vim: set filetype=ruby et sw=2 ts=2:

begin
  require 'rake/gempackagetask'
  require 'rake/extensiontask'
rescue LoadError
end

require 'rbconfig'
include Config

require 'rake/clean'
CLEAN.include 'doc', 'coverage', FileList["**/*.dump"],
  FileList["ext/*.{o,so,#{CONFIG['DLEXT']}}"], 'lib/*.so',
  'ext/Makefile'

MAKE = ENV['MAKE'] || %w[gmake make].find { |c| system(c, '-v') }
PKG_NAME = 'neuro'
PKG_VERSION = File.read('VERSION').chomp
PKG_FILES = FileList["**/*"].exclude(/CVS|pkg|doc|tmp|coverage|(\.dump\Z)/).to_a

task :default => :test

desc "Run unit tests"
task :test => :compile_ext do
  sh 'testrb -Iext:lib tests/test_*.rb'
end

desc "Creating documentation"
task :doc do
  sh 'rdoc -t "neuro - Neural Network Extension for Ruby" -m doc-main.txt -o doc doc-main.txt ext/neuro.c lib/neuro/version.rb' # lib/neuro/display.rb'
end

desc "Compiling library"
task :compile_ext do
  cd 'ext' do
    ruby 'extconf.rb'
    sh MAKE
  end
end

desc "Installing library"
task :install => :test do
  src = "ext/neuro.#{CONFIG['DLEXT']}"
  filename = File.basename(src)
  dst = File.join(CONFIG["sitelibdir"], filename)
  install(src, dst, :verbose => true, :mode => 0644)
  src = 'lib/neuro/display.rb'
  filename = File.basename(src)
  dst_dir = File.join(CONFIG["sitelibdir"], 'neuro')
  mkdir_p dst_dir
  dst = File.join(dst_dir, filename)
  install(src, dst, :verbose => true, :mode => 0644)
end

if defined?(Gem) and defined?(Rake::GemPackageTask) and
  defined?(Rake::ExtensionTask)
then
  spec_src = <<-GEM
    Gem::Specification.new do |s|
      s.name = '#{PKG_NAME}'
      s.version = '#{PKG_VERSION}'
      s.summary = "Neural Network Extension for Ruby"
      s.description = <<EOF
A Ruby extension that provides a 2-Layer Back Propagation Neural Network, which
can be used to categorize datasets of arbitrary size.
EOF

      s.files = #{PKG_FILES.to_a.sort.inspect}

      s.extensions = "ext/extconf.rb"

      s.require_paths << 'ext' << 'lib'

      s.has_rdoc = true
      s.extra_rdoc_files << 'doc-main.txt'
      s.rdoc_options << '--main' << 'doc-main.txt' << '--title' << 'Neural Network Extension for Ruby'
      s.test_files.concat #{Dir['tests/test_*.rb'].to_a.sort.inspect}

      s.author = "Florian Frank"
      s.email = "flori@ping.de"
      s.homepage = "http://neuro.rubyforge.org"
      s.rubyforge_project = '#{PKG_NAME}'
    end
  GEM

  desc 'Create a gemspec file'
  task :gemspec do
    File.open("#{PKG_NAME}.gemspec", 'w') do |f|
      f.puts spec_src
    end
  end

  spec = eval(spec_src)
  Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_tar      = true
    pkg.package_files = PKG_FILES
  end

  Rake::ExtensionTask.new do |ext|
    ext.name            = PKG_NAME
    ext.gem_spec        = spec
    ext.cross_compile   = true
    ext.cross_platform  = 'i386-mswin32'
    ext.ext_dir         = 'ext'
    ext.lib_dir         = 'lib'
  end
end

desc m = "Writing version information for #{PKG_VERSION}"
task :version do
  puts m
  File.open(File.join('lib', 'neuro', 'version.rb'), 'w') do |v|
    v.puts <<EOT
module Neuro
  # Neuro version
  VERSION         = '#{PKG_VERSION}'
  VERSION_ARRAY   = VERSION.split(/\\./).map { |x| x.to_i } # :nodoc:
  VERSION_MAJOR   = VERSION_ARRAY[0] # :nodoc:
  VERSION_MINOR   = VERSION_ARRAY[1] # :nodoc:
  VERSION_BUILD   = VERSION_ARRAY[2] # :nodoc:
end
EOT
  end
end

task :default => [ :version, :gemspec, :test ]

desc "Build all gems and archives for a new release."
task :release => [ :clean, :version, :gemspec, :cross, :native, :gem ] do
  system "#$0 clean native gem"
  system "#$0 clean package"
end
