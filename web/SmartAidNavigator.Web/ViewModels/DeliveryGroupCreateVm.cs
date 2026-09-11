using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace SmartAidNavigator.Web.ViewModels;

public class DeliveryGroupCreateVm
{
    [Required]
    [Display(Name = "Group Name")]
    public string GroupName { get; set; } = "";

    [Display(Name = "Assigned Driver / NGO Staff")]
    public long? AssignedTo { get; set; }

    [Display(Name = "Scheduled Date")]
    public DateOnly? ScheduledDate { get; set; }

    [Display(Name = "Notes")]
    public string? Notes { get; set; }

    [Display(Name = "Choose Existing Deliveries")]
    public List<long> SelectedDeliveryIds { get; set; } = new();

    public List<DeliveryGroupDeliveryCardVm> DeliveryCards { get; set; } = new();

    public List<SelectListItem> StaffOptions { get; set; } = new();
}

public class DeliveryGroupDeliveryCardVm
{
    public long DeliveryId { get; set; }

    public string ShelterName { get; set; } = "-";

    public string AddressLine { get; set; } = "";

    public string City { get; set; } = "";

    public string State { get; set; } = "";

    public string Status { get; set; } = "";

    public string StatusLabel { get; set; } = "";

    public string StatusCssClass { get; set; } = "badge-planned";

    public DateOnly? ScheduledDate { get; set; }

    public string ScheduledDateText => ScheduledDate?.ToString("yyyy-MM-dd") ?? "Not scheduled";
    public DateTime CreatedAt { get; set; }

    public string CreatedAtText => CreatedAt.ToString("yyyy-MM-dd HH:mm");

    public string CreatedAtSortValue => CreatedAt.ToString("yyyyMMddHHmmss");

    public string LocationSortValue => LocationText.ToLower();

    public string PriorityName { get; set; } = "-";

    public string PriorityCssClass { get; set; } = "";

    public decimal? PriorityScore { get; set; }

    public decimal? DistanceKm { get; set; }

    public int? EtaMinutes { get; set; }

    public string LocationText
    {
        get
        {
            var parts = new List<string>();

            if (!string.IsNullOrWhiteSpace(City))
            {
                parts.Add(City);
            }

            if (!string.IsNullOrWhiteSpace(State))
            {
                parts.Add(State);
            }

            return parts.Count > 0 ? string.Join(", ", parts) : "-";
        }
    }

    public string ItemsSummary { get; set; } = "No items added yet";

    public int ItemTypeCount { get; set; }

    public int TotalQuantity { get; set; }

    public bool IsSelected { get; set; }
}