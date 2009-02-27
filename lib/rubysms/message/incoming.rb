#!/usr/bin/env ruby
# vim: noet


module SMS
	class Incoming
		attr_reader :sender, :sent, :received, :text
		attr_reader :backend, :responses
		
		def initialize(backend, sender, sent, text)
			
			# move all arguments into read-only
			# attributes. ugly, but Struct only
			# supports read/write attrs
			@backend = backend
			@sender = sender
			@sent = sent
			@text = text
			
			# assume that the message was
			# received right now, since we
			# don't have an incoming buffer
			@received = Time.now
			
			# initialize a place for responses
			# to this message to live, to be
			# extracted (for logging?) later
			@responses = []
		end
		
		def respond(response_text)
			og = SMS::Outgoing.new(backend, sender, response_text)
			og.in_response_to = self
			@responses.push(og)
			og.send!
		end
	end
end
