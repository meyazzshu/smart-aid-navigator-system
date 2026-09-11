using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.ViewModels;

public class BeneficiaryUpsertVm
{
    public long? BeneficiaryId { get; set; }

    [Required, MaxLength(160)]
    public string FullName { get; set; } = "";

    [MaxLength(40)]
    public string? IcOrPassport { get; set; }

    [MaxLength(30)]
    public string? Phone { get; set; }

    [MaxLength(20)]
    public string? Gender { get; set; }

    [DataType(DataType.Date)]
    public DateOnly? DateOfBirth { get; set; }

    [MaxLength(255)]
    public string? AddressLine { get; set; }

    [MaxLength(100)]
    public string? City { get; set; }

    [MaxLength(100)]
    public string? State { get; set; }

    [MaxLength(20)]
    public string? PostalCode { get; set; }

    [MaxLength(20)]
    public string Status { get; set; } = "ACTIVE";
}
