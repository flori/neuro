require 'mkmf'

if CONFIG['CC'] == 'gcc'
  CONFIG['CC'] = 'gcc -Wall -O2'
end
create_makefile 'neuro'
