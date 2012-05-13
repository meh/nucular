require 'rake'
require 'rake/clean'

NAME    = 'nucular'
VERSION = '0.0.1'

def name
  "#{NAME}.#{VERSION}"
end

DC    = 'dmd'
FLAGS = ''

if ENV['DEBUG']
	FLAGS << ' -debug'
end

SOURCES = FileList['nucular/**/*.d']
OBJECTS = SOURCES.ext('o')

task :default => ["lib#{name}.so"]

file "lib#{name}.so" do
	sh "#{DC} -shared #{FLAGS} #{SOURCES}"
end
