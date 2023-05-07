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
    public string OrderReserverTopicEndpoint => GetRequiredUri(_featuresConfiguration.OrderReserveTopicEnpoint, nameof(FeaturesConfiguration.OrderReserveTopicEnpoint));

    public bool IsOrderDeliveryEnabled => _featuresConfiguration.OrderDeliveryEnabled;
    public string OrderDeliveryUri => GetRequiredUri(_featuresConfiguration.OrderDeliveryUrl, nameof(FeaturesConfiguration.OrderDeliveryUrl));

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
