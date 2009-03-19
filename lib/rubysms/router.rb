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
			
			# if a prefix was provided (to give a litle
			# more info on what went wrong), prepend it
			# to the output and indent the rest
			unless prefix_message.nil?
				msgs = [prefix_message] + msgs.collect do |msg|
					"  " + msg.to_s
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
				log "Shutting down", :stop
			
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
		# DEPRECATED because it's confusing and magical.
		def add(something)
			log "Router#add is deprecated; use " +\
			    "#add_backend and #add_app", :warn
			
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
		
		# Adds an SMS application (which is usually an instance of a subclass
		# of SMS::App, but anything's fine, so long as it quacks the right way)
		# to this router, which will be started once _serve_forever_ is called.
		def add_app(app)
			@apps.push(app)
			app.router = self
		end
		
		# Adds an SMS backend (which MUST be is_a?(SMS::Backend::Base), for now),
		# or a symbol representing a loadable SMS backend, which is passed on to
		# SMS::Backend.create (along with *args) to be required and initialized.
		# This only really works with built-in backends, for now, but is useful
		# for initializing those:
		#
		#   # start serving with a single
		#   # http backend on port 9000
		#   router = SMS::Router.new
		#   router.add_backend(:HTTP, 9000)
		#   router.serve_forever
		#
		#   # start serving on two gsm
		#   # modems with pin numbers
		#   router = SMS::Router.new
		#   router.add_backend(:GSM, "/dev/ttyS0", 1234)
		#   router.add_backend(:GSM, "/dev/ttyS1", 5678)
		#   router.serve_forever
		#
		def add_backend(backend, *args)
				
			# if a backend object was given, add it to this router
			# TODO: this modifies the argument just slightly. would
			# it be better to duplicate the object first?
			if backend.is_a?(SMS::Backend::Base)
				@backends.push(backend)
				backend.router = self
			
			# if it's a named backend, spawn it (along
			# with the optional arguments) and recurse
			elsif backend.is_a?(Symbol) or backend.is_a?(String)
				add_backend SMS::Backend.create(backend.to_sym, nil, *args)
			
			# no idea what this
			# backend is = boom
			else
				raise RuntimeError,
					"Router#add_backend doesn't know what " +\
					"to do with #{backend} (#{backend.klass})"
			end
		end
		
		# Relays a given incoming message from a
		# specific backend to all applications.
		def incoming(msg)
			log_with_time "[#{msg.backend.label}] #{msg.sender.key}: #{msg.text} (#{msg.text.length})", :in
			
			# iterate apps starting with
			# the highest numeric priority
			sorted = @apps.sort_by { |a| a.priority }.reverse
			
			# notify each application of the message.
			# they may or may not respond to it, and
			# may throw the :halt symbol to stop the
			# notifying further apps. this is useful
			# in conjunction with App.priority
			catch(:halt) do
				sorted.each do |app|
					begin
						catch(:continue) do
							app.incoming msg
							
							# if the app responded to the message, cancel
							# further processing - unless :continue was
							# thrown, which jumps over this check
							unless msg.responses.empty?
								throw :halt
							end
						end
					
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
		end
		
		# Notifies each application of an outgoing message, and
		# logs it. Should be called by all backends prior to sending.
		def outgoing(msg)
			log_with_time "[#{msg.backend.label}] #{msg.recipient.key}: #{msg.text} (#{msg.text.length})", :out
			log("Outgoing message exceeds 140 characters", :warn) if msg.text.length > 140
			
			# iterate apps starting with the loest numeric priority (the
			# opposite to #incoming,so a :highest priority app gets the
			# first look at incoming, and the last word on what goes out)
			sorted = @apps.sort_by { |a| a.priority }
			
			# notify each app of the outgoing sms
			# note that the sending can still fail
			sorted.each do |app|
				app.outgoing msg
			end
		end
	end
end
