@maxLength(30)
param applicationName string = 'identitydemo-${uniqueString(resourceGroup().id)}'

param location string = resourceGroup().location

@allowed([
  'F1'
  'D1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1'
  'P2'
  'P3'
  'P4'
])
param appServicePlanTier string = 'F1'

@minValue(1)
@maxValue(3)
param appServicePlanInstances int = 1

param repositoryUrl string = 'https://github.com/Azure-Samples/cosmos-dotnet-core-todo-app.git'
param branch string = 'master'

param databaseName string = 'Tasks'
param containerName string = 'Items'
param identityName string = 'ManageIdentity'


param serviceBusNamespaceName string ='servicebus17645'
param serviceBusQueueName string = 'servicebusqueue48353'

param eventHubSku string = 'Standard'

var eventHubNamespaceName = 'eventhubns54365'
var eventHubName = 'eventhub'



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

resource farm 'Microsoft.Web/serverFarms@2020-06-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: appServicePlanTier
    capacity: appServicePlanInstances
  }
  properties: {}
}

resource website 'Microsoft.Web/sites@2020-06-01' = {
  name: websiteName
  location: location
  identity:{
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: farm.id
    siteConfig: {
      appSettings: [
        {
          name: 'CosmosDb:Account'
          value: cosmos.properties.documentEndpoint
        }
        {
          name: 'CosmosDb:Key'
          value: listKeys(cosmos.id, cosmos.apiVersion).primaryMasterKey
        }
        {
          name: 'CosmosDb:DatabaseName'
          value: databaseName
        }
        {
          name: 'CosmosDb:ContainerName'
          value: containerName
        }
      ]
    }
  }
}


resource srcCtrl 'Microsoft.Web/sites/sourcecontrols@2020-06-01' = {
  name: '${website.name}/web'
  properties: {
    repoUrl: repositoryUrl
    branch: branch
    isManualIntegration: true
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

// Create our managed identity
resource msi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName 
  location: location
}

// Give the managed identity contributor role to Cosmos
resource cosmosRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(contributorRoleId, cosmos.id)
  scope: cosmos
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', contributorRoleId)
    principalId: msi.properties.principalId
  }
}

// Give the managed identity reader role to EventHub
resource eventHubRole 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(readerRoleId, eventHub.id)
  scope: eventHub
  properties: {

   // principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: msi.properties.principalId
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
