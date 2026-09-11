using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartAidNavigator.Web.Models;

public class Delivery
{
    public long DeliveryId { get; set; }

    public long NgoId { get; set; }
    public Ngo? Ngo { get; set; }

    public long ShelterId { get; set; }
    public Shelter? Shelter { get; set; }

    public long? AssignedTo { get; set; }
    public User? AssignedUser { get; set; }

    public int? PriorityId { get; set; }
    public PriorityCategory? PriorityCategory { get; set; }

    // If you added FK to routes (recommended)
    public long? RouteId { get; set; }
    public DeliveryRoute? Route { get; set; }



    //public DeliveryStatus Status { get; set; } = DeliveryStatus.PLANNED;
    public DeliveryStatus Status { get; set; }

    public DateOnly? ScheduledDate { get; set; }

    public string? Notes { get; set; }

    // computed by routing/prioritization algorithm
    public decimal? PriorityScore { get; set; }
    public decimal? DistanceKm { get; set; }
    public int? EtaMinutes { get; set; }

    public string? ImageLink { get; set; }

    public DateTime CreatedAt { get; set; }

    public ICollection<DeliveryTracking> TrackingUpdates { get; set; } = new List<DeliveryTracking>();

    public ICollection<DeliveryItem> DeliveryItems { get; set; } = new List<DeliveryItem>();

    public ICollection<DeliveryGroupDelivery> DeliveryGroupDeliveries { get; set; } = new List<DeliveryGroupDelivery>();
}
