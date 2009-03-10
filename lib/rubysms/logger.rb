#!/usr/bin/env ruby
# vim: noet

module SMS
	class Logger
		def initialize(stream=$stdout)
			@stream = stream
		end
		
		def event(str, type=:info)
			
			# arrays or strings are fine. quack!
			str = str.join("\n") if str.respond_to?(:join)
			
			# each item in the log is prefixed by a four-char
			# coloured prefix block, to help scanning by eye
			prefix_text = LogPrefix[type] || type.to_s
			prefix = colored(prefix_text, type)
			
			# the first line of the message is indented by
			# the prefix, so indent subsequent lines by an
			# equal amount of space, to keep them lined up
			indent = colored((" " * prefix_text.length), type) + " "
			@stream.puts prefix + " " + str.to_s.gsub("\n", "\n#{indent}")
		end
		
		def event_with_time(str, *rest)
			event("#{time_log(Time.now)} #{str}", *rest)
		end

		private

		# Returns a short timestamp suitable
		# for embedding in the screen log.
		def time_log(dt=nil)
			dt = DateTime.now unless dt
			dt.strftime("%I:%M%p")
		end
		
		def colored(str, color)
			
			# resolve named colors
			# to their ANSI color
			color = LogColors[color]\
				if color.is_a? Symbol
			
			# return the ugly ANSI string
			"\e[#{color};37;1m#{str}\e[0m"
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
	end
end
