#!/usr/bin/env ruby
# vim: noet

module SMS
	class Router
		attr_reader :apps, :backends
		
		
		def initialize
			@log = Logger.new(STDOUT)
			@backends = []
			@apps = []
		end
		
		
		# proxy methods to pass events
		# to the logger with the pretty
		
		def log(*args)
			@log.event(*args)
		end
		
		def log_with_time(*args)
			@log.event_with_time(*args)
		end
		
		def log_exception(error, prefix_message=nil)
			msgs = [error.class, error.message]
			
			# if a prefix was provided (to give a litle
			# more info on what went wrong), prepend it
			# to the output with a blank line
			unless prefix_message.nil?
				msg.shift prefix_message, ""
			end
			
			# add each line until the current frame is within
			# rubysms (the remainder will just be from gems)
			catch(:done) do
				error.backtrace.each do |line|
					if line =~ /^#{SMS::Root}/
						throw :done
					end
					
					# still within the application,
					# so add the frame to the log
					msgs.push("  " + line)
				end
			end
			
			@log.event msgs, :warn
		end
		
		
		# Starts listening for incoming messages
		# on all backends, and never returns.
		def serve_forever
			
			# (attempt to) start up each
			# backend in a separate thread
			@backends.each do |b|
				Thread.new do
					b.start
				end
			end
			
			# applications don't need their own
			# thread (they're notified in serial),
			# but do have a #start method
			@apps.each { |a| a.start }

			# catch interrupts and display a nice message (rather than
			# a backtrace). to avoid seeing control characters (^C) in
			# the output, disable the "echoctl" option in your terminal
			# (i added "stty -echoctl" to my .bashrc)
			trap("INT") do
				log "Shutting down", :init
			
				# fire the "stop" method of
				# each application and backend
				# before terminating the process
				(@backends + @apps).each do |inst|
					inst.stop
				end
			
				exit
			end
		
			# block until ctrl+c
			while true do
				sleep 5
			end
		end
		
		# Accepts an SMS::Backend::Base or SMS::App instance,
		# which is stored until _serve_forever_ is called.
		def add(something)
			if something.is_a? SMS::Backend::Base
				@backends.push(something)
			
			elsif something.is_a? SMS::App
				@apps.push(something)
			
			else
				raise RuntimeError,
					"Router#add doesn't know what " +\
					"to do with a #{something.klass}"
			end
			
			# store a reference back to this router in
			# the app or backend, so it can talk back
			something.router = self
		end
		
		# Relays a given incoming message from a
		# specific backend to all applications.
		def incoming(msg)
			log_with_time "[#{msg.backend.label}] #{msg.sender.key}: #{msg.text} (#{msg.text.length})", :in
			
			# notify each application of the message.
			# they may or may not respond to it
			@apps.each do |app|
				begin
					app.incoming msg
				
				# something went boom in the app
				# log it, and continue with the next
				rescue StandardError => err
					log_exception(err)
					
				#	if msg.responses.empty?
				#		msg.respond("Sorry, there was an error while processing your message.")
				#	end
				end
			end
		end
		
		# Notifies each application of an outgoing message, and
		# logs it. Should be called by all backends prior to sending.
		def outgoing(msg)
			log_with_time "[#{msg.backend.label}] #{msg.recipient.key}: #{msg.text} (#{msg.text.length})", :out
			log("Outgoing message exceeds 140 characters", :warn) if msg.text.length > 140
			cancelled = false
			
			# notify each app of the outgoing sms
			# note that the sending can still fail
			@apps.each do |app|
				app.outgoing msg
			end
		end
	end
end
