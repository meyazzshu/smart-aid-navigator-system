using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.ViewModels;

public class NgoCreateVm
{
    // NGO details
    [Required]
    [Display(Name = "NGO Name")]
    public string NgoName { get; set; } = "";

    public string? Description { get; set; }
    public string? Phone { get; set; }

    [EmailAddress]
    public string? Email { get; set; }

    public bool IsActive { get; set; } = true;

    public bool IsTaxExempt { get; set; }
    public string? TaxExemptionNo { get; set; }

    public string? AddressLine { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? PostalCode { get; set; }

    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }

    // Owner account details
    [Required]
    [Display(Name = "Owner Full Name")]
    public string OwnerFullName { get; set; } = "";

    [Required]
    [EmailAddress]
    [Display(Name = "Owner Email")]
    public string OwnerEmail { get; set; } = "";

    [Display(Name = "Owner Phone")]
    public string? OwnerPhone { get; set; }

    [Display(Name = "Owner IC / Passport")]
    public string? OwnerIcOrPassport { get; set; }

    [Display(Name = "Owner Gender")]
    public string? OwnerGender { get; set; }

    [Display(Name = "Owner Date of Birth")]
    public DateOnly? OwnerDateOfBirth { get; set; }

    [Required]
    [MinLength(6)]
    [Display(Name = "Owner Password")]
    public string OwnerPassword { get; set; } = "";

    public string OwnerStaffType { get; set; } = "NGO Staff";
    public string OwnerStaffTitle { get; set; } = "Owner";
}