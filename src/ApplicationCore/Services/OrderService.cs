using System;
using System.Linq;
using System.Net.Http;
using System.Net.Mime;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Ardalis.GuardClauses;
using Microsoft.eShopWeb.ApplicationCore.Entities;
using Microsoft.eShopWeb.ApplicationCore.Entities.BasketAggregate;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;
using Microsoft.eShopWeb.ApplicationCore.Specifications;

namespace Microsoft.eShopWeb.ApplicationCore.Services;

public class OrderService : IOrderService
{
    private readonly IRepository<Order> _orderRepository;
    private readonly IUriComposer _uriComposer;
    private readonly IAppLogger<BasketService> _logger;
    private readonly IFeatureProvider _featureProvider;
    private readonly IOrderReserver _orderReserver;
    private readonly IRepository<Basket> _basketRepository;
    private readonly IRepository<CatalogItem> _itemRepository;

    public OrderService(
        IRepository<Basket> basketRepository,
        IRepository<CatalogItem> itemRepository,
        IRepository<Order> orderRepository,
        IUriComposer uriComposer,
        IAppLogger<BasketService> logger,
        IFeatureProvider featureProvider,
        IOrderReserver orderReserver)
    {
        _orderRepository = orderRepository;
        _uriComposer = uriComposer;
        _logger = logger;
        _featureProvider = featureProvider;
        _orderReserver = orderReserver;
        _basketRepository = basketRepository;
        _itemRepository = itemRepository;
    }

    public async Task CreateOrderAsync(int basketId, Address shippingAddress)
    {
        var basketSpec = new BasketWithItemsSpecification(basketId);
        var basket = await _basketRepository.FirstOrDefaultAsync(basketSpec);

        Guard.Against.Null(basket, nameof(basket));
        Guard.Against.EmptyBasketOnCheckout(basket.Items);

        var catalogItemsSpecification = new CatalogItemsSpecification(basket.Items.Select(item => item.CatalogItemId).ToArray());
        var catalogItems = await _itemRepository.ListAsync(catalogItemsSpecification);

        var items = basket.Items.Select(basketItem =>
        {
            var catalogItem = catalogItems.First(c => c.Id == basketItem.CatalogItemId);
            var itemOrdered = new CatalogItemOrdered(catalogItem.Id, catalogItem.Name, _uriComposer.ComposePicUri(catalogItem.PictureUri));
            var orderItem = new OrderItem(itemOrdered, basketItem.UnitPrice, basketItem.Quantity);
            return orderItem;
        }).ToList();

        var order = new Order(basket.BuyerId, shippingAddress, items);

        await _orderRepository.AddAsync(order);        

        await _orderReserver.ReserveAsync(order);

        await DeliverOrderAsync(order);
    }

    private async Task DeliverOrderAsync(Order order)
    {
        if (!_featureProvider.IsOrderDeliveryEnabled)
        {
            _logger.LogWarning("Order delivery is disabled");
            return;
        }

        var body = new
        {
            OrderId = order.Id,
            FinalPrice = order.OrderItems.Sum(i => i.Units * i.UnitPrice),
            OrderItems = order.OrderItems.Select(item =>
                new {
                    ItemId = item.Id,
                    ItemPrice = item.UnitPrice,
                    Quantity = item.Units
                }).ToArray(),
            ShippingAddress = new
            {
                order.ShipToAddress.Country,
                order.ShipToAddress.State,
                order.ShipToAddress.City,
                order.ShipToAddress.Street,
                order.ShipToAddress.ZipCode
            }
        };
        var result = await PostAsync(_featureProvider.OrderDeliveryUri, body);
        if (!result.IsSuccessStatusCode)
            throw new Exception($"Order '{order.Id}' was delivered with error '{result.StatusCode}' and message '{await result.Content.ReadAsStringAsync()}'");

        _logger.LogInformation($"Order '{order.Id}' has been send to order delivery service");
    }

    private static async Task<HttpResponseMessage> PostAsync(string uri, object body)
    {
        var json = JsonSerializer.Serialize(body);
        var stringContent = new StringContent(json, Encoding.UTF8, MediaTypeNames.Application.Json);
        var httpClient = new HttpClient();
        return await httpClient.PostAsync(uri, stringContent);
    }
}
