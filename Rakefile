# frozen_string_literal: true

require "bundler/gem_tasks"
task default: %i[]

require "rake/extensiontask"

Rake::ExtensionTask.new "activerecord-cubrid-adapter" do |ext|
  ext.name = 'cubrid'
  ext.lib_dir = "lib"
end
