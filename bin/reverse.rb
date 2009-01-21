#!/usr/bin/env ruby
# vim: noet

require(File.dirname(__FILE__) + "/../lib/rubysms.rb")

class ReverseApp < SMS::App
	def incoming(msg)
		msg.respond msg.text.reverse
	end
end

ReverseApp.serve!
