# frozen_string_literal: true

# Copyright Core DF — Apache License 2.0

module CoreautoResult
  module_function

  def missing_env(vars)
    { status_code: 601, error: "Environment variables #{vars} should be defined" }
  end

  def transport_error(message = 'inaccessible')
    { status_code: 0, error: message }
  end
end
