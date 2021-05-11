using Azure.Identity;
using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace AzureIdentityDemo.Functions
{
    public class TriggerDemo
    {
        EventHubProducerClient _eventHubClient = null;
        ServiceBusClient _serviceBusClient = null;
        ServiceBusSender _serviceBusSender = null;
        CosmosClient _cosmosClient = null;
        public TriggerDemo(IConfiguration configuration)
        {
            _eventHubClient = new EventHubProducerClient(configuration["EventHub:NameSpace"], configuration["EventHub:Name"], new DefaultAzureCredential());
            _serviceBusClient = new ServiceBusClient(configuration["ServiceBus:NameSpace"], new DefaultAzureCredential());
            _serviceBusSender = _serviceBusClient.CreateSender(configuration["ServiceBus:Name"]);
            _cosmosClient = new CosmosClient(configuration["Cosmos:Address"], new DefaultAzureCredential());
        }

        // Note we just have the name of a queue. The Connection property is in the form of https://identitydemo.queue.core.windows.net
        // There's nothing secret in the config being loaded from your application config
        [FunctionName("TriggerDemo")]
        public async Task Run([QueueTrigger("%Queue:Name%", Connection = "Queue:Address")] string job, ILogger log, CancellationToken ct)
        {
            var data = new EventData(new BinaryData(job));
            await _eventHubClient.SendAsync(new EventData[] { data });
        }

        [FunctionName("EventHubTrigger")]
        public async Task EventHubTrigger([EventHubTrigger("%EventHub:Name%", Connection = "EventHub:NameSpace")] EventData[] events, ILogger log)
        {
            foreach (var eventdata in events)
            {
                ServiceBusMessage message = new ServiceBusMessage(eventdata.EventBody.ToString());
                await _serviceBusSender.SendMessageAsync(message);
            }
        }

        //[FunctionName("ServiceBusTrigger")]
        //public async Task ServiceBusTrigger([ServiceBusTrigger("%ServiceBus:Name%", Connection = "ServiceBus:NameSpace")] EventData[] events, ILogger log)
        //{
        //    _cosmosClient.GetContainer()

        //}

    }
}
