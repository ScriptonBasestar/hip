# frozen_string_literal: true

module Hip
  class CLI
    class Base < Thor
      def self.exit_on_failure?
        true
      end
    end
  end
end
