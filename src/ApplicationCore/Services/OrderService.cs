using System;
using System.Linq;
using System.Net.Http;
using System.Net.Http.Json;
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
    private readonly IRepository<Basket> _basketRepository;
    private readonly IRepository<CatalogItem> _itemRepository;

    public OrderService(IRepository<Basket> basketRepository,
        IRepository<CatalogItem> itemRepository,
        IRepository<Order> orderRepository,
        IUriComposer uriComposer,
        IAppLogger<BasketService> logger)
    {
        _orderRepository = orderRepository;
        _uriComposer = uriComposer;
        _logger = logger;
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

        await PostOrderAsync(order);
    }

    private async Task PostOrderAsync(Order order)
    {
        var jsonContent = JsonSerializer.Serialize(new { 
            OrderId = order.Id,
            OrderItems = order.OrderItems.Select(item => 
                new { 
                    ItemId = item.Id,
                    Quantity = item.Units })
            .ToArray() 
        });
        var content = new StringContent(jsonContent, Encoding.UTF8, MediaTypeNames.Application.Json);
        var httpClient = new HttpClient();
        var result = await httpClient.PostAsync(_uriComposer.OrderReserverUri, content);
        if (!result.IsSuccessStatusCode)
            throw new Exception($"Order '{order.Id}' was posted with error '{result.StatusCode}' and message '{await result.Content.ReadAsStringAsync()}'");

        _logger.LogInformation($"Order '{order.Id}' has been send to OrderReserver service");
    }
}
