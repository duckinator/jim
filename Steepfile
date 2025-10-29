D = Steep::Diagnostic

target :lib do
  check "lib"
  signature "sig"
  ignore_signature "sig/test"

  library "date"
  library "digest"
  library "etc"
  library "fileutils"
  library "io-console"
  library "json"
  library "net-http"
  library "optparse"
  library "pathname"
  library "pp"
  #library "prism"
  library "stringio"
  library "uri"
  library "yaml"
  library "zlib"

  # ignore "lib/templates/*.rb"

  configure_code_diagnostics(D::Ruby.default)      # `default` diagnostics setting (applies by default)
  # configure_code_diagnostics(D::Ruby.strict)       # `strict` diagnostics setting
  # configure_code_diagnostics(D::Ruby.lenient)      # `lenient` diagnostics setting
  # configure_code_diagnostics(D::Ruby.silent)       # `silent` diagnostics setting
  # configure_code_diagnostics do |hash|             # You can setup everything yourself
  #   # Apparently UnsafeSpec metaprograms too hard and confuses it.
  #   hash[D::Ruby::NoMethod] = :information
  # end
end
