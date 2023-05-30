using System;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.Extensions.Options;

namespace Microsoft.eShopWeb.ApplicationCore.Services;

public class FeatureProvider : IFeatureProvider
{
    private readonly FeaturesConfiguration _featuresConfiguration;

    public FeatureProvider(IOptions<FeaturesConfiguration> featuresConfiguration)
    {
        _featuresConfiguration = featuresConfiguration.Value;
    }

    public bool IsOrderReserverEnabled => _featuresConfiguration.OrderReserveEnabled;
    public string OrderReserverTopicEndpoint => GetRequiredUri(_featuresConfiguration.OrderReserveEventGridTopicEnpoint, nameof(FeaturesConfiguration.OrderReserveEventGridTopicEnpoint));

    public bool IsOrderDeliveryEnabled => _featuresConfiguration.OrderDeliveryEnabled;
    public string OrderDeliveryUri => GetRequiredUri(_featuresConfiguration.OrderDeliveryUrl, nameof(FeaturesConfiguration.OrderDeliveryUrl));

    public string AzureServiceBusFullNamespace => string.IsNullOrEmpty(_featuresConfiguration.AzureServiceBusFullNamespace)
        ? throw new NullReferenceException($"Config value '{nameof(FeaturesConfiguration.AzureServiceBusFullNamespace)}' is not defined")
        : _featuresConfiguration.AzureServiceBusFullNamespace;

    public string OrderReserverQueueName => string.IsNullOrEmpty(_featuresConfiguration.OrderReserverQueueName)
        ? throw new NullReferenceException($"Config value '{nameof(FeaturesConfiguration.OrderReserverQueueName)}' is not defined")
        : _featuresConfiguration.OrderReserverQueueName;

    private static string GetRequiredUri(string? url, string settingName)
        => string.IsNullOrEmpty(url)
                ? throw new NullReferenceException($"'{settingName}' was not defined")
                : url;
    private static bool GetBool(string? value)
    {
        bool.TryParse(value, out var result);
        return result;
    }
}
