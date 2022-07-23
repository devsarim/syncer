local RunService = game:GetService("RunService")

local IS_SERVER, IS_CLIENT = RunService:IsServer(), RunService:IsClient()

if (IS_SERVER) then
  return require(script.syncerServer)  
elseif (IS_CLIENT) then
  return require(script.syncerClient)
end