type StateFetchCallback = (playerThatInvoked: Player, storeObject: Rodux.Store, ...any) -> any

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local IS_SERVER = RunService:IsServer()
local Packages = script.Parent.Parent

local Rodux = require(Packages.Rodux)
local Promise = require(Packages.Promise)
local t = require(Packages.t)

local NetDefinitions = require(script.Parent.remoteDefinitions)
local StateChanged = NetDefinitions.Server:Get("StateChanged")
local FetchStores = NetDefinitions.Server:Get("FetchStores")
local StoreCreated = NetDefinitions.Server:Get("StoreCreated")

local serverStores: {[string]: Rodux.Store} = {}

local function logError(prefix, err)
  error(("[%s] %s"):format(prefix, err))
end

local function replicationMiddleware(nextDispatch, store: Rodux.Store)
  return function (action)
    nextDispatch(action)

    if (action.REPLICATE_PLAYER) then
      StateChanged:SendToPlayer(action.REPLICATE_PLAYER, store._name, action)
    elseif (action.REPLICATE_PLAYERS) then
      StateChanged:SendToPlayers(action.REPLICATE_PLAYERS, store._name, action)
    elseif (action.REPLICATE_EXCEPT) then
      StateChanged:SendToAllPlayersExcept(action.REPLICATE_EXCEPT, store._name, action)
    else
      StateChanged:SendToAllPlayers(store._name, action)
    end
  end
end

local function getClientStores(player: Player)
  local stores: {[string]: {state: {}, reducer: Rodux.Reducer}} = {}

  for name, store in pairs(serverStores) do
    stores[name] = {state = store._fetchCallback and store._fetchCallback(player, store) or store:getState(), reducer = store._reducerFile}
  end

  return stores
end

local createStoreArgs = t.tuple(t.instanceIsA("ModuleScript"), t.optional(t.callback), t.string)
local createStore = function (reducer: ModuleScript, fetchCallback: StateFetchCallback?, name: string)
  local valid, err = createStoreArgs(reducer, fetchCallback, name)
  if (not valid) then
    logError("syncer.createStore", err)
  end

  assert(IS_SERVER, "'createStore' can only be called from the server")
  assert(reducer:IsDescendantOf(ReplicatedStorage), "Bad argument #1 to 'createStore', expected 'ModuleScript' accessible by the server and the clients")

  --* Construct and define extra properties
  local store = Rodux.Store.new(require(reducer), nil, {
    replicationMiddleware
  })
  store._reducerFile = reducer
  store._fetchCallback = fetchCallback
  store._name = name

  --* Define helper methods for replication
  function store:dispatchPlayer(action, player: Player)
    action.REPLICATE_PLAYER = player
    store:dispatch(action)
  end

  function store:dispatchPlayers(action, players: {Player})
    action.REPLICATE_PLAYERS = players
    store:dispatch(action)
  end

  function store:dispatchExcept(action, players: {Player} | Player)
    action.REPLICATE_EXCEPT = players
    store:dispatch(action)
  end

  serverStores[name] = store

  --* Replicate the creation of this store to all players
  for _, player in ipairs(Players:GetPlayers()) do
    StoreCreated:SendToPlayer(player, getClientStores(player)) 
  end

  return store
end

local getStoreArgs = t.tuple(t.string)
local function getStore(storeName: string)
  local valid, err = getStoreArgs(storeName)
  if (not valid) then
    logError("syncer.getStore", err)
  end

  return Promise.new(function(res, rej)
    local store, waitStart = nil, tick()
    repeat
      store = serverStores[storeName]
      task.wait()
    until store or tick() - waitStart >= 30

    if (store) then
      res(store)
    else
      rej()
    end
  end)
end

FetchStores:SetCallback(getClientStores)

return {
  getStore = getStore,
  createStore = createStore,
}