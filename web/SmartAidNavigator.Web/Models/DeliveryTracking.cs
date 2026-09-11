using Microsoft.AspNetCore.Mvc;
using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class DeliveryTracking
{
    public long TrackingId { get; set; }

    public long DeliveryId { get; set; }
    public Delivery? Delivery { get; set; }

    public DeliveryStatus Status { get; set; }

    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }

    [MaxLength(255)]
    public string? Note { get; set; }

    public DateTime CreatedAt { get; set; }
}

