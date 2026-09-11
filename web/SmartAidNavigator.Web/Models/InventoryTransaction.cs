using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class InventoryTransaction
{
    public long TransactionId { get; set; }

    [Required, MaxLength(10)]
    public string OwnerType { get; set; } = "SHELTER";

    public long OwnerId { get; set; }

    public long ItemId { get; set; }
    public AidItem? Item { get; set; }

    [Required, MaxLength(10)]
    public string TransactionType { get; set; } = "IN";

    public int Quantity { get; set; }

    [MaxLength(30)]
    public string SourceType { get; set; } = "MANUAL_ADJUSTMENT";

    public long? SourceId { get; set; }

    [MaxLength(255)]
    public string? Note { get; set; }

    public long? CreatedBy { get; set; }
    public User? CreatedByUser { get; set; }

    public DateTime CreatedAt { get; set; }
}
