
@description('The name of the Cosmos DB')
param accountName string

@description('The location of the Cosmos DB')
param location string

@description('Resource tag for Jumpstart Agora')
param resourceTags object = {
  Project: 'Jumpstart_Agora'
}

@description('The name of the Azure Data Explorer POS database')
param posOrdersDBName string = 'posOrders'

resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts@2023-03-01-preview' = {
  name: accountName
  kind: 'GlobalDocumentDB'
  location: location
  tags: resourceTags
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

resource posOrdersDB 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  parent: cosmosDB
  name: posOrdersDBName
  properties: {
    options: {}
    resource: {
      id: posOrdersDBName
    }
  }
}

resource posOrdersContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-05-15' = {
  parent: posOrdersDB
  name: 'orders'
  properties: {
    resource: {
      id: 'orders'
      partitionKey: {
        paths: [
          '/orderID'
        ]
        kind: 'Hash'
      }
    }
  }
}

output cosmosDBName string = cosmosDB.name
output cosmosDBEndpoint string = cosmosDB.properties.documentEndpoint
