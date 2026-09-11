using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.ViewModels;

public class MyNgoInventoryVm
{
    public long NgoId { get; set; }
    public string NgoName { get; set; } = "";

    // Filters
    public string StockFilter { get; set; } = "in-stock";
    public int? CategoryId { get; set; }
    public string? Search { get; set; }
    public string? SourceType { get; set; }

    // Dropdown
    public List<InventoryCategoryFilterVm> Categories { get; set; } = new();

    // Stats
    public int TotalItemTypes { get; set; }
    public int InStockCount { get; set; }
    public int ZeroStockCount { get; set; }
    public int LowStockCount { get; set; }
    public int TotalQuantity { get; set; }

    public List<MyNgoInventoryRowVm> Rows { get; set; } = new();
}

public class MyNgoInventoryRowVm
{
    public long ItemId { get; set; }
    public int CategoryId { get; set; }
    public string CategoryName { get; set; } = "";
    public string ItemName { get; set; } = "";
    public string Unit { get; set; } = "";
    public int Quantity { get; set; }
    public int MinimumLevel { get; set; }
    public DateTime UpdatedAt { get; set; }

    public string? SourceType { get; set; }

    public string SourceTypeLabel => SourceType switch
    {
        "DONATION" => "Donation",
        "MANUAL_ADJUSTMENT" => "Manually Key-in",
        "DELIVERY" => "Delivery",
        "BENEFICIARY_NEED" => "Beneficiary Need",
        _ => "-"
    };

    public bool IsLowStock => MinimumLevel > 0 && Quantity < MinimumLevel;
    public bool IsZeroStock => Quantity <= 0;
}

public class MyNgoAddStockVm
{
    public string NgoName { get; set; } = "";

    public string? Note { get; set; }

    public List<MyNgoAddStockItemVm> Items { get; set; } = new();
}

public class MyNgoAddStockItemVm
{
    public long ItemId { get; set; }

    public string ItemName { get; set; } = "";

    public string CategoryName { get; set; } = "";

    public string Unit { get; set; } = "";

    public int CurrentQuantity { get; set; }

    public int MinimumLevel { get; set; }

    [Range(0, 100000, ErrorMessage = "Quantity cannot be negative.")]
    public int AddQuantity { get; set; }
}