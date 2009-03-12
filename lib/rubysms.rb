#!/usr/bin/env ruby
#:title:RubySMS
#--
# vim: noet
#++


# during development, it's important to EXPLODE
# as early as possible when something goes wrong
Thread.abort_on_exception = true
Thread.current["name"] = "main"


# everything (should) live
# in this tidy namespace
module SMS
	
	# store this directory name; everything
	# inside here is considered to be part
	# of the rubysms framework, so can be
	# ignored in application backtraces
	Root = File.dirname(__FILE__)
end


# load all supporting files
dir = SMS::Root + "/rubysms"
require "#{dir}/logger.rb"
require "#{dir}/router.rb"
require "#{dir}/thing.rb"
require "#{dir}/application.rb"
require "#{dir}/backend.rb"
require "#{dir}/errors.rb"
require "#{dir}/person.rb"


# include RubyGSM via the gem. we need this regardless
# of whether we are running a GSM backend, because we
# use the message classes to pass around SMS
#
# attempt to load rubygsm using relative paths first,
# so we can easily run on the trunk by cloning from
# github. the dir structure should look something like:
#
# projects
#  - rubygsms
#  - rubygsm
begin
	dev_dir = "#{dir}/../../../rubygsm"
	dev_path = "#{dev_dir}/lib/rubygsm.rb"
	require File.expand_path(dev_path)
	
rescue LoadError
	begin
	
		# couldn't load via relative
		# path, so try loading the gem
		require "rubygems"
		require "rubygsm"
		
	rescue LoadError
		
		# no gem either. this is alright, since rubysms
		# doesn't *require* rubygsm (we can still develop
		# locally), but we won't be able to send/receive
		# SMS via a GSM modem without it
		
	end
end


# message classes
require "#{dir}/message/incoming.rb"
require "#{dir}/message/outgoing.rb"


# all backends (hard coded, for now)
require "#{dir}/backend/http.rb"
require "#{dir}/backend/drb.rb"


# if rubygsm was loaded (via path
# or gem), add the gsm backend
if Object.const_defined?(:Gsm)
	require "#{dir}/backend/gsm.rb"
end
