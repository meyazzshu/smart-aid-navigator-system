using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class Shelter
{
    public long ShelterId { get; set; }

    [Required, MaxLength(160)]
    public string ShelterName { get; set; } = "";

    public long? NgoId { get; set; }
    public Ngo? Ngo { get; set; }

    [MaxLength(30)]
    public string? Phone { get; set; }

    [MaxLength(190)]
    public string? Email { get; set; }

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

    public int? Capacity { get; set; }

    public int CurrentOccupancy { get; set; }

    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }
    public long? ApprovedBy { get; set; }
    public DateTime? ApprovedAt { get; set; }

    public User? ApprovedByUser { get; set; }

    public ICollection<ShelterInventory> Inventory { get; set; } = new List<ShelterInventory>();
    public ICollection<Delivery> Deliveries { get; set; } = new List<Delivery>();
    public ICollection<DeliveryRouteStop> RouteStops { get; set; } = new List<DeliveryRouteStop>();
    public ICollection<ShelterAssessment> Assessments { get; set; } = new List<ShelterAssessment>();
    public ICollection<Beneficiary> Beneficiaries { get; set; } = new List<Beneficiary>();

}
