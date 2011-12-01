# vim: set filetype=ruby et sw=2 ts=2:

require 'gem_hadar'

GemHadar do
  name        'neuro'
  author      'Florian Frank'
  email       'flori@ping.de'
  homepage    "http://flori.github.com/#{name}"
  summary     'Neural Network Extension for Ruby'
  description <<EOT
A Ruby extension that provides a 2-Layer Back Propagation Neural Network, which
can be used to categorize datasets of arbitrary size.
EOT
  test_dir    'tests'
  ignore      '.*.sw[pon]', 'pkg', 'Gemfile.lock'
  clean       '*.dump'
  title       "#{name.camelize} - #{summary}"
  readme      'README.rdoc'
  require_paths %w[lib ext]
  development_dependency 'test-unit', '~>2.4'

  install_library do
    src = "ext/neuro.#{CONFIG['DLEXT']}"
    filename = File.basename(src)
    dst = File.join(CONFIG["sitelibdir"], filename)
    install(src, dst, :verbose => true, :mode => 0644)
    dst_dir = File.join(CONFIG["sitelibdir"], 'neuro')
    mkdir_p dst_dir
    cd 'lib/neuro' do
      for src in Dir['*.rb']
        dst = File.join(dst_dir, src)
        install(src, dst, :verbose => true, :mode => 0644)
      end
    end
  end
end
