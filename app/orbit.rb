#!/usr/bin/ruby

require 'rubygems'
require 'bundler/setup'
require 'optparse'
require 'webrick'
require 'xmlrpc/server'
require_relative 'orbit/db.rb'
require_relative 'orbit/metaweblog_api.rb'
require_relative 'orbit/blogger_api.rb'
require_relative 'orbit/servlet.rb'

options = {}

optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} -s '/path/to/hugo/site' [options]"

  options['src_path'] = nil
  opts.on('-s', '--src-path FOLDER', 'Path to your Hugo site (required)') do |s|
    options['src_path'] = s
  end

  options['content_folder'] = 'post'
  opts.on('-c', '--content-folder FOLDER_NAME', "Name of the folder in \
          `/content` you want Orbit to serve (default: 'post')") do |c|
    options['content_folder'] = c
  end

  options['port'] = 4040
  opts.on('-p', '--port PORT', Integer, 'Port to run Orbit on (default: 4040)') do |p|
    options['port'] = p
  end

  options['token'] = nil
  opts.on('-t', '--token TOKEN', 'Token used for authenticating yourself (optional)') do |t|
    options['token'] = t
  end

  options['update_command'] = nil
  opts.on('-u', '--update-command COMMAND', 'Command run when your site is \
          updated (optional)') do |u|
    options['update_command'] = u
  end
end

optparse.parse!

if options['src_path'].nil? or not File.directory? options['src_path']
  puts 'option --src-path is required must be an existing folder'
  exit 1
end

db = OrbitDB.new(options)
metaweblog_api = MetaWeblogAPI.new(db, options['update_command'])
blogger_api = BloggerAPI.new(db, options['update_command'])

servlet = OrbitServlet.new(options['token'])
servlet.add_handler('metaWeblog', metaweblog_api)
servlet.add_handler('blogger', blogger_api)

server = WEBrick::HTTPServer.new(:Port => options['port'])
server.mount('/xmlrpc', servlet)

['INT', 'TERM', 'HUP'].each do |signal|
  trap(signal) { server.shutdown }
end

server.start
