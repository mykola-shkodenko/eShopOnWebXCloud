using System.Net;
using System.Net.Mime;
using System.Text.Json;
using System.Text.Json.Serialization;
using Azure;
using Azure.Identity;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.AzureFunctions;

public class OrderDeliveryProcessor
{
    private const string CosmosEnpoint = "COSMOS_ENDPOINT";
    private const string DatabaseName = "COSMOS_DATABASE";
    private const string ContainerName = "COSMOS_ORDERS_CONTAINER";    

    private readonly ILogger _logger;

    public OrderDeliveryProcessor(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<OrderDeliveryProcessor>();
    }

    [Function(nameof(OrderDeliveryProcessor))]
    public async Task<HttpResponseData> Run([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
    {
        _logger.LogInformation("Order delivery triggered");
        HttpResponseData response;
        try
        {
            var order = await JsonSerializer.DeserializeAsync<OrderRequestDtos.DeliveredOrder>(req.Body);
            
            if (order is null)
            {
                response = req.CreateResponse(HttpStatusCode.NoContent);
                response.WriteString($"Request body was not desirialized or is empty");
            }
            else
            {
                await SaveOrderAsync(order);

                response = req.CreateResponse(HttpStatusCode.OK);
                response.WriteString($"OrderId is {order.OrderId} and contains {order.OrderItems?.Count()} item(s) with final price {order.FinalPrice}");
            }            
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, $"Processing error: {ex.Message}");

            response = req.CreateResponse(HttpStatusCode.InternalServerError);
            response.WriteString($"Error: {ex.Message}");

        }
        response.Headers.Add("Content-Type", $"{MediaTypeNames.Text.Plain}; charset=utf-8");
        return response;
    }

    private async Task SaveOrderAsync(OrderRequestDtos.DeliveredOrder deliveredOrder)
    {
        var order = ToOrderDto(deliveredOrder);
        // New instance of CosmosClient class
        using CosmosClient client = new(
            accountEndpoint: GetVariable(CosmosEnpoint),
            tokenCredential: new DefaultAzureCredential()
        );

        var databaseName = GetVariable(DatabaseName);
        _logger.LogInformation($"Database name: {databaseName}");
        var database = client.GetDatabase(id: databaseName);

        var containerName = GetVariable(ContainerName);
        _logger.LogInformation($"Container name: {containerName}");
        var container = database.GetContainer(containerName);

        _logger.LogInformation($"Creatring order: {deliveredOrder.OrderId}");
        var savedOrder = await container.CreateItemAsync(item: order);

        _logger.LogInformation($"Order with id {deliveredOrder.OrderId} has been saved");
    }

    private static OrderCosmosDtos.Order ToOrderDto(OrderRequestDtos.DeliveredOrder request)
    {
        if (request.OrderItems is null)
            throw new ArgumentNullException(nameof(request.OrderItems));

        var items = request.OrderItems.Select(i => new OrderCosmosDtos.OrderItem(i.ItemId, i.Quantity, i.ItemPrice)).ToArray();

        if (request.ShippingAddress is null)
            throw new ArgumentNullException(nameof(request.ShippingAddress));

        var shipAddress = request.ShippingAddress;
        var address = new OrderCosmosDtos.Address(shipAddress.Country, request.ShippingAddress.State, request.ShippingAddress.City, request.ShippingAddress.Street, request.ShippingAddress.ZipCode);
        
        return new OrderCosmosDtos.Order(
                    Guid.NewGuid(),
                    request.OrderId,
                    request.FinalPrice,
                    items,
                    address
                );
    }

    private static string GetVariable(string key) => Environment.GetEnvironmentVariable(key)!;

    internal class OrderRequestDtos
    {
        internal record DeliveredOrder(int OrderId, decimal FinalPrice, IEnumerable<DeliveredOrderItem>? OrderItems, ShippingAddress? ShippingAddress);

        internal record DeliveredOrderItem(int ItemId, int Quantity, decimal ItemPrice);

        internal record ShippingAddress(string Country, string State, string City, string Street, string ZipCode);
    }
    
    internal class OrderCosmosDtos{
        internal record Order(Guid id, int orderId, decimal totalPrice, IEnumerable<OrderItem>? items, Address? address);
        internal record OrderItem(int itemId, int quantity, decimal price);

        internal record Address(string country, string state, string city, string street, string zipCode);
    }
    
}
