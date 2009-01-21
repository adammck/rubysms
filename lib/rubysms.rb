#!/usr/bin/env ruby
# vim: noet


# during development, it's important to EXPLODE
# as early as possible when something goes wrong
Thread.abort_on_exception = true
Thread.current["name"] = "main"


# everything (should) live
# in this tidy namespace
module SMS
end


# all library files should live in here
dir = File.dirname(__FILE__) + "/rubysms/"


# load all supporting files
require "#{dir}/logger.rb"
require "#{dir}/router.rb"
require "#{dir}/thing.rb"
require "#{dir}/application.rb"
require "#{dir}/backend.rb"
require "#{dir}/errors.rb"


# include RubyGSM via the gem. we need this regardless
# of whether we are running a GSM backend, because we
# use the message classes to pass around SMS
#require "rubygems"
#require "rubygsm"

# or via ../ for the time being
rubygsm_dir = "#{dir}/../../../rubygsm"
require File.expand_path("#{rubygsm_dir}/lib/rubygsm.rb")


# message classes
require "#{dir}/message/incoming.rb"
require "#{dir}/message/outgoing.rb"


# all backends (hard coded, for now)
require "#{dir}/backend/http.rb"
require "#{dir}/backend/drb.rb"
require "#{dir}/backend/gsm.rb"