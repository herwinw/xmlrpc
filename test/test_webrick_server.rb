# coding: utf-8
# frozen_string_literal: false

require 'test/unit'
require 'webrick'
require_relative 'webrick_testing'
require "xmlrpc/server"
require 'xmlrpc/client'

class Test_Webrick < Test::Unit::TestCase
  include WEBrick_Testing

  def create_servlet(server)
    s = XMLRPC::WEBrickServlet.new

    basic_auth = WEBrick::HTTPAuth::BasicAuth.new(
      :Realm => 'auth',
      :UserDB => WEBrick::HTTPAuth::Htpasswd.new(File.expand_path('./htpasswd', File.dirname(__FILE__))),
      :Logger => server.logger,
    )

    class << s; self end.send(:define_method, :service) {|req, res|
      basic_auth.authenticate(req, res)
      super(req, res)
    }

    s.add_handler("test.add") do |a, b|
      a + b
    end

    s.add_handler("test.div") do |a, b|
      if b == 0
        raise XMLRPC::FaultException.new(1, "division by zero")
      else
        a / b
      end
    end

    s.set_default_handler do |name, *args|
      raise XMLRPC::FaultException.new(-99, "Method #{name} missing" +
            " or wrong number of parameters!")
    end

    s.add_introspection

    return s
  end

  def setup_http_server_option(use_ssl)
    option = {
      :BindAddress => "localhost",
      :Port => 0,
      :SSLEnable => use_ssl,
    }
    if use_ssl
      require 'webrick/https'
      option.update(
        :SSLVerifyClient => ::OpenSSL::SSL::VERIFY_NONE,
        :SSLCertName => []
      )
    end

    option
  end

  def test_client_server
    # NOTE: I don't enable SSL testing as this hangs
    use_ssl = false
    option = setup_http_server_option(use_ssl)
    with_server(option, method(:create_servlet)) do |addr|
      @s = XMLRPC::Client.new3(:host => addr.ip_address, :port => addr.ip_port, :use_ssl => use_ssl)
      @s.user = 'admin'
      @s.password = 'admin'
      silent do
        do_test
      end
      @s.http.finish
      @s = XMLRPC::Client.new3(:host => addr.ip_address, :port => addr.ip_port, :use_ssl => use_ssl)
      @s.user = '01234567890123456789012345678901234567890123456789012345678901234567890123456789'
      @s.password = 'guest'
      silent do
        do_test
      end
      @s.http.finish
    end
  end

  def silent
    begin
      back, $VERBOSE = $VERBOSE, nil
      yield
    ensure
      $VERBOSE = back
    end
  end

  def do_test
    # simple call
    assert_equal(9, @s.call('test.add', 4, 5))

    # fault exception
    assert_raise(XMLRPC::FaultException) { @s.call('test.div', 1, 0) }

    # fault exception via call2
    ok, param = @s.call2('test.div', 1, 0)
    assert_equal(false, ok)
    assert_instance_of(XMLRPC::FaultException, param)
    assert_equal(1, param.faultCode)
    assert_equal('division by zero', param.faultString)

    # call2 without fault exception
    ok, param = @s.call2('test.div', 10, 5)
    assert_equal(true, ok)
    assert_equal(param, 2)

    # introspection
    assert_equal(["test.add", "test.div", "system.listMethods", "system.methodSignature", "system.methodHelp"],
                 @s.call("system.listMethods"))

    # default handler (missing handler)
    ok, param = @s.call2('test.nonexisting')
    assert_equal(false, ok)
    assert_equal(-99, param.faultCode)

    # default handler (wrong number of arguments)
    ok, param = @s.call2('test.add', 1, 2, 3)
    assert_equal(false, ok)
    assert_equal(-99, param.faultCode)

    # multibyte characters
    assert_equal("あいうえおかきくけこ", @s.call('test.add', "あいうえお", "かきくけこ"))
  end
end
