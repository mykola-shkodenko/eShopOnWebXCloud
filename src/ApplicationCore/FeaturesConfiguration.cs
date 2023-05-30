namespace Microsoft.eShopWeb.ApplicationCore;

public class FeaturesConfiguration
{
    public const string CONFIG_NAME = "Features";
    public bool OrderReserveEnabled { get; set; }
    public string? OrderReserveEventGridTopicEnpoint { get; set; }
    public string? AzureServiceBusFullNamespace { get; set; }
    public string? OrderReserverQueueName { get; set; }
    public bool OrderDeliveryEnabled { get; set; }
    public string? OrderDeliveryUrl { get; set; }
}
