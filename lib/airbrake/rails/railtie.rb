# frozen_string_literal: true

module Airbrake
  module Rails
    # This railtie works for any Rails application that supports railties (Rails
    # 3.2+ apps). It makes Airbrake Ruby work with Rails and report errors
    # occurring in the application automatically.
    #
    # rubocop:disable Metrics/BlockLength
    class Railtie < ::Rails::Railtie
      initializer('airbrake.middleware') do |app|
        require 'airbrake/rails/railties/middleware_tie'
        Railties::MiddlewareTie.new(app).call
      end

      rake_tasks do
        # Report exceptions occurring in Rake tasks.
        require 'airbrake/rake'

        # Defines tasks such as `airbrake:test` & `airbrake:deploy`.
        require 'airbrake/rake/tasks'
      end

      initializer('airbrake.action_controller') do
        require 'airbrake/rails/railties/action_controller_tie'
        Railties::ActionControllerTie.new.call
      end

      initializer('airbrake.active_record') do
        ActiveSupport.on_load(:active_record, run_once: true) do
          # Reports exceptions occurring in some bugged ActiveRecord callbacks.
          # Applicable only to the versions of Rails lower than 4.2.
          if defined?(::Rails) &&
             Gem::Version.new(::Rails.version) <= Gem::Version.new('4.2')
            require 'airbrake/rails/active_record'
            include Airbrake::Rails::ActiveRecord
          end

          if defined?(ActiveRecord)
            # Send SQL queries.
            require 'airbrake/rails/active_record_subscriber'
            ActiveSupport::Notifications.subscribe(
              'sql.active_record', Airbrake::Rails::ActiveRecordSubscriber.new
            )

            # Filter out parameters from SQL body.
            if ::ActiveRecord::Base.respond_to?(:connection_db_config)
              # Rails 6.1+ deprecates "connection_config" in favor of
              # "connection_db_config", so we need an updated call.
              Airbrake.add_performance_filter(
                Airbrake::Filters::SqlFilter.new(
                  ::ActiveRecord::Base.connection_db_config.configuration_hash[:adapter],
                ),
              )
            else
              Airbrake.add_performance_filter(
                Airbrake::Filters::SqlFilter.new(
                  ::ActiveRecord::Base.connection_config[:adapter],
                ),
              )
            end
          end
        end
      end

      initializer('airbrake.active_job') do
        ActiveSupport.on_load(:active_job, run_once: true) do
          # Reports exceptions occurring in ActiveJob jobs.
          require 'airbrake/rails/active_job'
          include Airbrake::Rails::ActiveJob
        end
      end

      initializer('airbrake.action_cable') do
        ActiveSupport.on_load(:action_cable, run_once: true) do
          # Reports exceptions occurring in ActionCable connections.
          require 'airbrake/rails/action_cable'
        end
      end

      runner do
        at_exit do
          Airbrake.notify_sync($ERROR_INFO) if $ERROR_INFO
        end
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
