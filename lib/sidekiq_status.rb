# -*- encoding : utf-8 -*-
require 'sidekiq'

require 'securerandom'
require "sidekiq_status/version"
require "sidekiq_status/client_middleware"
require "sidekiq_status/container"
require "sidekiq_status/worker"

Sidekiq.configure_client do |config|
  config.client_middleware do |chain|
    chain.add SidekiqStatus::ClientMiddleware
  end
end

require 'sidekiq_status/web' if defined?(Sidekiq::Web)