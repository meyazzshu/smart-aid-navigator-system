using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class AidItem
{
    public long ItemId { get; set; }

    public int CategoryId { get; set; }
    public AidCategory? Category { get; set; }

    [Required, MaxLength(120)]
    public string ItemName { get; set; } = "";

    [Required, MaxLength(30)]
    public string Unit { get; set; } = "unit";

    public bool IsActive { get; set; } = true;

    public ICollection<ShelterInventory> ShelterInventories { get; set; } = new List<ShelterInventory>();
}
