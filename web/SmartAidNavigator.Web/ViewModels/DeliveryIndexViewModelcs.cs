using Microsoft.AspNetCore.Mvc.Rendering;
using SmartAidNavigator.Web.Models;
using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.ViewModels;

public class DeliveryIndexViewModel
{
    public string NgoName { get; set; } = "";

    // Filters
    public string Status { get; set; } = "ALL";
    public long? ShelterId { get; set; }
    public int? PriorityId { get; set; }
    public DateOnly? ScheduledFrom { get; set; }
    public DateOnly? ScheduledTo { get; set; }
    public string? Search { get; set; }
    public string SortBy { get; set; } = "created-desc";

    // Dropdowns
    public List<SelectListItem> Shelters { get; set; } = new();
    public List<SelectListItem> Priorities { get; set; } = new();

    // Stats
    public int ActiveCount { get; set; }
    public int PlannedCount { get; set; }
    public int RoutedCount { get; set; }
    public int InTransitCount { get; set; }
    public int DeliveredCount { get; set; }
    public int CancelledCount { get; set; }
    public int TotalDeliveryCount { get; set; }

    public List<DeliveryListRowVm> Deliveries { get; set; } = new();
}

public class DeliveryListRowVm
{
    public long DeliveryId { get; set; }

    public string ShelterName { get; set; } = "";
    public string? ShelterCity { get; set; }
    public string? ShelterState { get; set; }

    public DeliveryStatus Status { get; set; }

    public DateOnly? ScheduledDate { get; set; }
    public string? Notes { get; set; }

    public int? PriorityId { get; set; }
    public string? PriorityName { get; set; }
    public decimal? PriorityScore { get; set; }

    public DateTime CreatedAt { get; set; }

    public int TotalQuantity => Items.Sum(x => x.Quantity);
    public int ItemTypeCount => Items.Count;

    public List<DeliveryListItemVm> Items { get; set; } = new();
}

public class DeliveryListItemVm
{
    public long ItemId { get; set; }
    public string ItemName { get; set; } = "";
    public string Unit { get; set; } = "";
    public int Quantity { get; set; }
}

public class DeliveryDetailVm
{
    public long DeliveryId { get; set; }

    public string NgoName { get; set; } = "";

    public long ShelterId { get; set; }
    public string ShelterName { get; set; } = "";
    public string? ShelterPhone { get; set; }
    public string? ShelterEmail { get; set; }
    public string? ShelterAddress { get; set; }
    public string? ShelterCity { get; set; }
    public string? ShelterState { get; set; }
    public string? ShelterPostalCode { get; set; }

    public DeliveryStatus Status { get; set; }

    public DateOnly? ScheduledDate { get; set; }
    public string? Notes { get; set; }
    public string? ImageLink { get; set; }
    public int? PriorityId { get; set; }
    public string? PriorityName { get; set; }
    public decimal? PriorityScore { get; set; }

    public DateTime CreatedAt { get; set; }

    public int TotalQuantity => Items.Sum(x => x.Quantity);
    public int ItemTypeCount => Items.Count;

    public List<DeliveryListItemVm> Items { get; set; } = new();
    public List<DeliveryTrackingRowVm> TrackingUpdates { get; set; } = new();
}

public class DeliveryTrackingRowVm
{
    public DeliveryStatus Status { get; set; }
    public string? Note { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class DeliveryEditVm
{
    public long DeliveryId { get; set; }

    public string NgoName { get; set; } = "";

    [Required]
    public long ShelterId { get; set; }

    public string? SelectedShelterName { get; set; }
    public decimal? SelectedShelterLatitude { get; set; }
    public decimal? SelectedShelterLongitude { get; set; }

    public DeliveryStatus Status { get; set; }

    public DateOnly? ScheduledDate { get; set; }

    public int? PriorityId { get; set; }

    public string? Notes { get; set; }

    public DateTime CreatedAt { get; set; }

    public List<DeliveryCreateItemVm> DeliveryItems { get; set; } = new()
    {
        new DeliveryCreateItemVm()
    };

    public List<SelectListItem> Shelters { get; set; } = new();

    public List<SelectListItem> Priorities { get; set; } = new();

    public List<SelectListItem> Items { get; set; } = new();
}