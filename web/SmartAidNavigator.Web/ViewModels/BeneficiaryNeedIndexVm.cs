using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.ViewModels;

public class BeneficiaryNeedIndexVm
{
    public string ShelterName { get; set; } = "";

    public string? Search { get; set; }
    public string? Priority { get; set; }
    public string? Status { get; set; }
    public string? SortBy { get; set; }

    public int TotalCount { get; set; }
    public int HighCriticalCount { get; set; }
    public int MediumCount { get; set; }
    public int LowCount { get; set; }

    public int SubmittedCount { get; set; }
    public int ReviewCount { get; set; }
    public int AwaitingDonationCount { get; set; }
    public int ReadyForPickupCount { get; set; }
    public int FulfilledCount { get; set; }

    public List<BeneficiaryNeed> Rows { get; set; } = new();
}