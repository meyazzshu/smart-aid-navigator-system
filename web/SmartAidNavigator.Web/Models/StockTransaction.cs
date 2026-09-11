using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class StockTransaction
{
    public long TransactionId { get; set; }

    public long ShelterId { get; set; }
    public Shelter? Shelter { get; set; }

    public long ItemId { get; set; }
    public AidItem? Item { get; set; }

    // IN / OUT / ADJUST
    [MaxLength(10)]
    public string TransactionType { get; set; } = "IN";

    public int Quantity { get; set; }

    [MaxLength(255)]
    public string? Note { get; set; }

    public long? CreatedBy { get; set; }
    public User? CreatedByUser { get; set; }

    public DateTime CreatedAt { get; set; }
}
