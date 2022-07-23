local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rodux = require(ReplicatedStorage.Packages.Rodux)
local Promise = require(ReplicatedStorage.Packages.Promise)

local NetDefinitions = require(script.Parent.remoteDefinitions)
local StateChanged = NetDefinitions.Client:Get("StateChanged")
local FetchStores = NetDefinitions.Client:Get("FetchStores")
local StoreCreated = NetDefinitions.Client:Get("StoreCreated")

local clientStores: {[string]: Rodux.Store} = {}

local function clientStateChanged(storeName: string, action)
  local store = clientStores[storeName]
  if (not store) then return end

  store:dispatch(action)
end

local function syncClientStores(stores)
  for name, object in pairs(stores) do
    if (clientStores[name]) then continue end

    clientStores[name] = Rodux.Store.new(require(object.reducer), object.state, {
      -- Rodux.loggerMiddleware
    })
  end
end

FetchStores:CallServerAsync():andThen(syncClientStores):catch(warn):await()
StoreCreated:Connect(syncClientStores)
StateChanged:Connect(clientStateChanged)

return {
  getStore = function(storeName: string)
    return Promise.new(function(res, rej)
      local store, waitStart = nil, tick()

      repeat
        store = clientStores[storeName]
        task.wait()
      until store or tick() - waitStart >= 30

      if (store) then
        res(store)
      else
        rej()
      end
    end)
  end,

  getStores = function()
    return clientStores
  end
}