#!/usr/bin/env ruby
# vim: noet


module SMS
	class Outgoing
		attr_accessor :text, :in_response_to
		attr_reader :backend, :recipient, :sent
		
		def initialize(backend, recipient=nil, text=nil)
			
			# move all arguments into instance
			# vars, to be accessed by accessors
			@backend = backend
			@text = text
			
			# Sets @recipient, transforming _recipient_ into an SMS::Person if
			# it isn't already (to enable persistance between :Outgoing and/or
			# SMS::Incoming objects)
			@recipient = recipient.is_a?(SMS::Person) ? recipient : SMS::Person.fetch(backend, recipient)
		end
		
		# Sends the message via _@backend_ NOW, and
		# prevents any further modifications to self,
		# to avoid the object misrepresenting reality.
		def send!
			backend.send_sms(self)
			@sent = Time.now
			
			# once sent, allow no
			# more modifications
			freeze
		end
		
		# Returns the phone number of the recipient of this message.
		def phone_number
			recipient.phone_number
		end
	end
end
