#!/usr/bin/env ruby
# vim: noet

require "rack"



module SMS::Backends
	class Http < SMS::Backend
		HTTP_PORT = 1270
		
		class RackApp
			def initialize(http_backend_instance)
				@inst = http_backend_instance
				@log = {}
			end
			
			def call(env)
				req = Rack::Request.new(env)
				res = Rack::Response.new
				
				# for requests not containing a
				# session id, generate one and
				# redirect back to it
				if req.path_info == "/"
					session = (1111 + rand(8888)).to_s
					res.body = "Redirecting to session #{session}"
					res["location"] = "/#{session}"
					res.status = 301
					
				elsif m = req.path_info.match(/^\/(\d{4})\/send$/)
					if req.post?
						msg = req.POST["msg"]
						session = m.captures[0]
						add_log_msg(session, "in", msg)
						
						# push the incoming message
						# into smsapp, to distribute
						# to each application
						SMS::dispatch(
							SMS::Incoming.new(
								@inst, session, Time.now, msg))
						
					# only post is allowed to this
					# url, so reject anything else
					else
						res.status = 405
						res.body = "Method not allowed"
						res["content-type"] = "text/plain"
					end
				
				elsif m = req.path_info.match(/^\/(\d{4})\.json$/)
					session = m.captures[0]
					res.body = "[" + (@log[session] ? (@log[session].collect { |msg| msg.inspect }.join(", ")) : "") + "]"
				
				# if this request is for a session id, then
				# render the static HTML content (the log
				# contents are rendered via JSON, above)
				elsif req.path_info.match(/^\/\d{4}$/)
					res.body = HTML
				
				# no other url is valid
				else
					res.status = 404
					res.body = "Not Found"
					res["content-type"] = "text/plain"
				end
				
				res.finish
			end
		
			def add_log_msg(session, dir, msg)
				arr = [nil, dir, msg]
				arr[0] = arr.object_id.abs
			
				# initialize an empty log for
				# this session if required
				@log[session] = []\
					unless @log.has_key?(session)
			
				# add this new log message
				@log[session].push(arr)
			end
		end
		
		def start
			@app = RackApp.new(self.class.instance)
			uri = "http://localhost:#{HTTP_PORT}"
			log ["Started HTTP Offline Backend", "URI: #{uri}"], :init
			
			Rack::Handler::Mongrel.run(
				@app, :Port=>HTTP_PORT)
		end
		
		def send_sms(msg)
			@app.add_log_msg(msg.recipient, "out", msg.text)
		end
	end
end

SMS::Backends::Http::HTML = <<EOF
<html>
	<head>
		<title>RubySMS Virtual Device</title>
		<script type="text/javascript" src="http://ajax.googleapis.com/ajax/libs/mootools/1.2.1/mootools-yui-compressed.js"></script>
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
		</script>
	</body>
</html>
EOF
