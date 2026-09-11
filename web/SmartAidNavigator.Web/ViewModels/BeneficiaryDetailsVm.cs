namespace SmartAidNavigator.Web.ViewModels;

public class BeneficiaryDetailsVm
{
    public long BeneficiaryId { get; set; }
    public long PersonId { get; set; }
    public long ShelterId { get; set; }

    public string FullName { get; set; } = "";
    public string? IcOrPassport { get; set; }
    public string? Phone { get; set; }
    public string? Gender { get; set; }
    public DateOnly? DateOfBirth { get; set; }

    public string? AddressLine { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? PostalCode { get; set; }

    public string Status { get; set; } = "ACTIVE";
    public DateTime? AdmittedAt { get; set; }
    public DateTime? DischargedAt { get; set; }
    public DateTime CreatedAt { get; set; }

    public string ShelterName { get; set; } = "";
}