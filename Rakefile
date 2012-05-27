require 'rake'
require 'rake/clean'

DC    = ENV['DC'] || 'dmd'
FLAGS = "-version=select -w -Ivendor/pegged #{ENV['FLAGS']}"

if ENV['DEBUG']
	FLAGS << ' -debug'
end

EXAMPLES = FileList['examples/*.d'].ext('')

SOURCES = FileList['nucular/**/*.d',
	'vendor/pegged/pegged/*.d', 'vendor/pegged/pegged/utils/*.d'
]

OBJECTS = SOURCES.ext('o')

CLEAN.include(OBJECTS).include(EXAMPLES.ext('o'))
CLOBBER.include(EXAMPLES).include('test')

rule '.o' => '.d' do |t|
  sh "#{DC} #{FLAGS} -of#{t.name} -c #{t.source}"
end

file 'libnucular.a' => OBJECTS do |t|
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
