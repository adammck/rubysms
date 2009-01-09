#!/usr/bin/env ruby
# vim: noet

# standard library
require "singleton.rb"

# ruby gems
require "rubygems"
require "rubygsm"


# --
# see bottom of this file
# for the backend includes
# --

# during development, it's important to EXPLODE
# as early as possible when something goes wrong
Thread.abort_on_exception = true
Thread.current["name"] = "main"


module SMS
	class << self
		attr_reader :apps
		def serve_forever(backend, *args)
			@apps = {}

			# start sending and receiving SMS early, so
			# we can use the backend in app initializers
			begin
				@backend = SMS::Backends.const_get(camelize(backend))
				self.backend.serve_forever(*args)
				
			#rescue StandardError
				#log "BOOM", :err
				#return false
			end
			
			# create instances of each SMS application
			ObjectSpace.each_object(Class) do |klass|
				if klass < SMS::App
					log "Started #{klass.to_s}", :init
					@apps[klass] = klass.new
					@apps[klass].start
				end
			end
			
			# catch interrupts and display a nice message (rather than
			# a backtrace). to avoid seeing control characters (^C) in
			# the output, disable the "echoctl" option in your terminal
			# (i added "stty -echoctl" to my .bashrc)
			trap("INT") do
				log "Shutting down", :init
				
				# fire the "stop" method of each
				# application before terminating
				apps.each_value { |app| app.stop }
				
				exit
			end
			
			# block until ctrl+c
			while true do
				#log_memory_usage
				sleep 5
			end
		end
		
		def backend
			@backend.instance
		end
		
		# whichever backend is running, incoming sms messages
		# will 
		def dispatch(from, dt, msg)
			log "#{time_log(dt)} #{from}: #{msg}", :in
			
			# notify each application of the message.
			# they may or may not respond to it
			apps.each_value do |app|
				begin
					app.incoming from, dt, msg
					
				rescue SMS::Respond => resp
					# if a :respond message was raised, then send it
					# now, before moving on to the next app. we send
					# it via app#send, rather than SMS::send_sms, in case
					# the app has any special outgoing functionality
					app.send_sms(from, *resp.message)
				end
			end
		end
		
		def send_sms(to, msg)
			log "#{time_log(Time.now)} #{to}: #{msg} (#{msg.length})", :out
			
			# notify each app of the outgoing sms
			# note that the sending can still fail
			apps.each_value do |app|
				if app.respond_to? :outgoing
					app.outgoing to, Time.now, msg
				end
			end
			
			# now really send the sms
			backend.send_sms(to, msg)
		end
	
		def log(msg, type=:info, klass=nil)
			
			# arrays or strings are fine. quack!
			msg = msg.join("\n") if msg.respond_to?(:join)
			
			# each item in the log is prefixed by a four-char
			# coloured prefix block, to help scanning by eye
			prefix_txt = LogPrefix[type] || type.to_s
			prefix = "\e[#{LogColors[type]};37;1m" + prefix_txt + "\e[0m"
			
			# the first line of the message is indented by
			# the prefix, so indent subsequent lines by an
			# equal amount of space, to keep them lined up
			indent = " " * (prefix_txt.length + 1)
			puts prefix + " " + msg.gsub("\n", "\n#{indent}")
		end
		
		private
	
		def time_log(dt=nil)
			dt = DateTime.now unless dt
			dt.strftime("%I:%M%p")
		end
		
		def log_memory_usage
			resident, virtual, cputime = `ps -o "rss vsz" h`.strip.split("\s")
			log "Res Mem: #{resident}KiB"
			log "Virt Mem: #{virtual}KiB"
		end

		def camelize(sym)
			sym.to_s.gsub(/(?:\A|_)(.)/) { $1.upcase }
		end
		
		LogColors = {
			:init => 46,
			:info => 40,
			:warn => 41,
			:err  => 41,
			:in   => 45,
			:out  => 45 }
	
		LogPrefix = {
			:info => "    ",
			:err  => "FAIL",
			:in   => " << ",
			:out  => " >> " }
	end # << self
	
	class CancelIncoming < StandardError
	end
	
	class CancelOutgoing < StandardError
	end
	
	class Respond < Interrupt
	end
	
	class App
		
		# stubs to avoid NoMethodError
		def start; end
		def stop; end
		
		def respond(*msg)
			raise SMS::Respond, msg
		end
		
		def incoming(from, dt, msg)
			if services = self.class.instance_variable_get(:@services)
			
				# iterate the services defined for this
				# class, and call the first that matches
				# the incoming message. 
				services.each do |service|
					method, pattern, priority = *service
				
					# if this pattern looks like a regex,
					# attempt to match the incoming message
					if pattern.respond_to?(:match)
						if m = pattern.match(msg)
							
							# build a string to clearly log where
							# we're dispatching the message to
							meth_str = self.class.to_s + "#" + method.to_s
							meth_str += " #{m.captures.inspect}"\
								unless m.captures.empty?
							
							log "Dispatching to: #{meth_str}"
							
							# dispatch this message to the matching
							# method, and stop processing (specifically,
							# so services can start specific, and become
							# more and more liberal without checking if
							# the message has already been dispatched
							# --
							# once the method is invoked, it can throw
							# the :do_not_want symbol to refuse the
							# message (for example, if a record was
							# not found), which allows processing to
							# continue as if the method never matched
							catch(:do_not_want) do
								send(method, from, dt, *m.captures)
								return true
							end
						end
					
					# the special :anything pattern
					# can be used as a default service
					elsif pattern == :anything
						send(method, from, dt, msg)
					end
				end
			end
		end
		
		def send_sms(to, *msgs)

			# iterate multiple arguments, to resolve
			# messages in each of them separately,
			parts = msgs.collect do |msg|
				
				# if the message is a symbol, then attempt to
				# resolve it via the self.class::Messages hash
				if msg.is_a? Symbol
					if self.class.const_defined?(:Messages)				
						if msg_str = self.class.const_get(:Messages)[msg]
							log "Resolved message #{msg.inspect} to #{msg_str.inspect}"
							msg = msg_str
						else
							log "No such message as #{msg.inspect} for #{self.class}", :warn
							msg = msg.to_s
						end
					else
						# no messages const in this app, but receiving
						# a cryptic message name is better than nothing
						log "No Messages for #{self.class}", :warn
						msg = msg.to_s
					end
				end
				
				msg
			end
			
			# send all parts joined with no separator,
			# for maximum control over formatting
			SMS::send_sms(to, parts.join(""))
		end
		
		def log(msg, type=:info)
			SMS::log(msg, type, self.class)
		end
	
		class << self
			def serve(regex)
				@serve = regex
			end
		
			def method_added(meth)
				if @serve
					@services = []\
						unless @services
					
					# add this method, along with the last stored
					# regex, to the map of services for this app.
					# the default 'incoming' method will iterate
					# the regexen, and redirect the message to
					# the method linked here
					@services.push([meth, @serve])
					@serve = nil
				end
			end
		end
	end
	
	class Backend
		include Singleton
		protected
		
		# proxy method(s) to the SMS module, so
		# backends can use them without the prefix
		def log(*args)
			SMS::log(*args)
		end
	end
end

# during dev, load all
# sms backends manually
here = File.dirname(__FILE__)
require "#{here}/backend/http.rb"
require "#{here}/backend/drb.rb"
require "#{here}/backend/gsm.rb"
