using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class DeliveryRoute
{
    public long RouteId { get; set; }

    public long NgoId { get; set; }
    public Ngo? Ngo { get; set; }

    public long? GeneratedBy { get; set; }
    public User? GeneratedByUser { get; set; }

    [Required, MaxLength(80)]
    public string Algorithm { get; set; } = "DIJKSTRA";

    public decimal? TotalDistanceKm { get; set; }
    public int? TotalEtaMinutes { get; set; }

    public DateTime CreatedAt { get; set; }

    public ICollection<DeliveryRouteStop> Stops { get; set; } = new List<DeliveryRouteStop>();
    public ICollection<Delivery> Deliveries { get; set; } = new List<Delivery>();
}
