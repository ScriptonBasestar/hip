# frozen_string_literal: true

module Hip
  Error = Class.new(StandardError)

  class VersionMismatchError < Hip::Error
  end
end
