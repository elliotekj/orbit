#!/usr/bin/ruby

require 'rubygems'
require 'bundler/setup'
require 'webrick'
require 'xmlrpc/server'
require_relative 'orbit/db.rb'
require_relative 'orbit/metaweblog_api.rb'
require_relative 'orbit/blogger_api.rb'
require_relative 'orbit/servlet.rb'

puts 'Starting Orbit…'

token = 'e1b22248-f2b7-4009-bfd0-2ceb743075b9'

db = OrbitDB.new('/Users/elliot/Desktop/elliotekj-com-hugo')
metaWeblog_api = MetaWeblogAPI.new(db)
blogger_api = BloggerAPI.new

servlet = OrbitServlet.new(token)
servlet.add_handler('metaWeblog', metaWeblog_api)

server = WEBrick::HTTPServer.new(:Port => 4040)
server.mount('/xmlrpc.php', servlet)

['INT', 'TERM', 'HUP'].each { |signal|
  trap(signal) { server.shutdown }
}

server.start
