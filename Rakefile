require 'rake'
require 'rake/clean'

DC    = ENV['DC'] || 'dmd'
FLAGS = "-version=select -w -Ivendor/pegged -Ivendor/openssl #{ENV['FLAGS']}"

if ENV['DEBUG']
	FLAGS << ' -debug -gc -gs'
end

GRAMMARS = FileList['nucular/**/*.pegd']

SOURCES = FileList['nucular/**/*.d',
	'vendor/pegged/pegged/peg.d', 'vendor/pegged/pegged/grammar.d', 'vendor/pegged/pegged/utils/associative.d',
].include(GRAMMARS.ext('d'))

OBJECTS = SOURCES.ext('o')

EXAMPLES = FileList['examples/*.d'].ext('')

CLEAN.include(OBJECTS).include(GRAMMARS.ext('d')).include(EXAMPLES.ext('o'))
CLOBBER.include(EXAMPLES).include('vendor/pegged/peggeden')

task :default => 'libnucular.a'

file 'libnucular.a' => GRAMMARS.ext('d') + OBJECTS do |t|
	sh "#{DC} #{FLAGS} -lib -oflibnucular.a #{OBJECTS}"
end

task :peggeden => 'vendor/pegged/peggeden'

file 'vendor/pegged/peggeden' do
	Dir.chdir 'vendor/pegged' do
		sh 'make'
	end
end

GRAMMARS.ext('').each {|name|
	file "#{name}.d" => [:peggeden, "#{name}.pegd"] do
		sh "vendor/pegged/peggeden #{name}.pegd #{name}.d"
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
		File.open('test.d', 'w') { |f| f.write('void main () { }') }

		sh "#{DC} #{FLAGS} -unittest -oftest test.d libnucular.a"
		sh './test'
	ensure
		sh 'rm -f test test.o test.d'
	end
end
