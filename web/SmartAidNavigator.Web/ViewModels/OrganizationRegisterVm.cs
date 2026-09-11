using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.ViewModels;

public class OrganizationRegisterVm
{
    [Required]
    public string RegisterType { get; set; } = ""; // NGO or SHELTER

    // Person / account
    [Required]
    [Display(Name = "Full Name")]
    public string FullName { get; set; } = "";

    [Display(Name = "IC / Passport")]
    public string? IcOrPassport { get; set; }

    [Required]
    [EmailAddress]
    public string Email { get; set; } = "";

    [Required]
    public string Phone { get; set; } = "";

    [Required]
    [MinLength(6)]
    public string Password { get; set; } = "";

    [Required]
    [Compare(nameof(Password))]
    [Display(Name = "Confirm Password")]
    public string ConfirmPassword { get; set; } = "";

    // Organization / shelter common
    [Required]
    [Display(Name = "Organization / Shelter Name")]
    public string EntityName { get; set; } = "";

    [Display(Name = "Description")]
    public string? Description { get; set; }

    [Display(Name = "Official Phone")]
    public string? EntityPhone { get; set; }

    [EmailAddress]
    [Display(Name = "Official Email")]
    public string? EntityEmail { get; set; }

    // NGO only
    [Display(Name = "Tax Exemption Number")]
    public string? TaxExemptionNo { get; set; }

    [Display(Name = "Tax Exempt NGO")]
    public bool IsTaxExempt { get; set; }

    // Shelter only
    [Display(Name = "Capacity")]
    public int? Capacity { get; set; }

    // Google location
    [Required]
    [Display(Name = "Search Location")]
    public string PlaceName { get; set; } = "";

    [Required]
    [Display(Name = "Address")]
    public string AddressLine { get; set; } = "";

    public string? City { get; set; }

    public string? State { get; set; }

    [Display(Name = "Postal Code")]
    public string? PostalCode { get; set; }

    [Required]
    public decimal? Latitude { get; set; }

    [Required]
    public decimal? Longitude { get; set; }
}