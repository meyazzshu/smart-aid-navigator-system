namespace SmartAidNavigator.Web.Models;

public class NgoInventory
{
    public long InventoryId { get; set; }

    public long NgoId { get; set; }
    public Ngo? Ngo { get; set; }

    public long ItemId { get; set; }
    public AidItem? Item { get; set; }

    public int Quantity { get; set; }
    public int MinimumLevel { get; set; }

    public DateTime UpdatedAt { get; set; }
}