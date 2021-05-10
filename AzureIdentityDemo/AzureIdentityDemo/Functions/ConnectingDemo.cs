using Azure.Identity;
using Azure.Storage.Queues;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.AzureAppConfiguration;
using Microsoft.Extensions.Logging;
using Microsoft.FeatureManagement;
using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace AzureIdentityDemo
{
    public class ConnectingDemo
    {
		private QueueClient _client;
		private readonly IFeatureManagerSnapshot _featureManagerSnapshot;
		private readonly IConfigurationRefresher _configurationRefresher;

		public ConnectingDemo(IConfiguration configuration, IFeatureManagerSnapshot featureManagerSnapshot, IConfigurationRefresherProvider refresherProvider)
		{
			// Connects to a storage queue client. Address looks like https://identitydemo.queue.core.windows.net
			// The queuename is just a valid queue name.
			_client = new QueueClient(new Uri($"{configuration["Queue:Uri"]}/{configuration["Queue:Name"]}"),
									  new DefaultAzureCredential(),
									  new QueueClientOptions()
									  {
										  MessageEncoding = QueueMessageEncoding.Base64
									  });
			_client.CreateIfNotExists();

			// Grab the feature flag API
			_featureManagerSnapshot = featureManagerSnapshot;
			_configurationRefresher = refresherProvider.Refreshers.First();
		}


		[FunctionName(nameof(ScheduleJob))]
		public async Task<IActionResult> ScheduleJob(
		   [HttpTrigger(AuthorizationLevel.Anonymous, "post", Route = "schedule")] HttpRequest req,		   
		   ILogger log)
		{
			await _configurationRefresher.TryRefreshAsync();
			if (await _featureManagerSnapshot.IsEnabledAsync("RunLoadTests"))
			{
				string job = await new StreamReader(req.Body).ReadToEndAsync();
				await _client.SendMessageAsync(job);
			}
			return (IActionResult) new OkResult();
		}
	}
}
