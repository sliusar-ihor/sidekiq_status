# -*- encoding : utf-8 -*-
module SidekiqStatus
  module Worker
    def self.included(base)
      base.class_eval do
        include Sidekiq::Worker

        include(InstanceMethods)

        base.define_singleton_method(:new) do |*args, &block|
          super(*args, &block).extend(Prepending)
        end
      end
    end

    module Prepending
      def perform(*args)
        status_job_id = self.class.respond_to?(:status_job_id) ? self.class.status_job_id(jid, args) : jid
        @status_container = SidekiqStatus::Container.load(status_job_id) rescue nil
        return super(*args) unless @status_container

        begin
          catch(:killed) do
            set_status('working')
            super(*args)
            set_status('complete')
          end
        rescue Exception => exc
          set_status('failed', exc.class.name + ': ' + exc.message + "   \n\n " + exc.backtrace.join("\n    "))
          raise exc
        end
      end
    end

    module InstanceMethods
      def status_container
        return nil unless @status_container

        kill if @status_container.kill_requested?
        @status_container
      end
      alias_method :sc, :status_container

      def kill
        # NOTE: status_container below should be accessed by instance var instead of an accessor method
        # because the second option will lead to infinite recursing
        @status_container.kill
        throw(:killed)
      end

      def set_status(status, message = nil)
        self.sc.update_attributes('status' => status) if self.sc
      end

      def at(at, message = nil)
        self.sc.update_attributes('at' => at, 'message' => message) if self.sc
      end

      def total=(total)
        self.sc.update_attributes('total' => total)
      end

      def payload=(payload)
        self.sc.update_attributes('payload' => payload)
      end
    end
  end
end
