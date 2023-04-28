namespace Microsoft.eShopWeb.ApplicationCore.Interfaces;

public interface IFeatureProvider
{
    bool IsOrderReserverEnabled { get; }
    string OrderReserverUri { get; }
    bool IsOrderDeliveryEnabled { get; }
    string OrderDeliveryUri { get; }
}
