require 'rake'
require 'rake/clean'

DC    = ENV['DC'] || 'dmd'
FLAGS = "-version=select -w -Ivendor/pegged #{ENV['FLAGS']}"

if ENV['DEBUG']
	FLAGS << ' -debug'
end

GRAMMARS = FileList['nucular/**/*.pegd']
SOURCES  = FileList['nucular/**/*.d'].include(GRAMMARS.ext('d'))
OBJECTS  = SOURCES.ext('o')

EXAMPLES = FileList['examples/*.d'].ext('')

CLEAN.include(OBJECTS).include(EXAMPLES.ext('o'))
CLOBBER.include(EXAMPLES).include('test')

rule '.pegd' => '.d' do |t|
  sh "peggeden #{t.source} #{t.name}"
end

rule '.o' => '.d' do |t|
  sh "#{DC} #{FLAGS} -of#{t.name} -c #{t.source}"
end

file 'libnucular.a' => GRAMMARS + OBJECTS do |t|
	sh "#{DC} #{FLAGS} -lib -oflibnucular.a #{OBJECTS}"
end

task :default => 'libnucular.a'

task :test do
	FLAGS << ' -unittest' and Rake::Task[:default].invoke

	begin
		sh "#{DC} #{FLAGS} -oftest test.d #{OBJECTS}"
		sh './test'
	ensure
		sh 'rm -f test test.o'
	end
end

EXAMPLES.each {|name|
	file name => ['libnucular.a', "#{name}.o"] do
		sh "#{DC} #{FLAGS} #{name}.o libnucular.a -of#{name}"
	end
}

task :examples => EXAMPLES
