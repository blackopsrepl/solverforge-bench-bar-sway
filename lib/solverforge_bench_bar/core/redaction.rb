# frozen_string_literal: true

module SolverForgeBenchBar
  module Core
    module Redaction
      DATABASE_URL = %r{\bpostgres(?:ql)?://[^\s"'<>]+}i
      URL_OPTION = /(--(?:postgres|database)-url(?:=|\s+))\S+/i
      PASSWORD_FIELD = /((?:password|passwd|pwd)\s*[=:]\s*)[^\s,;]+/i
      ABSOLUTE_PATH = %r{(?<![[:alnum:]/])/(?!/)[^\s"'<>]+}

      module_function

      def clean(value, limit: 500)
        text = value.to_s
          .gsub(DATABASE_URL, "<redacted-database-url>")
          .gsub(URL_OPTION, "\\1<redacted>")
          .gsub(PASSWORD_FIELD, "\\1<redacted>")
          .gsub(ABSOLUTE_PATH, "<redacted-path>")
          .gsub(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/, "")
          .strip
        text.length > limit ? "#{text[0, limit - 1]}…" : text
      end
    end
  end
end
