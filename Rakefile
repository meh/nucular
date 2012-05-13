require 'rake'
require 'rake/clean'

NAME    = 'nucular'
VERSION = '0.0.1'

DC    = 'dmd'
FLAGS = "#{ENV['FLAGS']}"

if ENV['DEBUG']
	FLAGS << ' -debug'
end

EXAMPLES = FileList['examples/*.d'].ext('')
SOURCES  = FileList['nucular/**/*.d']
OBJECTS  = SOURCES.ext('o')

CLEAN.include(OBJECTS).include(EXAMPLES).include(EXAMPLES.ext('o'))

task :default => EXAMPLES

rule '.o' => '.d' do |t|
  sh "#{DC} #{FLAGS} -of#{t.name} -c #{t.source}"
end

EXAMPLES.each {|name|
	file name => OBJECTS + ["#{name}.o"] do
		sh "#{DC} #{FLAGS} #{name}.o #{OBJECTS} -of#{name}"
	end
}

