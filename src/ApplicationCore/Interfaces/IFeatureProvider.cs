namespace Microsoft.eShopWeb.ApplicationCore.Interfaces;

public interface IFeatureProvider
{
    bool IsOrderReserverEnabled { get; }
    string OrderReserverTopicEndpoint { get; }
    bool IsOrderDeliveryEnabled { get; }
    string OrderDeliveryUri { get; }
}
