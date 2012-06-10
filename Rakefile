require 'rake'
require 'rake/clean'

DC       = ENV['DC'] || 'dmd'
SELECTOR = ENV['SELECTOR'] || 'select'
CFLAGS   = "#{ENV['CFLAGS']} -version=#{SELECTOR} -w -Ivendor/pegged -Ivendor/openssl"
LDFLAGS  = "#{ENV['LDFLAGS']} -L-lssl -L-lcrypto"

if ENV['DEBUG']
	CFLAGS << ' -debug -gc'
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
	sh "#{DC} #{CFLAGS} -lib -oflibnucular.a #{OBJECTS}"
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
  sh "#{DC} #{CFLAGS} -of#{t.name} -c #{t.source}"
end

EXAMPLES.each {|name|
	file name => ['libnucular.a', "#{name}.o"] do
		sh "#{DC} #{CFLAGS} #{LDFLAGS} #{name}.o libnucular.a -of#{name}"
	end
}

task :examples => EXAMPLES
