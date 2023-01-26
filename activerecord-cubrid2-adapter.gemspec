# frozen_string_literal: true

version = File.read(File.expand_path('VERSION', __dir__)).strip

Gem::Specification.new do |spec|
  spec.name          = 'activerecord-cubrid2-adapter'
  spec.platform      = Gem::Platform::RUBY
  spec.version       = version

  spec.required_ruby_version = '>= 2.5.0'

  spec.licenses      = ['MIT', 'GPL-2.0']
  spec.authors       = ['Eui-Taik Na']
  spec.email         = ['damulhan@gmail.com']
  spec.homepage      = 'https://github.com/damulhan/activerecord-cubrid2-adapter'
  spec.summary       = 'ActiveRecord Cubrid Adapter.'
  spec.description   = 'ActiveRecord Cubrid Adapter. Cubrid 9 and upward. Based on cubrid gem.'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activerecord', '~> 6.0', '>= 6.0'
  spec.add_runtime_dependency 'cubrid', '~> 10.0', '>= 10.0'
end
