@maxLength(30)
param applicationName string = 'identitydemo-${uniqueString(resourceGroup().id)}'
param featureFlagAddress string

param location string = resourceGroup().location

param databaseName string = 'Tasks'
param containerName string = 'Items'

param serviceBusNamespaceName string ='servicebus17645'
param serviceBusQueueName string = 'servicebusqueue48353'

param eventHubSku string = 'Standard'

var eventHubNamespaceName = 'eventhubns54365'
var eventHubName = 'eventhub'
var storageAccountName = 'stor54365'
var storageQueueName = 'jobs'

// All the various AD role id's we'll be using
var storageaccountdatacontributorRoleId = '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'

var cosmosAccountName = toLower(applicationName)
var websiteName = applicationName // why not just use the param directly?
var hostingPlanName = applicationName // why not just use the param directly?

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2020-04-01' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
    // this means you must used RBAC
    disableKeyBasedMetadataWriteAccess: true
  }
}
resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-03-15' = {
  name: '${cosmos.name}/demo'
  properties: {
    resource: {
      id: 'demo'
    }
  }
}
resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-03-15' = {
  name: '${database.name}/democontainer'
  properties:{
    resource: {
      id: 'democontainer'
    }
  }
}
 

resource farm 'Microsoft.Web/serverFarms@2020-06-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource appinsights 'Microsoft.Insights/components@2020-02-02-preview' ={
  name: '${websiteName}-ai'
  location: location
  kind: 'web'
  properties: {
    'Application_Type': 'web'   
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
}

resource storageQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2021-02-01' ={
  name: '${storageAccount.name}/default/${storageQueueName}'
}

resource website 'Microsoft.Web/sites@2020-06-01' = {
  name: websiteName
  location: location
  identity:{
    type: 'SystemAssigned'
  }
  kind: 'functionapp'
  properties: {
    serverFarmId: farm.id
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appinsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          'name': 'FUNCTIONS_EXTENSION_VERSION'
          'value': '~3'
        }
        {
          'name': 'FUNCTIONS_WORKER_RUNTIME'
          'value': 'dotnet'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'Queue:Address__serviceUri'
          value: 'https://${storageAccount.name}.queue.core.windows.net'
        }
        {
          name: 'Queue:Uri'
          value: 'https://${storageAccount.name}.queue.core.windows.net'
        }
        {
          name: 'Queue:Name'
          value: storageQueueName
        }
        {
          name: 'CosmosDb:Account'
          value: cosmos.properties.documentEndpoint
        }
        {
          name: 'CosmosDb:DatabaseName'
          value: databaseName
        }
        {
          name: 'CosmosDb:ContainerName'
          value: containerName
        }
        {
          name: 'FeatureFlagAddress'
          value: featureFlagAddress
        }
      ]
    }
  }
}

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2017-04-01' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {}
}

resource serviceBusQueue 'Microsoft.ServiceBus/namespaces/queues@2017-04-01' = {
  name: '${serviceBusNamespace.name}/${serviceBusQueueName}'
  properties: {
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 1024
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: 'P10675199DT2H48M5.4775807S'
    deadLetteringOnMessageExpiration: false
    duplicateDetectionHistoryTimeWindow: 'PT10M'
    maxDeliveryCount: 10
    autoDeleteOnIdle: 'P10675199DT2H48M5.4775807S'
    enablePartitioning: false
    enableExpress: false
  }
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2018-01-01-preview' = {
  name: eventHubNamespaceName
  location: location
  sku: {
    name: eventHubSku
    tier: eventHubSku
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2017-04-01' = {
  name: '${eventHubNamespace.name}/${eventHubName}'
  properties: {
    messageRetentionInDays: 7
    partitionCount: 1
  }
}

// Give the managed identity contributor role to Cosmos
resource cosmosRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(contributorRoleId, cosmos.id)
  scope: cosmos
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: website.identity.principalId
  }
}

// Give the managed identity reader role to EventHub
resource eventHubRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(readerRoleId, eventHub.id)
  scope: eventHub
  properties: {

   // principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: website.identity.principalId
  }
}

// Give the managed identity contributor role to Cosmos
resource serviceBusRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(contributorRoleId, serviceBusQueue.id)
  scope: serviceBusQueue
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: website.identity.principalId
  }
}

//Give the managed identity the data contributor role to the relevant storage queue
resource storageQueueRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storageaccountdatacontributorRoleId, storageQueue.id)
  scope: storageQueue
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageaccountdatacontributorRoleId)
    principalId: website.identity.principalId
  }  
}
