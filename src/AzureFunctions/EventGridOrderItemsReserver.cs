/*using System.Text.Json;
using Azure.Core.Serialization;
using Azure.Identity;
using Azure.Messaging.EventGrid;
using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Polly;
using Polly.Retry;

namespace Microsoft.eShopWeb.AzureFunctions;

public class OrderItemsReserver
{
    private readonly ILogger _logger;

    public OrderItemsReserver(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<OrderItemsReserver>();
    }

    [Function(nameof(OrderItemsReserver))]
    public async Task Run([EventGridTrigger()] EventGridEvent @event)
    {
        _logger.LogInformation("C# EventGrid trigger function processed a request.");

        _logger.LogInformation($"Event: {JsonSerializer.Serialize(@event)} Data: {@event.Data?.ToString()}");

        if (@event.Data is null)
        {
            throw new NullReferenceException("Event data is null");
        }
        var data = @event.Data.ToObjectFromJson<ReservedOrder>(new JsonSerializerOptions()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });
        if (data is null)
        {
            throw new NullReferenceException("Deserialized event data is null");
        }
        
        await CreateBlobWithRetryAsync(data);

        _logger.LogInformation($"Order {data.OrderId} has been reserved successfully");
    }

    private async Task CreateBlobWithRetryAsync(ReservedOrder order)
    {
        try
        {
            string blobName = $"Order_{order.OrderId}_{order.OrderItems?.Count()}_{order.OrderItems?.Sum(i => i.Quantity)}.json";

            var containerStorageUrl = GetVariable("ORDERS_CONTAINER_URL");

            var options = new BlobClientOptions();
            options.Retry.MaxDelay = TimeSpan.FromSeconds(4);
            options.Retry.MaxRetries = 2;
            var containerClient = new BlobContainerClient(new Uri(containerStorageUrl), new DefaultAzureCredential(), options);

            await containerClient.CreateIfNotExistsAsync();

            var blobClient = containerClient.GetBlobClient(blobName);

            using var memoryStream = new MemoryStream();
            await JsonSerializer.SerializeAsync(memoryStream, order.OrderItems);
            memoryStream.Position = 0;
            await blobClient.UploadAsync(memoryStream);

            _logger.LogInformation($"Blob '{blobName}' has been uploaded to container '{containerClient.Name}'");
        }
        catch(Exception ex)
        {
            _logger.LogError(ex, $"Order blob was not created for reason: {ex.Message}");

            await SendOrderFailedEventAsync(order);
        }
    }

    private async Task SendOrderFailedEventAsync(ReservedOrder order)
    {
        EventGridPublisherClient client = new EventGridPublisherClient(
                        new Uri(GetVariable("EVENTGRID_ORDER_FAILED_TOPIC_ENDPOINT")),
                        new DefaultAzureCredential());

        // Example of a custom ObjectSerializer used to serialize the event payload to JSON
        var customSerializer = new JsonObjectSerializer(new JsonSerializerOptions()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        // Add EventGridEvents to a list to publish to the topic
        List<EventGridEvent> eventsList = new List<EventGridEvent>
            {
                new OrderFailedEvent(
                    "microsoft/eshopwebxcloud/order/failed",
                    await customSerializer.SerializeAsync(order)),
            };

        // Send the events
        await client.SendEventsAsync(eventsList);

        _logger.LogInformation($"Event for failed order {order.OrderId} has been send");
    }
    
    internal class OrderFailedEvent : EventGridEvent
    {
        public OrderFailedEvent(string subject, BinaryData data)
            : base(subject, nameof(OrderFailedEvent), "1.0", data)
        {
        }
    }

    private static string GetVariable(string key) => Environment.GetEnvironmentVariable(key)!;

    public class ReservedOrder
    {
        public int OrderId { get; set; }
        public IEnumerable<OrderItem>? OrderItems { get; set; }
    }

    public record OrderItem(int ItemId, int Quantity);
}
*/
