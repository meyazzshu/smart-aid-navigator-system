using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.ViewModels;

public class NgoBeneficiaryNeedIndexVm
{
    public long NgoId { get; set; }
    public string NgoName { get; set; } = "";

    public string? Search { get; set; }
    public string? Status { get; set; }
    public string? Priority { get; set; }
    public long? ShelterId { get; set; }
    public string SortBy { get; set; } = "newest";

    public int TotalCount { get; set; }
    public int AwaitingDonationCount { get; set; }
    public int ReadyForPickupCount { get; set; }
    public int HighCriticalCount { get; set; }

    public List<NgoBeneficiaryNeedShelterFilterVm> Shelters { get; set; } = new();
    public List<NgoBeneficiaryNeedRowVm> Rows { get; set; } = new();
}

public class NgoBeneficiaryNeedShelterFilterVm
{
    public long ShelterId { get; set; }
    public string ShelterName { get; set; } = "";
}

public class NgoBeneficiaryNeedRowVm
{
    public long NeedId { get; set; }
    public string BeneficiaryName { get; set; } = "";
    public string ShelterName { get; set; } = "";
    public long ShelterId { get; set; }

    public long ItemId { get; set; }
    public string ItemName { get; set; } = "";
    public string CategoryName { get; set; } = "";
    public string Unit { get; set; } = "";

    public int RequiredQuantity { get; set; }
    public int ShelterStockQuantity { get; set; }
    public int NgoStockQuantity { get; set; }
    public bool CanCreateDelivery { get; set; }

    public string Priority { get; set; } = "";
    public string RequestStatus { get; set; } = "";
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; }
}