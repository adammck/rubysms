#!/usr/bin/env ruby
# vim: noet

module SMS::Backends
	
	# however many SmsApp classes are created
	# and run, only a single instance can access
	# the GSM modem at once: this is the instance
	class Gsm < SMS::Backend
		def serve_forever(port="/dev/ttyS0", pin=nil)
			begin
				@gsm = GsmModem.new(port)
				@gsm.use_pin(pin) unless pin.nil?
				@gsm.receive SMS.method(:dispatch)
				
				bands = @gsm.bands.join(", ")
				log "Using GSM Band: #{@gsm.band}MHz"
				log "Modem supports: #{bands}"
				
				log "Waiting for GSM network..."
				str = @gsm.wait_for_network
				log "Signal strength is: #{str}"
				
			# couldn't open the port. this usually means
			# that the modem isn't plugged in to it...
			rescue Errno::ENOENT, ArgumentError
				log "Couldn't open #{port}", :err
				raise IOError
			
			# something else went wrong
			# while initializing the modem
			rescue GsmModem::Error => err
				log ["Couldn't initialize the modem",
				     "RubyGSM Says: #{err.desc}"], :err
				raise RuntimeError
			end
			
			# rubygsm didn't blow up?!
			log "Started GSM Backend", :init
		end
		
		def send_sms(to, msg)
			@gsm.send(to, msg)
		end
	end
end
