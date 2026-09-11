using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace SmartAidNavigator.Web.Models;

[Table("delivery_groups")]
public class DeliveryGroup
{
    [Key]
    [Column("delivery_group_id")]
    public long DeliveryGroupId { get; set; }

    [Column("ngo_id")]
    public long NgoId { get; set; }

    public Ngo? Ngo { get; set; }

    [Column("assigned_to")]
    public long? AssignedTo { get; set; }

    public User? AssignedUser { get; set; }

    [Required]
    [Column("group_name")]
    [StringLength(160)]
    public string GroupName { get; set; } = "";

    [Column("status")]
    public DeliveryStatus Status { get; set; } = DeliveryStatus.PLANNED;

    [Column("scheduled_date")]
    public DateOnly? ScheduledDate { get; set; }

    [Column("origin_lat")]
    public decimal? OriginLat { get; set; }

    [Column("origin_lng")]
    public decimal? OriginLng { get; set; }

    [Column("total_distance_km")]
    public decimal? TotalDistanceKm { get; set; }

    [Column("total_eta_minutes")]
    public int? TotalEtaMinutes { get; set; }

    [Column("google_maps_url")]
    public string? GoogleMapsUrl { get; set; }

    [Column("optimized_at")]
    public DateTime? OptimizedAt { get; set; }

    [Column("notes")]
    [StringLength(255)]
    public string? Notes { get; set; }

    [Column("created_at")]
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<DeliveryGroupDelivery> GroupDeliveries { get; set; } = new List<DeliveryGroupDelivery>();
}