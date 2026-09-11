namespace SmartAidNavigator.Web.Models;

public class DonationItem
{
    public long DonationItemId { get; set; }

    public long DonationId { get; set; }
    public Donation? Donation { get; set; }

    public long ItemId { get; set; }
    public AidItem? Item { get; set; }

    public int Quantity { get; set; }
}