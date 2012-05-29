require 'rake'
require 'rake/clean'

DC    = ENV['DC'] || 'dmd'
FLAGS = "-version=select -w -Ivendor/pegged #{ENV['FLAGS']}"

if ENV['DEBUG']
	FLAGS << ' -debug'
end

GRAMMARS = FileList['nucular/**/*.pegd']

SOURCES = FileList['nucular/**/*.d',
	'vendor/pegged/pegged/peg.d', 'vendor/pegged/pegged/grammar.d', 'vendor/pegged/pegged/utils/associative.d',
].include(GRAMMARS.ext('d'))

OBJECTS = SOURCES.ext('o')

EXAMPLES = FileList['examples/*.d'].ext('')

CLEAN.include(OBJECTS).include(GRAMMARS.ext('d')).include(EXAMPLES.ext('o'))
CLOBBER.include(EXAMPLES).include('test')

task :default => 'libnucular.a'

file 'libnucular.a' => GRAMMARS.ext('d') + OBJECTS do |t|
	sh "#{DC} #{FLAGS} -lib -oflibnucular.a #{OBJECTS}"
end

GRAMMARS.ext('').each {|name|
	file "#{name}.d" => "#{name}.pegd" do
		sh "peggeden #{name}.pegd #{name}.d"
	end
}

rule '.o' => '.d' do |t|
  sh "#{DC} #{FLAGS} -of#{t.name} -c #{t.source}"
end

EXAMPLES.each {|name|
	file name => ['libnucular.a', "#{name}.o"] do
		sh "#{DC} #{FLAGS} #{name}.o libnucular.a -of#{name}"
	end
}

task :examples => EXAMPLES

task :test do
	FLAGS << ' -unittest' and Rake::Task[:default].invoke

	begin
		sh "#{DC} #{FLAGS} -oftest test.d #{OBJECTS}"
		sh './test'
	ensure
		sh 'rm -f test test.o'
	end
end
