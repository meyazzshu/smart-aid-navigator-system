using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc.Rendering;

namespace SmartAidNavigator.Web.ViewModels;

public class ShelterCreateVm
{
    // Shelter details
    [Required]
    [Display(Name = "Shelter Name")]
    public string ShelterName { get; set; } = "";

    public long? NgoId { get; set; }

    public string? Phone { get; set; }

    [EmailAddress]
    public string? Email { get; set; }

    public int? Capacity { get; set; }
    public int CurrentOccupancy { get; set; } = 0;

    public bool IsActive { get; set; } = true;

    public string? AddressLine { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? PostalCode { get; set; }

    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }

    // Shelter manager account details
    [Required]
    [Display(Name = "Manager Full Name")]
    public string ManagerFullName { get; set; } = "";

    [Required]
    [EmailAddress]
    [Display(Name = "Manager Email")]
    public string ManagerEmail { get; set; } = "";

    [Display(Name = "Manager Phone")]
    public string? ManagerPhone { get; set; }

    [Display(Name = "Manager IC / Passport")]
    public string? ManagerIcOrPassport { get; set; }

    [Display(Name = "Manager Gender")]
    public string? ManagerGender { get; set; }

    [Display(Name = "Manager Date of Birth")]
    public DateOnly? ManagerDateOfBirth { get; set; }

    [Required]
    [MinLength(6)]
    [Display(Name = "Manager Password")]
    public string ManagerPassword { get; set; } = "";

    public string ManagerStaffType { get; set; } = "Shelter Manager";
    public string ManagerStaffTitle { get; set; } = "Shelter Manager";

    public List<SelectListItem> NgoOptions { get; set; } = new();
}