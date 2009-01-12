#!/usr/bin/env ruby
# vim: noet


module SMS::Backends
	
	# however many SmsApp classes are created
	# and run, only a single instance can access
	# the GSM modem at once: this is the instance
	class Gsm < SMS::Backend
		def start(port=:auto, pin=nil)
			begin
				@gsm = ::Gsm::Modem.new(port)
				@gsm.use_pin(pin) unless pin.nil?
				@gsm.receive method(:incoming)
				
				bands = @gsm.bands_available.join(", ")
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
			rescue ::Gsm::Modem::Error => err
				log ["Couldn't initialize the modem",
				     "RubyGSM Says: #{err.desc}"], :err
				raise RuntimeError
			end
			
			# rubygsm didn't blow up?!
			log "Started GSM Backend", :init
		end
		
		def send_sms(msg)
			@gsm.send_sms(msg.recipient, msg.text)
		end
		
		# called back by rubygsm when an incoming
		# message arrives, which we will pass on
		# to rubysms to dispatch to applications
		def incoming(msg)
		
			# NOTE: the msg argument is a GSM::Incoming
			# object from RubyGSM, NOT the more useful
			# SMS::Incoming object from RubySMS
			
			SMS::dispatch(
				SMS::Incoming.new(
					self.class.instance, msg.sender, msg.sent, msg.text)
		end
	end
end
