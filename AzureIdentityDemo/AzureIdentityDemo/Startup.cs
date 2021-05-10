using System;
using System.Collections.Generic;
using System.Text;
using Azure.Identity;
using Microsoft.Azure.Functions.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Microsoft.FeatureManagement;

[assembly: FunctionsStartup(typeof(AzureIdentityDemo.Startup))]
namespace AzureIdentityDemo
{
    class Startup : FunctionsStartup
    {
        public override void ConfigureAppConfiguration(IFunctionsConfigurationBuilder builder)
        {
            builder.ConfigurationBuilder.AddAzureAppConfiguration(options =>
            {
                options.Connect(new Uri(Environment.GetEnvironmentVariable("FeatureFlagAddress")), new DefaultAzureCredential())
                       .Select("_")
                       .UseFeatureFlags();
            });
        }

        public override void Configure(IFunctionsHostBuilder builder)
        {
            builder.Services.AddAzureAppConfiguration();
            builder.Services.AddFeatureManagement();
        }
    }
}
