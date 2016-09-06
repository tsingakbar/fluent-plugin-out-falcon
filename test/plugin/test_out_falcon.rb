# -*- coding: utf-8 -*-
require 'uri'
require 'yajl'
require 'fluent/test/falcon_output_test'
require 'fluent/plugin/out_falcon'


TEST_LISTEN_PORT = 5126


class FalconOutputTestBase < Test::Unit::TestCase
  # setup / teardown for servers
  def setup
    Fluent::Test.setup
    @posts = []
    @puts = []
    @prohibited = 0
    @requests = 0
    @auth = false
    @dummy_server_thread = Thread.new do
      srv = if ENV['VERBOSE']
              WEBrick::HTTPServer.new({:BindAddress => '127.0.0.1', :Port => TEST_LISTEN_PORT})
            else
              logger = WEBrick::Log.new('/dev/null', WEBrick::BasicLog::DEBUG)
              WEBrick::HTTPServer.new({:BindAddress => '127.0.0.1', :Port => TEST_LISTEN_PORT, :Logger => logger, :AccessLog => []})
            end
      begin
        allowed_methods = %w(POST PUT)
        srv.mount_proc('/api/') { |req,res|
          @requests += 1
          unless allowed_methods.include? req.request_method
            res.status = 405
            res.body = 'request method mismatch'
            next
          end
          if @auth and req.header['authorization'][0] == 'Basic YWxpY2U6c2VjcmV0IQ==' # pattern of user='alice' passwd='secret!'
            # ok, authorized
          elsif @auth
            res.status = 403
            @prohibited += 1
            next
          else
            # ok, authorization not required
          end

          record = {:auth => nil}
          if req.content_type == 'application/json'
            record[:json] = Yajl.load(req.body)
          else
            record[:form] = Hash[*(req.body.split('&').map{|kv|kv.split('=')}.flatten)]
          end

          instance_variable_get("@#{req.request_method.downcase}s").push(record)

          res.status = 200
        }
        srv.mount_proc('/') { |req,res|
          res.status = 200
          res.body = 'running'
        }
        srv.start
      ensure
        srv.shutdown
      end
    end

    # to wait completion of dummy server.start()
    require 'thread'
    cv = ConditionVariable.new
    watcher = Thread.new {
      connected = false
      while not connected
        begin
          get_content('localhost', TEST_LISTEN_PORT, '/')
          connected = true
        rescue Errno::ECONNREFUSED
          sleep 0.1
        rescue StandardError => e
          p e
          sleep 0.1
        end
      end
      cv.signal
    } 
    mutex = Mutex.new
    mutex.synchronize {
      cv.wait(mutex)
    } 
  end

  def test_dummy_server
    host = '127.0.0.1'
    port = TEST_LISTEN_PORT
    client = Net::HTTP.start(host, port)

    assert_equal '200', client.request_get('/').code
    assert_equal '200', client.request_post('/api/service/metrics/hoge', 'number=1&mode=gauge').code

    assert_equal 1, @posts.size

    assert_equal '1', @posts[0][:form]['number']
    assert_equal 'gauge', @posts[0][:form]['mode']
    assert_nil @posts[0][:auth]

    @auth = true

    assert_equal '403', client.request_post('/api/service/metrics/pos', 'number=30&mode=gauge').code

    req_with_auth = lambda do |number, mode, user, pass|
      url = URI.parse("http://#{host}:#{port}/api/service/metrics/pos")
      req = Net::HTTP::Post.new(url.path)
      req.basic_auth user, pass
      req.set_form_data({'number'=>number, 'mode'=>mode})
      req
    end

    assert_equal '403', client.request(req_with_auth.call(500, 'count', 'alice', 'wrong password!')).code

    assert_equal '403', client.request(req_with_auth.call(500, 'count', 'alice', 'wrong password!')).code

    assert_equal 1, @posts.size

    assert_equal '200', client.request(req_with_auth.call(500, 'count', 'alice', 'secret!')).code

    assert_equal 2, @posts.size

  end

  def teardown
    @dummy_server_thread.kill
    @dummy_server_thread.join
  end
end

class FalconOutputTest < FalconOutputTestBase
  CONFIG_FORM = %[
    endpoint_url http://127.0.0.1:#{TEST_LISTEN_PORT}/api/
    serializer form
  ]

  CONFIG_JSON = %[
    endpoint_url http://127.0.0.1:#{TEST_LISTEN_PORT}/api/
    serializer json
  ]

  CONFIG_PUT = %[
    endpoint_url http://127.0.0.1:#{TEST_LISTEN_PORT}/api/
    serializer form
    http_method put
  ]

  CONFIG_HTTP_ERROR = %[
    endpoint_url https://127.0.0.1:#{TEST_LISTEN_PORT + 1}/api/
    serializer form
  ]

  CONFIG_HTTP_ERROR_SUPPRESSED = %[
    endpoint_url https://127.0.0.1:#{TEST_LISTEN_PORT + 1}/api/
    serializer form
    raise_on_error false
  ]

  RATE_LIMIT_MSEC = 1200

  CONFIG_RATE_LIMIT = %[
    endpoint_url http://127.0.0.1:#{TEST_LISTEN_PORT}/api/
    serializer form
    rate_limit_msec #{RATE_LIMIT_MSEC}
  ]

  def create_driver(conf=CONFIG_FORM, tag='test.metrics')
    Fluent::Test::OutputTestDriver.new(Fluent::FalconOutput, tag).configure(conf)
  end

  def test_configure
    d = create_driver
    assert_equal "http://127.0.0.1:#{TEST_LISTEN_PORT}/api/", d.instance.endpoint_url
    assert_equal :form, d.instance.serializer

    d = create_driver CONFIG_JSON
    assert_equal "http://127.0.0.1:#{TEST_LISTEN_PORT}/api/", d.instance.endpoint_url
    assert_equal :json, d.instance.serializer
  end

  def test_emit_form
    d = create_driver
    d.emit({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1, 'binary' => "\xe3\x81\x82".force_encoding("ascii-8bit") })
    d.run

    assert_equal 1, @posts.size
    record = @posts[0]

    assert_equal '50', record[:form]['field1']
    assert_equal '20', record[:form]['field2']
    assert_equal '10', record[:form]['field3']
    assert_equal '1', record[:form]['otherfield']
    assert_equal URI.encode_www_form_component("あ").upcase, record[:form]['binary'].upcase
    assert_nil record[:auth]

    d.emit({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
    d.run

    assert_equal 2, @posts.size
  end

  def test_emit_form_put
    d = create_driver CONFIG_PUT
    d.emit({ 'field1' => 50 })
    d.run

    assert_equal 0, @posts.size
    assert_equal 1, @puts.size
    record = @puts[0]

    assert_equal '50', record[:form]['field1']
    assert_nil record[:auth]

    d.emit({ 'field1' => 50 })
    d.run

    assert_equal 0, @posts.size
    assert_equal 2, @puts.size
  end

  def test_emit_json
    binary_string = "\xe3\x81\x82".force_encoding("ascii-8bit")
    d = create_driver CONFIG_JSON
    d.emit({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1, 'binary' => binary_string })
    d.run

    assert_equal 1, @posts.size
    record = @posts[0]

    assert_equal 50, record[:json][0]['field1']
    assert_equal 20, record[:json][0]['field2']
    assert_equal 10, record[:json][0]['field3']
    assert_equal 1, record[:json][0]['otherfield']
    assert_equal binary_string, record[:json][0]['binary'].force_encoding("ascii-8bit")
    assert_nil record[:auth]
  end

  def test_http_error_is_raised
    d = create_driver CONFIG_HTTP_ERROR
    assert_raise Errno::ECONNREFUSED do
      d.emit({ 'field1' => 50 })
    end
  end

  def test_http_error_is_suppressed_with_raise_on_error_false
    d = create_driver CONFIG_HTTP_ERROR_SUPPRESSED
    d.emit({ 'field1' => 50 })
    d.run
    # drive asserts the next output chain is called;
    # so no exception means our plugin handled the error

    assert_equal 0, @requests
  end

  def test_rate_limiting
    d = create_driver CONFIG_RATE_LIMIT
    record = { :k => 1 }

    last_emit = _current_msec
    d.emit(record)
    d.run

    assert_equal 1, @posts.size

    d.emit({})
    d.run
    assert last_emit + RATE_LIMIT_MSEC > _current_msec, "Still under rate limiting interval"
    assert_equal 1, @posts.size

    wait_msec = 500
    sleep (last_emit + RATE_LIMIT_MSEC - _current_msec + wait_msec) * 0.001
    
    assert last_emit + RATE_LIMIT_MSEC < _current_msec, "No longer under rate limiting interval"
    d.emit(record)
    d.run
    assert_equal 2, @posts.size
  end

  def _current_msec
    Time.now.to_f * 1000
  end
  
  def test_auth
    @auth = true # enable authentication of dummy server

    d = create_driver(CONFIG_FORM, 'test.metrics')
    d.emit({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
    d.run # failed in background, and output warn log

    assert_equal 0, @posts.size
    assert_equal 1, @prohibited

    d = create_driver(CONFIG_FORM + %[
      authentication basic
      username alice
      password wrong_password
    ], 'test.metrics')
    d.emit({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
    d.run # failed in background, and output warn log

    assert_equal 0, @posts.size
    assert_equal 2, @prohibited

    d = create_driver(CONFIG_FORM + %[
      authentication basic
      username alice
      password secret!
    ], 'test.metrics')
    d.emit({ 'field1' => 50, 'field2' => 20, 'field3' => 10, 'otherfield' => 1 })
    d.run # failed in background, and output warn log

    assert_equal 1, @posts.size
    assert_equal 2, @prohibited
  end

end
