module Cubrid2
  class Error < StandardError
    ENCODE_OPTS = {
      undef: :replace,
      invalid: :replace,
      replace: '?'.freeze
    }.freeze

    ConnectionError = Class.new(Error)
    TimeoutError = Class.new(Error)

    attr_reader :error_number, :sql_state

    ######################################
    # ### CUBRID Error codes
    # from ext/error.c

    # {-1,      "CUBRID database error"},
    # {-2,      "Invalid connection handle"},
    # {-3,      "Memory allocation error"},
    # {-4,      "Communication error"},
    # {-5,      "No more data"},
    # {-6,      "Unknown transaction type"},
    # {-7,      "Invalid string parameter"},
    # {-8,      "Type conversion error"},
    # {-9,      "Parameter binding error"},
    # {-10,     "Invalid type"},
    # {-11,     "Parameter binding error"},
    # {-12,     "Invalid database parameter name"},
    # {-13,     "Invalid column index"},
    # {-14,     "Invalid schema type"},
    # {-15,     "File open error"},
    # {-16,     "Connection error"},
    # {-17,     "Connection handle creation error"},
    # {-18,     "Invalid request handle"},
    # {-19,     "Invalid cursor position"},
    # {-20,     "Object is not valid"},
    # {-21,     "CAS error"},
    # {-22,     "Unknown host name"},
    # {-99,     "Not implemented"},
    # {-1000,   "Database connection error"},
    # {-1002,   "Memory allocation error"},
    # {-1003,   "Communication error"},
    # {-1004,   "Invalid argument"},
    # {-1005,   "Unknown transaction type"},
    # {-1007,   "Parameter binding error"},
    # {-1008,   "Parameter binding error"},
    # {-1009,   "Cannot make DB_VALUE"},
    # {-1010,   "Type conversion error"},
    # {-1011,   "Invalid database parameter name"},
    # {-1012,   "No more data"},
    # {-1013,   "Object is not valid"},
    # {-1014,   "File open error"},
    # {-1015,   "Invalid schema type"},
    # {-1016,   "Version mismatch"},
    # {-1017,   "Cannot process the request. Try again later."},
    # {-1018,   "Authorization error"},
    # {-1020,   "The attribute domain must be the set type."},
    # {-1021,   "The domain of a set must be the same data type."},
    # {-2001,   "Memory allocation error"},
    # {-2002,   "Invalid API call"},
    # {-2003,   "Cannot get column info"},
    # {-2004,   "Array initializing error"},
    # {-2005,   "Unknown column type"},
    # {-2006,   "Invalid parameter"},
    # {-2007,   "Invalid array type"},
    # {-2008,   "Invalid type"},
    # {-2009,   "File open error"},
    # {-2010,   "Temporary file open error"},
    # {-2011,   "Glo transfering error"},
    # {0,       "Unknown Error"}
    ######################################

    # cubrid gem compatibility
    alias err_code error_number
    alias err_msg message

    def initialize(msg, server_version = nil, error_number = nil, sql_state = nil)
      @server_version = server_version
      @error_number = error_number
      @sql_state = sql_state ? sql_state.encode(**ENCODE_OPTS) : nil

      super msg
    end
  end
end
