#!/usr/bin/env ruby
# vim: noet


module SMS
	class Incoming
		attr_reader :sent, :received, :text
		attr_reader :backend, :sender, :responses
		
		def initialize(backend, sender, sent, text)
			
			# move all arguments into read-only
			# attributes. ugly, but Struct only
			# supports read/write attrs
			@backend = backend
			@sent = sent
			@text = text
			
			# Sets @sender, transforming _sender_ into an SMS::Person if
			# it isn't already (to enable persistance between :Outgoing
			# and/or SMS::Incoming objects)
			@sender = sender.is_a?(SMS::Person) ? sender : SMS::Person.fetch(backend, sender)
			
			# assume that the message was
			# received right now, since we
			# don't have an incoming buffer
			@received = Time.now
			
			# initialize a place for responses
			# to this message to live, to be
			# extracted (for logging?) later
			@responses = []
		end
		
		# Creates an SMS::Outgoing object, adds it to _@responses_, and links
		# it back to this SMS::Incoming object via Outgoing#in_response_to.
		# IMPORTANT: This method doesn't actually SEND the message, it just
		# creates it - use Incoming#respond to create an send in one call.
		# This is most useful when you want to quickly create a response,
		# modify it a bit, and send it.
		def create_response(response_text)
			og = SMS::Outgoing.new(backend, sender, response_text)
			og.in_response_to = self
			@responses.push(og)
			og
		end
		
		# Same as Incoming#respond, but also sends the message.
		def respond(response_text)
			create_response(response_text).send!
		end
		
		# Returns the phone number of the sender of this message.
		def phone_number
			sender.phone_number
		end
	end
end
