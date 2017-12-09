#!/usr/bin/ruby

require 'rubygems'
require 'bundler/setup'
require 'webrick'
require 'xmlrpc/server'
require_relative 'orbit/db.rb'
require_relative 'orbit/metaweblog_api.rb'
require_relative 'orbit/blogger_api.rb'
require_relative 'orbit/servlet.rb'

options = {}

puts "👋  Welcome to Orbit!\n\n"
puts "Please enter the path to your Hugo site (e.g. '/Users/elliot/Sites/elliotekj.com'):\n"
options['src_path'] = gets.chomp
puts "And the port would you like to run Orbit on (e.g. '4040'):\n"
options['port'] = gets.chomp
puts "And the content folder the posts you want serve live in (e.g. 'post' if you want to serve posts in 'content/post'):\n"
options['content_folder'] = gets.chomp
puts "And the token you would like to use to secure access to the endpoint?\n"
options['token'] = gets.chomp
puts '🕐  Thanks, Orbit is setting up…'

puts options

db = OrbitDB.new(options)
metaweblog_api = MetaWeblogAPI.new(db)
blogger_api = BloggerAPI.new(db)

servlet = OrbitServlet.new(options['token'])
servlet.add_handler('metaWeblog', metaweblog_api)
servlet.add_handler('blogger', blogger_api)

server = WEBrick::HTTPServer.new(:Port => options['port'])
server.mount('/xmlrpc.php', servlet)

['INT', 'TERM', 'HUP'].each { |signal|
  trap(signal) { server.shutdown }
}

puts "🚀  Orbit is running on http://localhost:#{options['port']}/xmlrpc.php!"
server.start
