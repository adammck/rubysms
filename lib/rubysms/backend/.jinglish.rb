#!/usr/bin/env ruby
# vim: noet

require "rubygsm.rb"
#require "smsapp.rb"

class Module
	def serves(token="", opts={}, &blk)
		opts = {
			:priority => :normal
		}.merge(opts)
		
		
		# symbols can be provided instead of regexen
		# (as defined by SmsApp::Regexen), to avoid
		# repeating the same common patterns
		if token.is_a?(Symbol)
			if SmsApp::Regexen.has_key?(token)
				@map = SmsApp::Regexen[token]

			else
				# if the symbol wasn't recognised, then
				# raise a fatal error to avoid ambiguity
				raise( IndexError,
					"Invalid regex fragment: #{token} " +
					"(See SmsApp::Regexen for a list)")
			end

		# anything else is fair game
		else; @map = token; end
		
		
		# as well as providing a regex (or part of one),
		# a block can be passed, which is invoked each
		# time a message is received to decide if the
		# linked module will accept it
		@block = blk
		
		
		# resolve named priorities to integers,
		# and raise a fatal error for unknowns
		unless(@priority = SmsApp::Priorities[opts[:priority]])
			raise(IndexError,
				"Invalid named priority: " +
				opts[:priority])
		end
	end
end

class Object
	def log(msg, type=:info)
		col = {
			:info => 43,
			:done => 42,
			:warn => 41,
			:inco => 44 }
		
		capt = {
			:inco => " << " }
		
		msg = msg.join("\n")\
			if msg.respond_to?(:join)
		
		prefix = capt.has_key?(type) ? capt[type] : type.to_s
		msg_log = msg.gsub("\n", " " * (prefix.length + 1))
		puts "\e[#{col[type]};37;1m" + "[#{prefix}]" + "\e[0m " + msg_log
	end
end


class SmsApp
	Regexen    = { :slug=>'([\w\-]+?)', :anything=>'(.*?)' }
	Priorities = { :low=>15, :normal=>10, :high=>5 }
	Join_Regex = '\s*'
	Wrap_Regex = "^%s$"

	def self.serve_forever(port="/dev/ttyS0", pin=nil)
		log "Starting SMS Application"
		
		# dump a list of maps that we will be serving
		log(handlers.collect do |h|
			"#{h.map.source} => #{h}"
		end)
		
		unless port.nil?
			begin
				
				# initialize the modem. these are globals for
				# now, since there can only be one process
				# accessing the modem at a time
				$modem = Modem.new port
				$cmdr = ModemCommander.new($modem)
				$cmdr.use_pin(pin) unless pin.nil?
				$cmdr.wait_for_network
				
			# couldn't open the port. this usually means
			# that the modem isn't plugged in to it...
			rescue Errno::ENOENT, ArgumentError
				log "Couldn't initialize modem", :warn
			
			# something else went wrong
			rescue Modem::Error => err
				log "Couldn't initialize the modem.\n" +\
				    "RubyGSM Says: #{err.desc}", :warn
			end
			
		else
			# the port was nil, so we won't be sending
			# or receiving anything.
			log "No modem. Starting Development Mode."
		end
		
	
		# watch files in /tmp/sms, and process
		# each as if it were an incoming sms
		Thread.new do
			path = "/tmp/sms"
			`mkdir #{path}` unless File.exists? path
			
			# to differentiate between injected and
			# real incoming sms in the rubygsm log
			Thread.current["name"] = "injector"
			
			while true
				`find #{path} -type f -print0`.split("\0").each do |file|
					if m = File.read(file).strip.match(/^(\d+):\s*(.+)$/)
						
						# pass to NotKannel::Receiver
						from, msg = *m.captures
						SmsApp::incoming from, Time.now, msg
						
						# delete the file, so we don't
						# process it again next time
						File.unlink(file)
					end
				end
				
				# re-check in
				# two seconds
				sleep 2
			end
		end
		
		# block until ctrl+c
		while true do
			sleep(1)
		end
	end
	
	def self.time(dt=nil)
		dt = DateTime.now unless dt
		#dt.strftime("%I:%M%p, %d/%m")
		dt.strftime("%I:%M%p")
	end
	
	def self.handlers
		handlers = []
		
		base = SmsApp::Handler
		ObjectSpace.each_object(Class) do |klass|
			if klass.ancestors.include?(base)\
			&& klass.to_s[025] != "Bundle"\
			&& klass != base
			
				handlers.push(klass)
			end
		end
		
		return handlers
	end
	
	def self.incoming(from, time, msg)
		time_log = SmsApp::time(time)
		log "#{time_log} #{from}: #{msg}", :inco
		
		# while iterating classes, we will store every
		# known map (for debugging in case the request
		# fails), and all potential matches
		matches = []
		
		handlers.each do |klass|
			this_map = klass.map
		
			# store the class and match data,
			# which is passed to #request
			if m = this_map.match(msg)
				matches.push({
					:class => klass,
					:bdata => [],
					:mdata => m.captures
				})
			end
		end
		
		# EXPLAIN THIS??
		matches.each do |m|
			m[:class].blocks.collect do |blk|
				res = blk.call(url, *m[:mdata])
				unless res
					matches.delete(m)
					break
				end
				
				m[:bdata].push(*res)\
					if res.is_a?(Array)
			end
		end
		
		# this URL is not served by any known
		# class - raise an ugly 404 error
		if matches.empty?
			puts "Couldn't dispatch incoming message"
			return false
		end
		
		# sort potential classes into priority order, and use the first
		top = (matches.sort_by { |match| match[:class].priority }).first
		obj = top[:class].new
		puts " => #{obj.class}"
	end
	
	class Handler
		class << self
			def map
				# the map of this class is established by concatenating
				# all of the map fragments in the modules nesting it
				regex = nested_instance_variables(:@map).compact.join(SmsApp::Join_Regex)
				Regexp.new(SmsApp::Wrap_Regex % regex)
			end
			
			def priority
				nested_instance_variables(:@priority).compact.last
			end
			
			def blocks
				return nested_instance_variables(:@block).compact
			end
			
			
		private
			def nested_instance_variables(symbol)
				nest = []
				
				# build an array of the modules wrapping
				# this class, from outer to innermost
				# something like: [ A, A::B, A::B::C ]
				self.name.split("::").each do |part|
					if nest.empty?; nest = [Object.const_get(part)]
					else;           nest.push(nest.last.const_get(part))
					end
				end
				
				# collect and return all of the instance
				# variables of the same name (symbol)
				nest.collect do |mod|
					mod.instance_variable_get(symbol)
				end
			end
		end
		
		def request(*args)
			raise RuntimeError\
				unless self.class.const_defined?(:Response)
			
			self.class::Response.new(*args)
		end
	end
	
	class ErrorHandler
		
	end
end


class DemoApplication < SmsApp
	def incomming(from, dt, msg)
		puts "I got a message!"
	end
end


# during development, it's important to EXPLODE
# as early as possible when something goes wrong
Thread.abort_on_exception = true
Thread.current["name"] = "main"

# start the app
SmsApp.serve_forever
