using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.ViewModels;

public class UserCreateVm
{
    [Required]
    [Display(Name = "Full Name")]
    public string FullName { get; set; } = "";

    [Required]
    [EmailAddress]
    public string Email { get; set; } = "";

    [Display(Name = "Phone Number")]
    public string? Phone { get; set; }

    [Display(Name = "IC / Passport")]
    public string? IcOrPassport { get; set; }

    [Display(Name = "Gender")]
    public string? Gender { get; set; }

    [Display(Name = "Date of Birth")]
    public DateOnly? DateOfBirth { get; set; }

    [Display(Name = "Address Line")]
    public string? AddressLine { get; set; }

    [Display(Name = "City")]
    public string? City { get; set; }

    [Display(Name = "State")]
    public string? State { get; set; }

    [Display(Name = "Postal Code")]
    public string? PostalCode { get; set; }

    [Required]
    [Display(Name = "Role")]
    public int RoleId { get; set; }

    [Display(Name = "Account Status")]
    public bool IsActive { get; set; } = true;

    [Required]
    [MinLength(6)]
    [Display(Name = "Password")]
    public string Password { get; set; } = "";
}