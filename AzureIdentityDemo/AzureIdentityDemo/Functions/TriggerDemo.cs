using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Text;
using System.Threading;

namespace AzureIdentityDemo.Functions
{
    public static class TriggerDemo
    {
        // Note we just have the name of a queue. The Connection property is in the form of https://identitydemo.queue.core.windows.net
        // There's nothing secret in the config being loaded from your application config

        [FunctionName("TriggerDemo")]
        public static void Run([QueueTrigger("%Queue:Name%", Connection = "Queue:Address")] string job, ILogger log, CancellationToken ct)
        {
            log.LogInformation($"got a job {job}");
        }
    }
}
