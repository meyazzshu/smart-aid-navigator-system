namespace SmartAidNavigator.Web.Models;

public class ShelterInventory
{
    public long InventoryId { get; set; }

    public long ShelterId { get; set; }
    public Shelter? Shelter { get; set; }

    public long ItemId { get; set; }
    public AidItem? Item { get; set; }

    public int Quantity { get; set; }
    public int MinimumLevel { get; set; }

    public DateTime UpdatedAt { get; set; }
}
