ENV['RAILS_ENV'] ||= 'development'

require_relative 'boot'
require 'rails'

# Load minimal Rails components
require 'active_record/railtie'

Bundler.require(*Rails.groups)

module SqlServerTest
  class Application < Rails::Application
    config.load_defaults 8.0
    config.root = File.expand_path('..', __dir__)
    config.eager_load_paths << File.join(config.root, 'app', 'models')
  end
end

Rails.application.initialize!
