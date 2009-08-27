#!/usr/bin/env ruby

require 'rbconfig'
include Config
require 'fileutils'
include FileUtils::Verbose

MAKE = if RUBY_PLATFORM =~ /mswin32/i 
  'nmake'
else
  ENV['MAKE'] || %w[gmake make].find { |c| system(c, '-v') }
end

bindir  = CONFIG['bindir']
archdir = CONFIG['sitearchdir']
libdir  = CONFIG['sitelibdir']
dlext   = CONFIG['DLEXT']

cd 'ext' do
  system 'ruby extconf.rb' or exit 1
  system "#{MAKE}" or exit 1
  mkdir_p archdir
  install "neuro.#{dlext}", archdir
end

mkdir_p dst_dir = File.join(libdir, 'neuro')
for file in Dir['lib/neuro/*.rb']
  install file, File.join(dst_dir, File.basename(file))
end
