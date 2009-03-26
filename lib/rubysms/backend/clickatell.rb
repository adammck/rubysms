#!/usr/bin/env ruby
# vim: noet


require "rubygems"
require "clickatell"
require "mongrel"
require "rack"


module SMS::Backend
	class Clickatell < Base
		PORT = 1280
		
		# just store the arguments until the
		# backend is ready to be started
		def initialize(key, username, password)
			@username = username
			@password = password
			@key = key
		end
		
		def start
			@api = ::Clickatell::API.authenticate(@key, @username, @password)
			balance = @api.account_balance
			
			# start a separate thread to receive
			# the incoming messages from clickatell
			@rack_thread = Thread.new do
				Rack::Handler::Mongrel.run(
					method(:rack_app), :Port=>PORT)
			end
			
			# nothing went wrong this time
			# so dump some useful info
			log [
				"Started #{label} Backend",
				"  Account balance: #{balance}"
			], :init
		end
		
		def send_sms(msg)
			begin
				@api.send_message(msg.phone_number, msg.text)
				super

			# sending failed, for some reason. i've
			# never seen this happen, so just log it
			rescue Clickatell::API::Error => err
				log_exception err, "Message sending FAILED"
			end
		end
		
		def rack_app(env)
			req = Rack::Request.new(env)
			post = req.GET
			
			# only a single (obscure) url is valid, which
			# must be entered into the clickatell admin
			return resp(404, "Not Found") unless\
				req.path_info == "/sms/receive"
			
			# check that the required parameters were
			# provided, and abort if any are missing
			return resp(500, "Missing Parameters") unless\
				post["from"] && post["timestamp"] && post["text"]
			
			begin
				# attempt to parse the timestamp
				# (it's a mySQL timestamp... ?!)
				time = Date.strptime(
					post["timestamp"],
					"%Y-%m-%d%H:%M:%S")
			
			# timestamp parsing fail
			rescue Exception => err
				log_exception err, "Invalid timestamp: #{post["timestamp"]}"
				return resp(500, "Invalid timestamp")
			end
			
			# everything looks fine, so notify rubysms of
			# the incoming message, and acknowledge clickatell
			router.incoming(
				SMS::Incoming.new(
					self, post["from"], time, post["text"]))
			resp(200, "Message Accepted")
		end
		
		private
		
		def resp(code, text)
			[code, {"content-type" => "text/plain"}, text]
		end
	end
end
