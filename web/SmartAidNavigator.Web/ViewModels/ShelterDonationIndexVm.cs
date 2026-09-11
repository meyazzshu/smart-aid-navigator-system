using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.ViewModels;

public class ShelterDonationIndexVm
{
    public string ShelterName { get; set; } = "";
    public string? Status { get; set; }
    public string? Type { get; set; }

    public int PendingCount { get; set; }
    public int ConfirmedCount { get; set; }
    public int CompletedCount { get; set; }
    public int CancelledCount { get; set; }

    public List<Donation> Donations { get; set; } = new();
}