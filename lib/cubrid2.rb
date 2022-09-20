require 'date'
require 'bigdecimal'

# Load libcubrid.dll before requiring cubrid/cubrid.so
# This gives a chance to be flexible about the load path
# Or to bomb out with a clear error message instead of a linker crash
if RUBY_PLATFORM =~ /mswin|mingw/
  dll_path = if ENV['RUBY_CUBRID_LIBCUBRID_DLL']
               # If this environment variable is set, it overrides any other paths
               # The user is advised to use backslashes not forward slashes
               ENV['RUBY_CUBRID_LIBCUBRID_DLL']
             elsif File.exist?(File.expand_path('../vendor/libcubrid.dll', File.dirname(__FILE__)))
               # Use vendor/libcubrid.dll if it exists, convert slashes for Win32 LoadLibrary
               File.expand_path('../vendor/libcubrid.dll', File.dirname(__FILE__))
               # elsif defined?(RubyInstaller)
               # RubyInstaller-2.4+ native build doesn't need DLL preloading
               # else
               # This will use default / system library paths
               '../vendor/libcubrid.dll'
             end

  if dll_path
    require 'fiddle'
    kernel32 = Fiddle.dlopen 'kernel32'
    load_library = Fiddle::Function.new(
      kernel32['LoadLibraryW'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_INT
    )
    abort "Failed to load libcubrid.dll from #{dll_path}" if load_library.call(dll_path.encode('utf-16le')).zero?
  end
end

# load c extension
require 'cubrid'

require 'cubrid2/version' unless defined? Cubrid2::VERSION
require 'cubrid2/error'
require 'cubrid2/result'
require 'cubrid2/client'
require 'cubrid2/field'
require 'cubrid2/statement'

# = cubrid
#
# A modern, simple and very fast Cubrid library for Ruby - binding to libcubrid
module Cubrid2
end

# For holding utility methods
module Cubrid2
  module Util
    #
    # Rekey a string-keyed hash with equivalent symbols.
    #
    def self.key_hash_as_symbols(hash)
      return nil unless hash

      Hash[hash.map { |k, v| [k.to_sym, v] }]
    end

    #
    # In Cubrid2::Client#query and Cubrid2::Statement#execute,
    # Thread#handle_interrupt is used to prevent Timeout#timeout
    # from interrupting query execution.
    #
    # Timeout::ExitException was removed in Ruby 2.3.0, 2.2.3, and 2.1.8,
    # but is present in earlier 2.1.x and 2.2.x, so we provide a shim.
    #
    require 'timeout'
    TIMEOUT_ERROR_CLASS = if defined?(::Timeout::ExitException)
                            ::Timeout::ExitException
                          else
                            ::Timeout::Error
                          end
  end
end
