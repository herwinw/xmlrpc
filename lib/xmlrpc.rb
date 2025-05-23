# frozen_string_literal: false
# == Author and Copyright
#
# Copyright (C) 2001-2004 by Michael Neumann (mailto:mneumann@ntecs.de)
#
# Released under the same term of license as Ruby.
#
# == Overview
#
# XMLRPC is a lightweight protocol that enables remote procedure calls over
# HTTP.  It is defined at http://www.xmlrpc.com.
#
# XMLRPC allows you to create simple distributed computing solutions that span
# computer languages.  Its distinctive feature is its simplicity compared to
# other approaches like SOAP and CORBA.
#
# The Ruby standard library package 'xmlrpc' enables you to create a server that
# implements remote procedures and a client that calls them.  Very little code
# is required to achieve either of these.
#
# == Example
#
# Try the following code.  It calls a standard demonstration remote procedure.
#
#   require 'xmlrpc/client'
#   require 'pp'
#
#   server = XMLRPC::Client.new2("http://xmlrpc-c.sourceforge.net/api/sample.php")
#   result = server.call("sample.sumAndDifference", 5, 3)
#   pp result
#
# == Documentation
#
# See http://www.ntecs.de/ruby/xmlrpc4r/.  There is plenty of detail there to
# use the client and implement a server.
#
# == Features of XMLRPC for Ruby
#
# * Extensions
#   * Introspection
#   * multiCall
#   * optionally nil values and integers larger than 32 Bit
#
# * Server
#   * Standalone XML-RPC server
#   * CGI-based (works with FastCGI)
#   * Rack application
#   * WEBrick servlet
#
# * Client
#   * synchronous/asynchronous calls
#   * Basic HTTP-401 Authentication
#   * HTTPS protocol (SSL)
#
# * Parsers
#   * REXML (XMLParser::REXMLStreamParser)
#     * Not compiled (pure ruby)
#     * See ruby standard library
#   * libxml (LibXMLStreamParser)
#     * Compiled
#     * See https://rubygems.org/gems/libxml-ruby/
#   * nokogiri (NokogiriStreamParser)
#     * Compiled
#     * See https://nokogiri.org
#
# * General
#   * possible to choose between REXML (pure Ruby) and LibXML/Nokogiri (compiled) parsers
#   * Marshalling Ruby objects to Hashes and reconstruct them later from a Hash
#   * SandStorm component architecture XMLRPC::Client interface
#
# == Howto
#
# === Client
#
#   require "xmlrpc/client"
#
#   # Make an object to represent the XML-RPC server.
#   server = XMLRPC::Client.new( "xmlrpc-c.sourceforge.net", "/api/sample.php")
#
#   # Call the remote server and get our result
#   result = server.call("sample.sumAndDifference", 5, 3)
#
#   sum = result["sum"]
#   difference = result["difference"]
#
#   puts "Sum: #{sum}, Difference: #{difference}"
#
# === XMLRPC::Client with XML-RPC fault-structure handling
#
# There are two possible ways, of handling a fault-structure:
#
# ==== by catching a XMLRPC::FaultException exception
#
#   require "xmlrpc/client"
#
#   # Make an object to represent the XML-RPC server.
#   server = XMLRPC::Client.new( "xmlrpc-c.sourceforge.net", "/api/sample.php")
#
#   begin
#     # Call the remote server and get our result
#     result = server.call("sample.sumAndDifference", 5, 3)
#
#     sum = result["sum"]
#     difference = result["difference"]
#
#     puts "Sum: #{sum}, Difference: #{difference}"
#
#   rescue XMLRPC::FaultException => e
#     puts "Error: "
#     puts e.faultCode
#     puts e.faultString
#   end
#
# ==== by calling "call2" which returns a boolean
#
#   require "xmlrpc/client"
#
#   # Make an object to represent the XML-RPC server.
#   server = XMLRPC::Client.new( "xmlrpc-c.sourceforge.net", "/api/sample.php")
#
#   # Call the remote server and get our result
#   ok, result = server.call2("sample.sumAndDifference", 5, 3)
#
#   if ok
#     sum = result["sum"]
#     difference = result["difference"]
#
#     puts "Sum: #{sum}, Difference: #{difference}"
#   else
#     puts "Error: "
#     puts result.faultCode
#     puts result.faultString
#   end
#
# === Using XMLRPC::Client::Proxy
#
# You can create a Proxy object onto which you can call methods. This way it
# looks nicer. Both forms, _call_ and _call2_ are supported through _proxy_ and
# _proxy2_.  You can additionally give arguments to the Proxy, which will be
# given to each XML-RPC call using that Proxy.
#
#   require "xmlrpc/client"
#
#   # Make an object to represent the XML-RPC server.
#   server = XMLRPC::Client.new( "xmlrpc-c.sourceforge.net", "/api/sample.php")
#
#   # Create a Proxy object
#   sample = server.proxy("sample")
#
#   # Call the remote server and get our result
#   result = sample.sumAndDifference(5,3)
#
#   sum = result["sum"]
#   difference = result["difference"]
#
#   puts "Sum: #{sum}, Difference: #{difference}"
#
# === CGI-based server using XMLRPC::CGIServer
#
# There are also two ways to define handler, the first is
# like C/PHP, the second like Java, of course both ways
# can be mixed:
#
# ==== C/PHP-like (handler functions)
#
#   require "xmlrpc/server"
#
#   s = XMLRPC::CGIServer.new
#
#   s.add_handler("sample.sumAndDifference") do |a,b|
#     { "sum" => a + b, "difference" => a - b }
#   end
#
#   s.serve
#
# ==== Java-like (handler classes)
#
#   require "xmlrpc/server"
#
#   s = XMLRPC::CGIServer.new
#
#   class MyHandler
#     def sumAndDifference(a, b)
#       { "sum" => a + b, "difference" => a - b }
#     end
#   end
#
#   # NOTE: Security Hole (read below)!!!
#   s.add_handler("sample", MyHandler.new)
#   s.serve
#
#
# To return a fault-structure you have to raise an XMLRPC::FaultException e.g.:
#
#   raise XMLRPC::FaultException.new(3, "division by Zero")
#
# ===== Security Note
#
# From Brian Candler:
#
#   Above code sample has an extremely nasty security hole, in that you can now call
#   any method of 'MyHandler' remotely, including methods inherited from Object
#   and Kernel! For example, in the client code, you can use
#
#     puts server.call("sample.send","`","ls")
#
#   (backtick being the method name for running system processes). Needless to
#   say, 'ls' can be replaced with something else.
#
#   The version which binds proc objects (or the version presented below in the next section)
#   doesn't have this problem, but people may be tempted to use the second version because it's
#   so nice and 'Rubyesque'. I think it needs a big red disclaimer.
#
#
# From Michael:
#
# A solution is to undef insecure methods or to use
# XMLRPC::Service::PublicInstanceMethodsInterface as shown below:
#
#   class MyHandler
#     def sumAndDifference(a, b)
#       { "sum" => a + b, "difference" => a - b }
#     end
#   end
#
#   # ... server initialization ...
#
#   s.add_handler(XMLRPC::iPIMethods("sample"), MyHandler.new)
#
#   # ...
#
# This adds only public instance methods explicitly declared in class MyHandler
# (and not those inherited from any other class).
#
# ==== With interface declarations
#
# Code sample from the book Ruby Developer's Guide:
#
#   require "xmlrpc/server"
#
#   class Num
#     INTERFACE = XMLRPC::interface("num") {
#       meth 'int add(int, int)', 'Add two numbers', 'add'
#       meth 'int div(int, int)', 'Divide two numbers'
#     }
#
#     def add(a, b) a + b end
#     def div(a, b) a / b end
#   end
#
#
#   s = XMLRPC::CGIServer.new
#   s.add_handler(Num::INTERFACE, Num.new)
#   s.serve
#
# === Standalone XMLRPC::Server
#
# Same as CGI-based server, the only difference being
#
#   server = XMLRPC::CGIServer.new
#
# must be changed to
#
#   server = XMLRPC::Server.new(8080)
#
# if you want a server listening on port 8080.
# The rest is the same.
#
# === Choosing a different XMLParser or XMLWriter
#
# The examples above all use the default parser (which is now since 1.8
# XMLParser::REXMLStreamParser) and a default XMLRPC::XMLWriter.
# If you want to use a different XMLParser, then you have to call the
# ParserWriterChooseMixin#set_parser method of XMLRPC::Client instances
# or instances of subclasses of XMLRPC::BasicServer or by editing
# xmlrpc/config.rb.
#
# XMLRPC::Client Example:
#
#   # ...
#   client = XMLRPC::Client.new( "xmlrpc-c.sourceforge.net", "/api/sample.php")
#   client.set_parser(XMLRPC::XMLParser::XMLParser.new)
#   # ...
#
# XMLRPC::Server Example:
#
#   # ...
#   server = XMLRPC::CGIServer.new
#   server.set_parser(XMLRPC::XMLParser::XMLParser.new)
#   # ...
#
#
# You can change the XML-writer by calling method ParserWriterChooseMixin#set_writer.
module XMLRPC
  VERSION = "0.3.4"
end
