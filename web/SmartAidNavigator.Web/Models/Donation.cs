using System.Drawing;

namespace SmartAidNavigator.Web.Models;

public class Donation
{
    public long DonationId { get; set; }

    public long? DonorId { get; set; }
    public Donor? Donor { get; set; }

    public long? NgoId { get; set; }
    public Ngo? Ngo { get; set; }

    public long? ShelterId { get; set; }

    public string DonationType { get; set; } = "ITEM";
    public string Status { get; set; } = "PENDING";

    public bool DropoffRequired { get; set; }
    public bool DropoffConfirmed { get; set; }

    public string? ProofPhotoUrl { get; set; }
    public string? Remarks { get; set; }

    public DateTime CreatedAt { get; set; }

    public List<DonationItem> DonationItems { get; set; } = new();
    public Payment? Payment { get; set; }
    public Shelter? Shelter { get; set; }
}