using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class Beneficiary
{
    public long BeneficiaryId { get; set; }

    public long PersonId { get; set; }
    public Person? Person { get; set; }

    public long ShelterId { get; set; }
    public Shelter? Shelter { get; set; }

    [MaxLength(20)]
    public string Status { get; set; } = "ACTIVE";

    public DateTime? AdmittedAt { get; set; }
    public DateTime? DischargedAt { get; set; }

    public int? AgeAtRegistration { get; set; }

    public DateTime CreatedAt { get; set; }

    public ICollection<BeneficiaryNeed> Needs { get; set; } = new List<BeneficiaryNeed>();
}
