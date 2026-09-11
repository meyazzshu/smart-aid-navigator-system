using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartAidNavigator.Web.Models;

[Table("delivery_group_deliveries")]
public class DeliveryGroupDelivery
{
    [Key]
    [Column("delivery_group_delivery_id")]
    public long DeliveryGroupDeliveryId { get; set; }

    [Column("delivery_group_id")]
    public long DeliveryGroupId { get; set; }

    public DeliveryGroup? DeliveryGroup { get; set; }

    [Column("delivery_id")]
    public long DeliveryId { get; set; }

    public Delivery? Delivery { get; set; }

    [Column("requested_stop_order")]
    public int? RequestedStopOrder { get; set; }

    [Column("optimized_stop_order")]
    public int? OptimizedStopOrder { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}