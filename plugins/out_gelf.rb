module Fluent

class GELFOutput < BufferedOutput

  Plugin.register_output("gelf", self)    

  config_param :use_record_host, :bool, :default => false
  config_param :add_msec_time, :bool, :default => false
  config_param :host, :string, :default => nil
  config_param :port, :integer, :default => 12201

  def initialize
    super
    require "gelf"
  end

  def configure(conf)
    super
    raise ConfigError, "'host' parameter required" unless conf.has_key?('host')
  end

  def start
    super
    @conn = GELF::Notifier.new(@host, @port, 'WAN', {:facility => 'fluentd'})

    # Errors are not coming from Ruby so we use direct mapping
    @conn.level_mapping = 'direct'
    # file and line from Ruby are in this class, not relevant
    @conn.collect_file_and_line = false
  end

  def shutdown
    super
  end

  def format(tag, time, record)
    gelfentry = { :timestamp => time}

    record.each_pair do |k,v|
      case k
      when 'version' then
        gelfentry[:_version] = v
      when 'timestamp' then
        gelfentry[:_timestamp] = v
      when 'host' then
        gelfentry[:_hostname] = v
      when 'level' then
        case v.downcase
        # emergency and alert aren't supported by gelf-rb
        when '0', 'emergency' then gelfentry[:level] = GELF::UNKNOWN
        when '1', 'alert' then gelfentry[:level] = GELF::UNKNOWN
        when '2', 'critical', 'crit' then gelfentry[:level] = GELF::FATAL
        when '3', 'error', 'err' then gelfentry[:level] = GELF::ERROR
        when '4', 'warning', 'warn' then gelfentry[:level] = GELF::WARN
        # gelf-rb also skips notice
        when '5', 'notice' then gelfentry[:level] = GELF::INFO
        when '6', 'informational', 'info' then gelfentry[:level] = GELF::INFO
        when '7', 'debug' then gelfentry[:level] = GELF::DEBUG
        else gelfentry[:_level] = v
        end
      when 'msec' then
        # msec must be three digits (leading/trailing zeroes)
        if @add_msec_time then 
          gelfentry[:timestamp] = (time.to_s + "." + v).to_f
        else
          gelfentry[:_msec] = v
        end
      when 'message' then
        gelfentry[:short_message] = v
      when 'ident' then
        gelfentry[:_ident] = v
      when '@log_name' then
        gelfentry[:_log_name] = v
      else
        gelfentry['_'+k] = v
      end
    end

    gelfentry[:_raw_message] = record.to_json
    
    gelfentry.to_msgpack
  end

  def write(chunk)
    chunk.msgpack_each do |data|
      @conn.notify!(data)
    end
  end

end


end

# vim: sw=2 ts=2 et
