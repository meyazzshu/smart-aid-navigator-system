using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.ViewModels;

public class MyNgoStockAdjustVm
{
    public long ItemId { get; set; }

    [Required]
    public string TransactionType { get; set; } = "IN";

    [Range(0, 999999)]
    public int Quantity { get; set; } = 1;

    public string? Note { get; set; }
}