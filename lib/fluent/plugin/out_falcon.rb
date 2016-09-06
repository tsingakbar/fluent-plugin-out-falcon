class Fluent::FalconOutput < Fluent::Output
  Fluent::Plugin.register_output('falcon', self)

  def initialize
    super
    require 'net/http'
    require 'uri'
    require 'yajl'
  end

  config_param :records, :string

  # Endpoint URL ex. localhost.local/api/
  config_param :endpoint_url, :string

  # Simple rate limiting: ignore any records within `rate_limit_msec`
  # since the last one.
  config_param :rate_limit_msec, :integer, :default => 0

  # Raise errors that were rescued during HTTP requests?
  config_param :raise_on_error, :bool, :default => true

  # nil | 'none' | 'basic'
  config_param :authentication, :string, :default => nil 
  config_param :username, :string, :default => ''
  config_param :password, :string, :default => '', :secret => true

  def configure(conf)
    super

    @auth = case @authentication
            when 'basic' then :basic
            else
              :none
            end
  end

  def start
    super
  end

  def shutdown
    super
  end

  def format_url(tag, time, record)
    @endpoint_url
  end

  def set_body(req, tag, time, record)
    req.body = Yajl.dump(eval(@records))
    req['Content-Type'] = 'application/json'
    req
  end

  def set_header(req, tag, time, record)
    req
  end

  def create_request(tag, time, record)
    url = format_url(tag, time, record)
    uri = URI.parse(url)
    req = Net::HTTP.const_get('Post').new(uri.path)
    set_body(req, tag, time, record)
    set_header(req, tag, time, record)
    return req, uri
  end

  def send_request(req, uri)    
    is_rate_limited = (@rate_limit_msec != 0 and not @last_request_time.nil?)
    if is_rate_limited and ((Time.now.to_f - @last_request_time) * 1000.0 < @rate_limit_msec)
      $log.info('Dropped request due to rate limiting')
      return
    end
    
    res = nil

    begin
      if @auth and @auth == :basic
        req.basic_auth(@username, @password)
      end
      @last_request_time = Time.now.to_f
      res = Net::HTTP.new(uri.host, uri.port).start {|http| http.request(req) }
    rescue => e # rescue all StandardErrors
      # server didn't respond
      $log.warn "Net::HTTP.#{req.method.capitalize} raises exception: #{e.class}, '#{e.message}'"
      raise e if @raise_on_error
    else
       unless res and res.is_a?(Net::HTTPSuccess)
          res_summary = if res
                           "#{res.code} #{res.message} #{res.body}"
                        else
                           "res=nil"
                        end
          $log.warn "failed to #{req.method} #{uri} (#{res_summary})"
       end #end unless
    end # end begin
  end # end send_request

  def handle_record(tag, time, record)
    req, uri = create_request(tag, time, record)
    send_request(req, uri)
  end

  def emit(tag, es, chain)
    es.each do |time, record|
      handle_record(tag, time, record)
    end
    chain.next
  end
end
