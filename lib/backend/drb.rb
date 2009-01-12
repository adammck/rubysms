#!/usr/bin/env ruby
# vim: noet


require "drb.rb"


module SMS::Backends
	class Drb < SMS::Backend
		DRB_PORT = 1370
		
		def start
			begin
			
				# start the DRb service, listening for connections
				# from the RubySMS virtual device (virtual-device.rb)
				drb = DRb.start_service("druby://localhost:#{DRB_PORT}", self)
				log ["Started DRb Offline Backend", "URI: #{drb.uri}"], :init
				
				# a hash to store incoming
				# connections from drb clients
				@injectors = {}
			end
		end
		
		def send_sms(msg)
			to = msg.recipient
			super
			
			# if this is the first time that we
			# have communicated with this DRb
			# client, then initialize the object
			unless @injectors.include?(to)
				drbo = DRbObject.new_with_uri("druby://localhost:#{DRB_PORT}#{to}")
				@injectors[to] = drbo
			end
			
			@injectors[to].incoming(msg.text)
		end
		
		# called from another ruby process, via
		# drb, to simulate an incoming sms message
		def incoming(sender, text)
			SMS::dispatch(
				SMS::Incoming.new(
					self.class.instance, sender, Time.now, text))
		end
	end
end
