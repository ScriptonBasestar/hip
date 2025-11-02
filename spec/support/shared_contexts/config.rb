# frozen_string_literal: true

shared_context "hip config", :config do
  before do
    Hip.config.to_h.merge!(config)
  end
end
