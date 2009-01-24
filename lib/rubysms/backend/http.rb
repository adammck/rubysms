#!/usr/bin/env ruby
# vim: noet

require "rubygems"
require "rack"


module SMS::Backend

	# Provides a low-tech HTML webUI to inject mock SMS messages into
	# RubySMS, and receive responses. This is usually used during app
	# development, to provide a cross-platform method of simulating
	# a two-way conversation with the SMS backend(s). Note, though,
	# that there is no technical difference between the SMS::Incoming
	# and SMS::Outgoing objects created by this backend, and those
	# created by "real" incoming messages via the GSM backend.
	#
	# The JSON API used internally by this backend also be used by
	# other HTML applications to communicate with RubySMS, but that
	# is quite obscure, and isn't very well documented yet. Also, it
	# sporadically changes without warning. May The Force be with you.
	class HTTP < Base
		HTTP_PORT = 1270
		MT_URL = "http://ajax.googleapis.com/ajax/libs/mootools/1.2.1/mootools-yui-compressed.js"
		attr_reader :msg_log
		
		def initialize(mootools_url=MT_URL)
			@app = RackApp.new(self, mootools_url)
			
			# initialize the log, which returns empty
			# arrays (new session) for unknown keys
			# to avoid initializing sessions all over
			@msg_log = {}
			@msg_log.default = []
			
			# add an incoming our outgoing message to
			# the log with a unique id, direction ("in"
			# or "out"), and the text content (NOT an
			# SMS::Incoming or SMS::Outgoing object)
			def @msg_log.append(session, dir, text)
				self[session].push [text.object_id.abs, dir, text]
			end
			
			# i'm so vain... i probably
			# think this code is about me
			def @msg_log.incoming(s,t); append(s, "in", t); end
			def @msg_log.outgoing(s,t); append(s, "out", t); end
		end

		# Starts a thread-blocking Mongrel to serve
		# SMS::Backend::HTTP::RackApp, and never returns.
		def start
			
			# add a screen log message, which is kind of
			# a lie, because we haven't started anything yet
			uri = "http://localhost:#{HTTP_PORT}"
			log ["Started HTTP Offline Backend", "URI: #{uri}"], :init
			
			# this is goodbye
			Rack::Handler::Mongrel.run(
				@app, :Port=>HTTP_PORT)
		end
		
		# outgoing message from RubySMS (probably
		# in response to an incoming, but maybe a
		# blast or other unsolicited message). do
		# nothing except add it to the log, for it
		# to be picked up next time someone looks
		def send_sms(msg)
			@msg_log.outgoing(msg.recipient, msg.text)
			super
		end
		
		
		
		
		# This simple Rack application handles the few
		# HTTP requests that this backend will serve:
		#
		# GET  /             -- redirect to a random blank session
		# GET  /123456.json  -- export session 123456 as JSON data
		# GET  /123456       -- view session 123456 (actually a
		#                       static HTML page which fetches
		#                       the data via javascript+json)
		# POST /123456/send  -- add a message to session 123456
		class RackApp
			def initialize(http_backend, mootools_url)
				@backend = http_backend
				@mt_url = mootools_url
				
				# generate the html to be returned by replacing the
				# variables in the constant with our instance vars
				@html = HTML.sub(/%(\w+)%/) do
					instance_variable_get("@#{$1}")
				end
			end
			
			def call(env)
				req = Rack::Request.new(env)
				path = req.path_info
				
				if req.get?
					
					# serve GET /
					# for requests not containing a session id, generate a random
					# new one (between 111111 and 999999) and redirect back to it
					if path == "/"
						while true
						
							# randomize a session id, and stop looping if
							# it's empty - this is just to avoid accidentally
							# jumping into someone elses session (although
							# that's allowed, if explicly requested)
							new_session = (111111 + rand(888888)).to_s
							break if @backend.msg_log[new_session].empty?
						end
					
						return [
							301, 
							{"location" => "/#{new_session}"},
							"Redirecting to session #{new_session}"]
					
					# serve GET /123456
					elsif m = path.match(/^\/\d{6}$/)
					
						# just so render the static HTML content (the
						# log contents are rendered via JSON, above)
						return [200, {"content-type" => "text/html"}, @html]
			
					# serve GET /123456.json
					elsif m = path.match(/^\/(\d{6})\.json$/)
						return [
							200,
							{"content-type" => "application/json"},
							"[" + (@backend.msg_log[m.captures[0]].collect { |msg| msg.inspect }.join(", ")) + "]"]
					end
				
				# serve POST /123456/send
				elsif (m = path.match(/^\/(\d{6})\/send$/)) && req.post?
					t = req.POST["msg"]
					s = m.captures[0]
					
					# log the incoming message, so it shows
					# up in the two-way "conversation" 
					@backend.msg_log.incoming(s, t)

					# push the incoming message
					# into RubySMS, to distribute
					# to each application
					@backend.router.incoming(
						SMS::Incoming.new(
							@backend, s, Time.now, t))
					
					# acknowledge POST
					return [
						200,
						{"content-type" => "text/plain" },
						"OK"]
				end
				
				# nothing else is valid. not 404, because it might be
				# an invalid method, and i can't be arsed right now.
				[500, {"content-type" => "text/plain" }, "FAIL."]
			end
		end
	end
end

SMS::Backend::HTTP::HTML = <<EOF
<html>
	<head>
		<title>RubySMS Virtual Device</title>
		<script id="mt" type="text/javascript" src="%mt_url%"></script>
		<style type="text/css">
			body {
				font: 9pt monospace;
				padding: 0.5em;
			}
			
			#log {
				padding: 0;
				margin: 0;
			}
			
				#log li {
					list-style: none;
					margin-bottom: 0.5em;
					white-space: pre;
				}
					
					#log li.in  { color: #800; }
					#log li.out { color: #008; }
		</style>
	</head>
	<body>
		<ul id="log">
		</ul>
		
		<form id="send" method="post">
			<input type="text" name="msg" />
			<input type="submit" value="Send" />
		</form>
		
		<script type="text/javascript">
			/* if mootools wasn't loaded (ie, the internet at this shitty
			 * african hotel is broken again), just throw up a warning */
			if(typeof(MooTools) == "undefined") {
				var err = [
					"Couldn't load MooTools from: " + document.getElementById("mt").src,
					"This interface will not work without it, because I am a terrible programmer. Sorry."
				].join("\\n");
				document.getElementById("log").innerHTML = '<li class="error">' + err + '</li>';

			} else {
				window.addEvent("domready", function() {
					// extract the session id from the URI
					var session_id = location.pathname.replace(/[^0-9]/g, "");
			
					/* for storing the timeout, so we
					 * can ensure that only one fetch
					 * is running at a time */
					var timeout = null;
			
					/* function to be called when it is time
					 * to update the log by polling the server */
					var update = function() {
						$clear(timeout);
					
						new Request.JSON({
							"method": "get",
							"url": "/" + session_id + ".json",
							"onSuccess": function(json) {
								json.each(function(msg) {
									var msg_id = "msg-" + msg[0];
							
									/* iterate the items returned by the
									 * JSON request, and append any new
									 * messages to the message log */
									if ($(msg_id) == null) {
										new Element("li", {
											"text": ((msg[1] == "in") ? "<<" : ">>") + ' ' + msg[2],
											"class": msg[1],
											"id": msg_id
										}).inject("log");
									}
								});
						
								// call again soon
								timeout = update.delay(5000);
							}
						}).send();
					};
			
					/* when a message is posted via AJAX,
					 * reload the load to include it */
					$("send").set("send", {
						"url": "/" + session_id + "/send",
						"onComplete": update
				
					/* submit the form via ajax,
					 * and cancel the full-page */
					}).addEvent("submit", function(ev) {
						this.send();
						ev.stop();
					});
			
					/* start updating the log almost right
					 * away, to load any initial content */
					timeout = update.delay(10);
				});
			}
		</script>
	</body>
</html>
EOF
