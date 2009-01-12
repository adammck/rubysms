#!/usr/bin/env ruby
# vim: noet


here = File.dirname(__FILE__)
require "#{here}/application.rb"
require "#{here}/backend.rb"
require "#{here}/errors.rb"

# rubygsm via gem
#require "rubygems"
#require "rubygsm"

# or via ../
rubygsm_dir = "#{here}/../../rubygsm"
require "#{rubygsm_dir}/lib/rubygsm.rb"

# message classes
require "#{here}/message/incoming.rb"
require "#{here}/message/outgoing.rb"


# during development, it's important to EXPLODE
# as early as possible when something goes wrong
Thread.abort_on_exception = true
Thread.current["name"] = "main"


module SMS
	class << self
		attr_reader :apps, :backends
		
		def serve
			@apps = {}
			@backends = []\
				if @backends.nil?
			
			# (attempt to) start up each
			# backend in a separate thread
			backends.each do |inst, args|
				Thread.new do
					inst.start(*args)
				end
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
				
				# fire the "stop" method of
				# each application and backend
				# before terminating the process
				backends.each   { |inst, args| inst.stop }
				apps.each_value { |app|        app.stop }
				
				exit
			end
			
			# block until ctrl+c
			while true do
				sleep 5
			end
		end
		
		def add_backend(backend, *args)
			@backends = []\
				if @backends.nil?

			begin
				here = File.dirname(__FILE__)
				require "#{here}/backend/#{backend.to_s.downcase}.rb"

			# the require failed, but there may be
			# other backends working fine, so proceed
			# with just a warning
			rescue LoadError
				log "Couldn't load backend: #{fn}", :err
				return false
			end

			begin
				# each backend should provide a submodule of
				# SMS::Backends, named according to its filename
				sym = camelize(backend)
				mod = SMS::Backends.const_get(sym)
				@backends.push([mod.instance, args])

			rescue StandardError
				log "Couldn't initialize backend: #{backend}", :err
			end
		end
		
		# whichever backends are running, incoming
		# sms messages are passed to every application
		def dispatch(msg)
			info = "#{time_log(msg.sent)} #{msg.backend.label} #{msg.sender}"
			log info + ": " + msg.text, :in
			
			# notify each application of the message.
			# they may or may not respond to it
			apps.each_value do |app|
					app.incoming msg
			end
		end
		
#		def send_sms(to, msg)
#			log "#{time_log(Time.now)} #{to}: #{msg} (#{msg.length})", :out
#			
#			# notify each app of the outgoing sms
#			# note that the sending can still fail
#			apps.each_value do |app|
#				if app.respond_to? :outgoing
#					app.outgoing to, Time.now, msg
#				end
#			end
#			
#			# now really send the sms
#			backend.send_sms(to, msg)
#		end
	
		def log(msg, type=:info)
			
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
		
		def log_with_time(msg, *rest)
			log("#{time_log(Time.now)} #{msg}", *rest)
		end
		
		private

		def time_log(dt=nil)
			dt = DateTime.now unless dt
			dt.strftime("%I:%M%p")
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
end
