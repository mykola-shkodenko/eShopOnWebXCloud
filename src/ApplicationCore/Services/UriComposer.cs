using Microsoft.eShopWeb.ApplicationCore.Interfaces;

namespace Microsoft.eShopWeb.ApplicationCore.Services;

public class UriComposer : IUriComposer
{
    private readonly CatalogSettings _catalogSettings;
    private readonly OrderSettings _orderSettings;

    public UriComposer(CatalogSettings catalogSettings, OrderSettings orderSettings)
    {
        _catalogSettings = catalogSettings;
        _orderSettings = orderSettings;
    }

    public string OrderReserverUri => string.IsNullOrEmpty(_orderSettings.OrderReserveUrl) 
        ? throw new System.NullReferenceException($"'{nameof(OrderSettings.OrderReserveUrl)}' was not defined")
        : _orderSettings.OrderReserveUrl;

    public string ComposePicUri(string uriTemplate)
    {
        return uriTemplate.Replace("http://catalogbaseurltobereplaced", _catalogSettings.CatalogBaseUrl);
    }
}
