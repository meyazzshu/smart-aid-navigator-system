namespace SmartAidNavigator.Web.Models;

public class Donor
{
    public long DonorId { get; set; }

    public long PersonId { get; set; }
    public Person? Person { get; set; }

    public string DonorType { get; set; } = "REGISTERED_USER";

    public DateTime CreatedAt { get; set; }

    public List<Donation> Donations { get; set; } = new();
}