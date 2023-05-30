using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Azure.Core.Serialization;
using Azure.Identity;
using Azure.Messaging.ServiceBus;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;

namespace Microsoft.eShopWeb.Infrastructure.Services;
internal class ServiceBusOrderReserver : IOrderReserver
{
    private readonly IAppLogger<ServiceBusOrderReserver> _logger;
    private readonly IFeatureProvider _featureProvider;

    public ServiceBusOrderReserver(
        IAppLogger<ServiceBusOrderReserver> logger,
        IFeatureProvider featureProvider)
    {
        _logger = logger;
        _featureProvider = featureProvider;
    }
    public async Task ReserveAsync(Order order)
    {
        if (!_featureProvider.IsOrderReserverEnabled)
        {
            _logger.LogWarning("Order reservation is disabled");
            return;
        }
        var body = new
        {
            OrderId = order.Id,
            OrderItems = order.OrderItems.Select(item =>
                new
                {
                    ItemId = item.Id,
                    Quantity = item.Units
                }).ToArray()
        };
        // Example of a custom ObjectSerializer used to serialize the event payload to JSON
        var customSerializer = new JsonObjectSerializer(new JsonSerializerOptions()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });


        // name of your Service Bus queue
        // the client that owns the connection and can be used to create senders and receivers
        ServiceBusClient client;

        // the sender used to publish messages to the queue
        ServiceBusSender sender;

        // The Service Bus client types are safe to cache and use as a singleton for the lifetime
        // of the application, which is best practice when messages are being published or read
        // regularly.
        //
        // Set the transport type to AmqpWebSockets so that the ServiceBusClient uses the port 443. 
        // If you use the default AmqpTcp, ensure that ports 5671 and 5672 are open.
        var clientOptions = new ServiceBusClientOptions
        {
            TransportType = ServiceBusTransportType.AmqpWebSockets
        };
        //TODO: Replace the "<NAMESPACE-NAME>" and "<QUEUE-NAME>" placeholders.
        client = new ServiceBusClient(
            //"<NAMESPACE-NAME>.servicebus.windows.net",
            _featureProvider.AzureServiceBusFullNamespace,
            new DefaultAzureCredential(),
            clientOptions);
        sender = client.CreateSender(_featureProvider.OrderReserverQueueName);

        // create a batch 
        using ServiceBusMessageBatch messageBatch = await sender.CreateMessageBatchAsync();

                // try adding a message to the batch
        if (!messageBatch.TryAddMessage(new ServiceBusMessage(await customSerializer.SerializeAsync(body))))
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
        
        _logger.LogInformation($"Order '{order.Id}' has been send to order reservation service");
    }    
}
