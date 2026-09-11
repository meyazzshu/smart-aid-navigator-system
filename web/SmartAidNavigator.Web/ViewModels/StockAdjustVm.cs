using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.ViewModels;

public class StockAdjustVm
{
    [Required]
    public long ItemId { get; set; }

    [Required]
    public string TransactionType { get; set; } = "IN"; // IN / OUT / ADJUST

    [Range(1, 100000)]
    public int Quantity { get; set; }

    public string? Note { get; set; }
}
