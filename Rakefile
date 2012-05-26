require 'rake'
require 'rake/clean'

NAME    = 'nucular'
VERSION = '0.0.1'

DC    = 'dmd'
FLAGS = "-version=select -w #{ENV['FLAGS']}"

if ENV['DEBUG']
	FLAGS << ' -debug'
end

EXAMPLES = FileList['examples/*.d'].ext('')
SOURCES  = FileList['nucular/**/*.d']
OBJECTS  = SOURCES.ext('o')

CLEAN.include(OBJECTS).include(EXAMPLES.ext('o'))
CLOBBER.include(EXAMPLES)

task :default => 'libnucular.a'

rule '.o' => '.d' do |t|
  sh "#{DC} #{FLAGS} -of#{t.name} -c #{t.source}"
end

file 'libnucular.a' => OBJECTS do |t|
	sh "#{DC} #{FLAGS} -lib -oflibnucular.a #{OBJECTS}"
end

EXAMPLES.each {|name|
	file name => ['libnucular.a', "#{name}.o"] do
		sh "#{DC} #{FLAGS} #{name}.o libnucular.a -of#{name}"
	end
}

task :examples => EXAMPLES
