#!/usr/bin/env ruby
# vim: noet


# include rubysms relative to this, rather
# than the rubygem, for the time being
require File.expand_path(
	"#{File.dirname(__FILE__)}/lib/rubysms.rb")


class DemoApp < SMS::App
	
	
	# if the word "test" is received, this method is called with the incoming msg
	# object (see lib/rubysms/message/incoming.rb and lib/rubygsm/msg/incoming.rb)
	# as the lone argument. like rubygsm, this object has a handy Incoming#respond
	# method, which makes two-way SMS communication easy as pie.
	
	serve "test"
	def test(msg)
		msg.respond "This is a test"
	end
	
	
	# if anything containing the word "help" is received, this method is called,
	# and (unless :halt is thrown!) dispatching will restart with the remainder
	# of the message (the part that *wasn't* matched).
	
	serve /help/
	def help(msg)
		SMS::Outgoing.new(msg.backend, msg.sender, "I can't help you").send!
	end
	
	
	# this method uses the msg.sender object to keep volitile state (which is
	# only stored per-process) to demonstrate how applications can implement
	# lightweight sessions over sms.
	
	serve /count/
	def count(msg)
		msg.sender[:count] = msg.sender[:count].to_i + 1
		msg.respond "You've said that #{msg.sender[:count]} times!"
	end
	
	
	# this method deliberately causes a runtime error if the message (or the
	# remainder of a message, if some has already been parsed!) starts with
	# the word "error", to demonstrate the rolling error log.
	
	serve /^error/
	def runtime_error(msg)
		this_doesnt_exist
	end
	
	
	# if no other service matches the incoming message,
	# or there is text left over by other services, this
	# method is called. the name "default" is irrelevant.
	
	serve :anything
	def default(msg, text)
		msg.respond "I don't understand: #{text.strip.inspect}"
	end
end


# if this file is being executed directly,
# rather than included, start serving
if __FILE__ == $0

	# create a rubysms router, which receives incoming messages from the
	# backend(s), notifies each app, and (maybe)sends back the response
	router = SMS::Router.new
	router.add_backend(:HTTP)
	router.add_backend(:DRB)
	
	# and the application(s)
	router.add_app DemoApp.new

	# start serving
	router.serve_forever
end
