namespace SmartAidNavigator.Web.ViewModels;

public class ShelterRequestListVm
{
    public long RequestId { get; set; }

    public string FullName { get; set; } = "";

    public string? Phone { get; set; }

    public string? Email { get; set; }

    public int TotalPeople { get; set; }

    public string Status { get; set; } = "";

    public DateTime CreatedAt { get; set; }

    public int DependentCount { get; set; }
}