using System.Net;
using System.Net.Mime;
using System.Text.Json;
using Azure.Identity;
using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.AzureFunctions;

public class OrderItemsReserver
{
    private readonly ILogger _logger;

    public OrderItemsReserver(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<OrderItemsReserver>();
    }

    [Function(nameof(OrderItemsReserver))]
    public async Task<HttpResponseData> Run([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req)
    {
        _logger.LogInformation("C# HTTP trigger function processed a request.");

        var reservedOrderItems = await System.Text.Json.JsonSerializer.DeserializeAsync<ReservedOrder>(req.Body);

        HttpResponseData response;
        if (reservedOrderItems is null)
        {
            response = req.CreateResponse(HttpStatusCode.NoContent);
            response.WriteString($"Request has not valid body");
        }
        else
        {
            await CreateBlocbAsync(reservedOrderItems);

            response = req.CreateResponse(HttpStatusCode.OK);
            response.WriteString($"OrderId is {reservedOrderItems.OrderId} and contains {reservedOrderItems.OrderItems?.Count()} item(s)");
        }
        response.Headers.Add("Content-Type", $"{MediaTypeNames.Text.Plain}; charset=utf-8" );        
        return response;
    }

    private async Task CreateBlocbAsync(ReservedOrder order)
    {
        var containerStorageUrl = GetVariable("ORDERS_CONTAINER_URL");

        var containerClient = new BlobContainerClient(new Uri(containerStorageUrl), new DefaultAzureCredential());
               
        await containerClient.CreateIfNotExistsAsync();

        string blobName = $"Order_{order.OrderId}_{order.OrderItems?.Count()}_{order.OrderItems?.Sum(i => i.Quantity)}.json";

        var blobClient = containerClient.GetBlobClient(blobName);

        using var memoryStream = new MemoryStream();
        await JsonSerializer.SerializeAsync(memoryStream, order.OrderItems);
        memoryStream.Position = 0;
        await blobClient.UploadAsync(memoryStream);

        _logger.LogInformation($"Blob '{blobName}' has been uploaded to container '{containerClient.Name}'");
    }

    private static string GetVariable(string key) => Environment.GetEnvironmentVariable(key)!;

    internal class ReservedOrder
    {
        public int OrderId { get; set; }
        public IEnumerable<OrderItem>? OrderItems { get; set; }
    }

    internal record OrderItem(int ItemId, int Quantity);
}
