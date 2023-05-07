using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.Json;
using System.Threading.Tasks;
using Azure.Core.Serialization;
using Azure.Identity;
using Azure.Messaging.EventGrid;
using Microsoft.eShopWeb.ApplicationCore.Entities.OrderAggregate;
using Microsoft.eShopWeb.ApplicationCore.Interfaces;

namespace Microsoft.eShopWeb.Infrastructure.Services;
internal class EventGridOrderReserver : IOrderReserver
{
    private readonly IAppLogger<EventGridOrderReserver> _logger;
    private readonly IFeatureProvider _featureProvider;

    public EventGridOrderReserver(
        IAppLogger<EventGridOrderReserver> logger,
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

        EventGridPublisherClient client = new EventGridPublisherClient(
            new Uri(_featureProvider.OrderReserverTopicEndpoint),
            new DefaultAzureCredential());

        // Example of a custom ObjectSerializer used to serialize the event payload to JSON
        var customSerializer = new JsonObjectSerializer(new JsonSerializerOptions()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        });

        // Add EventGridEvents to a list to publish to the topic
        List<EventGridEvent> eventsList = new List<EventGridEvent>
        {
            new OrderReservedEvent(
                "microsoft/eshopwebxcloud/order/reserved",
                await customSerializer.SerializeAsync(body)),
        };

        // Send the events
        await client.SendEventsAsync(eventsList);

        _logger.LogInformation($"Order '{order.Id}' has been send to order reservation service");
    }

    internal class OrderReservedEvent : EventGridEvent
    {
        public OrderReservedEvent(string subject, BinaryData data) 
            : base(subject, nameof(OrderReservedEvent), "1.0", data)
        {
        }
    }
}
