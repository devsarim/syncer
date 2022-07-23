local Net = require(script.Parent.Parent.Net)

return Net.CreateDefinitions({
  StateChanged = Net.Definitions.ServerToClientEvent(),
  StoreCreated = Net.Definitions.ServerToClientEvent(),

  FetchStores = Net.Definitions.ServerAsyncFunction({
    Net.Middleware.RateLimit({
      MaxRequestsPerMinute = 1
    })
  })
})