using System.Text;
using System.Text.Json;
using Azure.Core.Serialization;
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using Azure.Storage.Blobs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace Microsoft.eShopWeb.AzureFunctions;

public class OrderItemsReserver
{
    private const string ServiceBusName = "ServiceBusConnection";
    private const string ServiceBusFullNamespaceKey = $"{ServiceBusName}__fullyQualifiedNamespace";
    //private const string ServiceBusRequestedQueueKey = "%AZURE_SERVICEBUS_ORDER_REQUESTED_QUEUE%";
    private const string ServiceBusFailedQueueKey = "AZURE_SERVICEBUS_ORDER_FAILED_QUEUE";

    private readonly ILogger _logger;

    public OrderItemsReserver(ILoggerFactory loggerFactory)
    {
        _logger = loggerFactory.CreateLogger<OrderItemsReserver>();
    }

    [Function(nameof(OrderItemsReserver))]
    public async Task Run([ServiceBusTrigger(
        queueName: "sbq-order-reservation-requested",
        Connection = ServiceBusName)] // Connection AzureWebJobsServiceBus
        byte[] message)
    {
        _logger.LogInformation("C# ServiceBus trigger function processed a request.");

        using MemoryStream stream = new MemoryStream(message);

        _logger.LogInformation($"Message size: {message.Length} bytes");

        var data = await JsonSerializer.DeserializeAsync<ReservedOrder>(stream, new JsonSerializerOptions()
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
            _logger.LogInformation("Creating blob with order details {OrderId}", order.OrderId);
            
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

            _logger.LogInformation("Blob '{BlobName}' has been uploaded to container '{ContainerClientName}'", blobName, containerClient.Name);
        }
        catch(Exception ex)
        {
            _logger.LogError(ex, "Order blob was not created for reason: {Message}", ex.Message);

            await SendOrderFailedEventAsync(order);
        }
    }

    private async Task SendOrderFailedEventAsync(ReservedOrder order)
    {
        _logger.LogInformation("Sending message with failed order {OrderId}", order.OrderId);
        // Example of a custom ObjectSerializer used to serialize the event payload to JSON
        var customSerializer = new JsonObjectSerializer(new JsonSerializerOptions()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });
       
        var clientOptions = new ServiceBusClientOptions
        {
            TransportType = ServiceBusTransportType.AmqpWebSockets
        };
        var serviceBusNamespace = GetVariable(ServiceBusFullNamespaceKey);
        var failedQueueName = GetVariable(ServiceBusFailedQueueKey);

        var client = new ServiceBusClient(serviceBusNamespace, new DefaultAzureCredential(),clientOptions);
        var sender = client.CreateSender(failedQueueName);

        // create a batch 
        using ServiceBusMessageBatch messageBatch = await sender.CreateMessageBatchAsync();

        // try adding a message to the batch
        if (!messageBatch.TryAddMessage(new ServiceBusMessage(await customSerializer.SerializeAsync(order))))
        {
            // if it is too large for the batch
            throw new Exception($"The message is too large to fit in the batch.");
        }

        try
        {
            // Use the producer client to send the batch of messages to the Service Bus queue
            await sender.SendMessagesAsync(messageBatch);
        }
        finally
        {
            // Calling DisposeAsync on client types is required to ensure that network
            // resources and other unmanaged objects are properly cleaned up.
            await sender.DisposeAsync();
            await client.DisposeAsync();
        }

        _logger.LogInformation("Message with failed order {OrderOrderId} has been send", order.OrderId);
    }
        
    private static string GetVariable(string key) => Environment.GetEnvironmentVariable(key)!;

    public class ReservedOrder
    {
        public int OrderId { get; set; }
        public IEnumerable<OrderItem>? OrderItems { get; set; }
    }

    public record OrderItem(int ItemId, int Quantity);
}
