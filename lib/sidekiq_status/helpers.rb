module SidekiqStatus
  module Helpers
    VIEW_PATH = File.expand_path('../../../web/views', __FILE__)

    def sidekiq_status_template(name)
      path = File.join(VIEW_PATH, name.to_s) + ".erb"
      File.open(path).read
    end

    def redirect_to(subpath)
      if respond_to?(:to)
        # Sinatra-based web UI
        redirect to(subpath)
      else
        # Non-Sinatra based web UI (Sidekiq 4.2+)
        redirect "#{root_path}#{subpath}"
      end
    end

    # Renamed to avoid conflict with Sidekiq 8.0's url_params method
    def build_url_params(options)
      # Handle both Sidekiq 8.0+ and older parameter access
      current_params = if respond_to?(:url_params) && defined?(super)
                         # In Sidekiq 8.0+, we need to manually reconstruct params from url_params
                         # This is a simplified approach - adjust based on your actual needs
                         params.respond_to?(:merge) ? params : {}
                       else
                         params
                       end

      current_params.merge(options).map do |key, value|
        "#{key}=#{CGI.escape(value.to_s)}"
      end.compact.join("&")
    end
  end
end
