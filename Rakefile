require 'rake'
require 'rake/clean'

NAME    = 'nucular'
VERSION = '0.0.1'

def name
  "#{NAME}.#{VERSION}"
end

DC    = 'dmd'
FLAGS = ENV['FLAGS'] || ''

if ENV['DEBUG']
	FLAGS << ' -debug'
end

SOURCES = FileList['nucular/**/*.d']
OBJECTS = SOURCES.ext('o')

CLEAN.include(OBJECTS)

task :default => ["lib#{name}.so"]

rule '.o' => '.d' do |t|
  sh "#{DC} #{FLAGS} -fPIC -of#{t.name} -c #{t.source}"
end

file "lib#{name}.so" => OBJECTS do
	sh "#{DC} -shared -fPIC #{FLAGS} #{OBJECTS} -oflib#{name}.so"
end
