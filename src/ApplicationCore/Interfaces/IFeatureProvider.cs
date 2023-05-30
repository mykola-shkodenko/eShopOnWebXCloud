namespace Microsoft.eShopWeb.ApplicationCore.Interfaces;

public interface IFeatureProvider
{
    bool IsOrderReserverEnabled { get; }
    string OrderReserverTopicEndpoint { get; }
    string AzureServiceBusFullNamespace { get; }
    string OrderReserverQueueName { get; }
    bool IsOrderDeliveryEnabled { get; }
    string OrderDeliveryUri { get; }
}
