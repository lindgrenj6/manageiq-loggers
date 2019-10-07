module ManageIQ
  module Loggers
    class Journald < Base
      attr_accessor :message_id

      def initialize(logdev = nil, *args)
        require "systemd-journal"
        super(logdev, *args)
        self.formatter = Formatter.new
        self.message_id = SecureRandom.uuid.tr('-','')
      end

      def filename
        "journald"
      end

      def add(severity, message = nil, progname = nil)
        severity ||= Logger::UNKNOWN
        return true if severity < @level

        progname ||= @progname

        if message.nil?
          if block_given?
            message = yield
          else
            message = progname
            progname = @progname
          end
        end

        message = formatter.call(format_severity(severity), progname, message)
        caller_object = caller_locations.last

        Systemd::Journal.message(
          :message           => message,
          :message_id        => message_id,
          :priority          => log_level_map[severity],
          :application       => 'cfme',
          :syslog_identifier => 'cfme',
          :syslog_facility   => 'local3',
          :code_line         => caller_object.lineno,
          :code_file         => caller_object.absolute_path
        )
      end

      private

      def log_level_map
        @log_level_map ||= {
          Logger::UNKNOWN => Systemd::Journal::LOG_ALERT,
          Logger::FATAL   => Systemd::Journal::LOG_CRIT,
          Logger::ERROR   => Systemd::Journal::LOG_ERR,
          Logger::WARN    => Systemd::Journal::LOG_WARNING,
          Logger::INFO    => Systemd::Journal::LOG_INFO,
          Logger::DEBUG   => Systemd::Journal::LOG_DEBUG,
        }
      end

      class Formatter < Base::Formatter
        def call(severity, progname, msg)
          msg = prefix_task_id(msg2str(msg)).truncate(Base::MAX_LOG_LINE_LENGTH)
          "%5s -- %s: %s\n" % [severity, progname, msg]
        end
      end
    end
  end
end
