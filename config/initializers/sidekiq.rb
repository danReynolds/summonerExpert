Sidekiq.configure_server do |config|
  config.server_middleware do |chain|
    chain.add Sidekiq::Throttler, storage: :redis
  end
  config.redis = { url: 'redis://redis:6379/0', password: ENV['REDIS_PASSWORD'] }
end

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://redis:6379/0', password: ENV['REDIS_PASSWORD'] }
end
