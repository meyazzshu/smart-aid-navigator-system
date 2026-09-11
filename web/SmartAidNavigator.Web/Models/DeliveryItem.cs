using System.ComponentModel.DataAnnotations.Schema;

namespace SmartAidNavigator.Web.Models;

public class DeliveryItem
{
    public long DeliveryItemId { get; set; }

    public long DeliveryId { get; set; }

    public Delivery? Delivery { get; set; }

    public long ItemId { get; set; }

    public AidItem? Item { get; set; }

    public int Quantity { get; set; }
}