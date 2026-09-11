namespace SmartAidNavigator.Web.ViewModels;

public class ShelterRequestIndexVm
{
    public string? Search { get; set; }
    public string? Status { get; set; }
    public string SortBy { get; set; } = "newest";

    public int TotalCount { get; set; }
    public int PendingCount { get; set; }
    public int ConfirmedCount { get; set; }
    public int ArrivedCount { get; set; }
    public int CancelledCount { get; set; }

    public List<ShelterRequestListVm> Rows { get; set; } = new();
}