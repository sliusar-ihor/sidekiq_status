require_relative 'helpers'

module SidekiqStatus
  # Hook into *Sidekiq::Web* Sinatra app which adds a new "/statuses" page
  module Web
    # Location of SidekiqStatus::Web view templates
    VIEW_PATH = File.expand_path('../../../web/views', __FILE__)

    # @param [Sidekiq::Web] app
    def self.registered(app)
      app.helpers Helpers

      app.get '/statuses' do
        # Handle both Sidekiq 8.0+ url_params and older params access for query parameters
        count_param = respond_to?(:url_params) ? url_params('count') : params[:count]
        page_param = respond_to?(:url_params) ? url_params('page') : params[:page]
        order_by_param = respond_to?(:url_params) ? url_params('order_by') : params[:order_by]
        sort_param = respond_to?(:url_params) ? url_params('sort') : params[:sort]

        @count = (count_param || 25).to_i

        @current_page = (page_param || 1).to_i
        @current_page = 1 unless @current_page > 0

        @total_size = SidekiqStatus::Container.size

        pageidx = @current_page - 1
        @statuses = SidekiqStatus::Container.statuses(pageidx * @count, (pageidx + 1) * @count, order_by_param, sort_param)

        erb(sidekiq_status_template(:statuses))
      end

      app.get '/statuses/:jid' do
        # Handle both Sidekiq 8.0+ route_params and older params access for route parameters
        jid = respond_to?(:route_params) ? route_params(:jid) : params[:jid]

        @status = SidekiqStatus::Container.load(jid)
        erb(sidekiq_status_template(:status))
      end

      app.get '/statuses/:jid/kill' do
        # Handle both Sidekiq 8.0+ route_params and older params access for route parameters
        jid = respond_to?(:route_params) ? route_params(:jid) : params[:jid]

        SidekiqStatus::Container.load(jid).request_kill
        redirect_to "#{root_path}statuses"
      end

      app.get '/statuses/delete/all' do
        SidekiqStatus::Container.delete
        redirect_to "#{root_path}statuses"
      end

      app.get '/statuses/delete/complete' do
        SidekiqStatus::Container.delete('complete')
        redirect_to "#{root_path}statuses"
      end

      app.get '/statuses/delete/finished' do
        SidekiqStatus::Container.delete(SidekiqStatus::Container::FINISHED_STATUS_NAMES)
        redirect_to "#{root_path}statuses"
      end
    end
  end
end

require 'sidekiq/web' unless defined?(Sidekiq::Web)

# Support for both Sidekiq 8.0+ and older versions
if defined?(Sidekiq::Web)
  if Sidekiq::Web.respond_to?(:configure)
    # Sidekiq 8.0+ configure API
    Sidekiq::Web.configure do |config|
      config.register(SidekiqStatus::Web,
                      name: 'sidekiq_status',
                      tab: 'Statuses',
                      index: 'statuses',
                      root_dir: File.expand_path("../../web", File.dirname(__FILE__)),
                      asset_paths: ["stylesheets"])
    end
  else
    # Fallback for older Sidekiq versions
    Sidekiq::Web.register(SidekiqStatus::Web)

    # Handle tab registration for older versions
    if Sidekiq::Web.tabs.is_a?(Array)
      # For sidekiq < 2.5
      Sidekiq::Web.tabs << "statuses"
    else
      Sidekiq::Web.tabs["Statuses"] = "statuses"
    end
  end
end