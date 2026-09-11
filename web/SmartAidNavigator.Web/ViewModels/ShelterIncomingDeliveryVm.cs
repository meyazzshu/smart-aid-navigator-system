using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.ViewModels;

public class ShelterIncomingDeliveryIndexVm
{
    public string ShelterName { get; set; } = "";

    public string? Search { get; set; }
    public string? Status { get; set; }
    public string SortBy { get; set; } = "newest";

    public int TotalCount { get; set; }
    public int PlannedCount { get; set; }
    public int RoutedCount { get; set; }
    public int InTransitCount { get; set; }
    public int DeliveredCount { get; set; }
    public int CancelledCount { get; set; }

    public List<ShelterIncomingDeliveryRowVm> Rows { get; set; } = new();
}

public class ShelterIncomingDeliveryRowVm
{
    public long DeliveryId { get; set; }

    public string NgoName { get; set; } = "";
    public DeliveryStatus Status { get; set; }

    public DateOnly? ScheduledDate { get; set; }
    public DateTime CreatedAt { get; set; }

    public decimal? DistanceKm { get; set; }
    public int? EtaMinutes { get; set; }

    public int ItemTypeCount { get; set; }
    public int TotalQuantity { get; set; }

    public string? Notes { get; set; }

    public List<ShelterIncomingDeliveryItemVm> Items { get; set; } = new();
}

public class ShelterIncomingDeliveryDetailVm
{
    public long DeliveryId { get; set; }

    public string ShelterName { get; set; } = "";
    public string NgoName { get; set; } = "";

    public DeliveryStatus Status { get; set; }

    public DateOnly? ScheduledDate { get; set; }
    public DateTime CreatedAt { get; set; }

    public decimal? DistanceKm { get; set; }
    public int? EtaMinutes { get; set; }

    public string? Notes { get; set; }
    public string? ImageLink { get; set; }

    public List<ShelterIncomingDeliveryItemVm> Items { get; set; } = new();
    public List<ShelterIncomingDeliveryTrackingVm> TrackingUpdates { get; set; } = new();

    public int ItemTypeCount => Items.Count;
    public int TotalQuantity => Items.Sum(x => x.Quantity);
}

public class ShelterIncomingDeliveryItemVm
{
    public long ItemId { get; set; }
    public string ItemName { get; set; } = "";
    public string Unit { get; set; } = "";
    public int Quantity { get; set; }
}

public class ShelterIncomingDeliveryTrackingVm
{
    public DeliveryStatus Status { get; set; }
    public string? Note { get; set; }
    public DateTime CreatedAt { get; set; }
}