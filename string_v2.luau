do
	wait(2)
	-- [dependencies]
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")

	--[enum]
	local Enum = setmetatable({
		CustomTypes = {},
		EnumType = Enum,
	}, {
		__index = function(self, key)
			local DefaultType, CustomType =
				(function()
					local success, enum = pcall(function()
						return self.EnumType[key]
					end)

					if success then
						return enum
					else
						return false
					end
				end)(), self.CustomTypes[key]

			if DefaultType or CustomType then
				return DefaultType or CustomType
			else
				return false
			end
		end,
		__newindex = function(self, key, value)
			self.CustomTypes[key] = value
		end,
		__tostring = function(self)
			return "Enum"
		end,
		__metatable = "Enum",
	}) :: typeof(Enum) & {
		WebSocketService: {
			Connection: {
				Secure: string,
				Insecure: string,
			},
		},
	} & any

	Enum["WebSocketService"] = {
		Connection = {
			Secure = "wss",
			Insecure = "ws",
		},
	}

	-- [websocket]
	local WebSocketManager = setmetatable({}, {
		__index = {
			new = function(self, config)
				assert(config, "Config is required")

				return setmetatable({
					Socket = nil,
					Config = config,
					ConnectinMethod = nil,
				}, {
					__index = {
						OnMessage = function(self, method)
							local success, response =
								pcall(self.Socket.OnMessage.Connect, self.Socket.OnMessage, method)
							if not success then
								warn("OnMessage", response)
							else
								warn("onMessage connection established")
							end
						end,
						OnClose = function(self, method)
							local success, response = pcall(self.Socket.OnClose.Connect, self.Socket.OnClose, method)
							if not success then
								warn("OnClose", response)
							else
								warn("onClose connection established")
							end
						end,
						Send = function(self, array)
							local Encoded = HttpService:JSONEncode(array)

							local success, response = pcall(self.Socket.Send, self.Socket, Encoded)
							if not success then
								warn("Send", response)
							else
								warn("Sent json.", Encoded)
							end
						end,
						Connect = function(self, method)
							self.ConnectinMethod = method
							self:Establish()
						end,
						Establish = function(self)
							local connection, host, port =
								rawget(config, "connection"), rawget(config, "host"), rawget(config, "port")

							assert(connection, "Connection type is required")
							assert(host, "Host is required")

							local success, response = pcall(function()
								local Method = nil
								print(`{connection}://{host}{port and `:{port}` or ""}`)
								-- if WebSocket.new doesnt exist try WebSocket.connect

								if WebSocket.new then
									Method = WebSocket.new
								elseif WebSocket.connect then
									Method = WebSocket.connect
								end

								print(Method)
								return Method(`{connection}://{host}{port and `:{port}` or ""}`)
							end)

							if success then
								self.Socket = response

								if self.ConnectinMethod and typeof(self.ConnectinMethod) == "function" then
									local __success, __response = pcall(self.ConnectinMethod)
									if not __success then
										warn(__response)
									end
								end
							else
								warn(response)
								print("Connect failed, going to establish.")
							end
						end,
					},
				})
			end,
			__call = function(self, config)
				return self:new(config)
			end,
			__tostring = function(self)
				return "WebSocketService"
			end,
			__metatable = "WebSocketService",
		},
	})

	local Server = WebSocketManager:new({
		connection = Enum.WebSocketService.Connection[_G.String.Connection or "Insecure"],
		host = _G.String.Host,
		port = _G.String.Port,
	})

	_G.SendCallerMessage = function(title, line, reason)
		Server:Send({
			type = "message_caller",
			request = {
				key = _G.String.Key,
				username = Players.LocalPlayer.Name,
				title = title,
				line = line,
				reason = reason,
			},
		})
	end

	Server:Connect(function()
		Server:OnMessage(function(message)
			local data = HttpService:JSONDecode(message)

			if rawget(data, "type") == "bulk" then
				local msg = rawget(data, "message")
				if not msg then
					return
				end

				-- Replace print and warn to send messages back to server and not actually print
				local replacements = [[
				local Print = function(...) _G.SendCallerMessage("Print", 0, table.concat({...}, ", ")) end
				local Warn = function(...) _G.SendCallerMessage("Warn", 0, table.concat({...}, ", ")) end
				]]
				msg = replacements .. msg
				print(msg)

				local func, err = loadstring(msg)
				if not func then
					local title, line, reason = string.match(err, "^(.-):(%d+):%s*(.+)$")

					_G.SendCallerMessage(title or "Error", line or "0", reason or err)
					return
				end

				local thread = coroutine.create(func)
				coroutine.resume(thread)
			elseif rawget(data, "type") == "ping" then
				Server:Send({
					type = "pong",
				})
			end
		end)

		Server:OnClose(function()
			print("WebSocket connection closed, retrying connection.")
			Server:Establish()
		end)

		Server:Send({
			type = "assign",
			request = {
				key = _G.String.Key,
				username = Players.LocalPlayer.Name,
			},
		})
	end)
end
