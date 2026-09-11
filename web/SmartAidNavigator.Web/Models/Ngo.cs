using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class Ngo
{
    public long NgoId { get; set; }

    [Required, MaxLength(160)]
    public string NgoName { get; set; } = "";

    public string? Description { get; set; }

    [MaxLength(30)]
    public string? Phone { get; set; }

    [MaxLength(190)]
    public string? Email { get; set; }

    [MaxLength(120)]
    public string? TaxExemptionNo { get; set; }

    public bool IsTaxExempt { get; set; }

    [MaxLength(255)]
    public string? AddressLine { get; set; }

    [MaxLength(100)]
    public string? City { get; set; }

    [MaxLength(100)]
    public string? State { get; set; }

    [MaxLength(20)]
    public string? PostalCode { get; set; }

    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }

    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }

    public long? ApprovedBy { get; set; }
    public DateTime? ApprovedAt { get; set; }

    public User? ApprovedByUser { get; set; }
    public ICollection<Shelter> Shelters { get; set; } = new List<Shelter>();
    public ICollection<DeliveryRoute> Routes { get; set; } = new List<DeliveryRoute>();
    public ICollection<Delivery> Deliveries { get; set; } = new List<Delivery>();
}
