using Microsoft.AspNetCore.Mvc.Rendering;
using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.ViewModels;

public class StaffManagementIndexVm
{
    public string PageTitle { get; set; } = "";
    public string PageSubtitle { get; set; } = "";

    public string BackAction { get; set; } = "";
    public string CreateAction { get; set; } = "";
    public string DeactivateAction { get; set; } = "";
    public string ReactivateAction { get; set; } = "";
    public string RemoveAction { get; set; } = "";
    

    public List<StaffManagementRowVm> Rows { get; set; } = new();
}

public class StaffManagementRowVm
{
    public long UserId { get; set; }
    public long EntityId { get; set; }

    public string FullName { get; set; } = "";
    public string Email { get; set; } = "";
    public string? Phone { get; set; }

    public string EntityName { get; set; } = "";
    public string StaffTitle { get; set; } = "";

    public bool IsActive { get; set; }
    public bool IsSelf { get; set; }
}

public class StaffCreateVm
{
    public string PageTitle { get; set; } = "";
    public string PostAction { get; set; } = "";
    public string BackAction { get; set; } = "";
    public string StaffType { get; set; } = "";

    [Required]
    [Display(Name = "Full Name")]
    public string FullName { get; set; } = "";

    [Required]
    [EmailAddress]
    public string Email { get; set; } = "";

    public string? Phone { get; set; }
    public string? IcOrPassport { get; set; }
    public string? Gender { get; set; }
    public DateOnly? DateOfBirth { get; set; }

    public string? AddressLine { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? PostalCode { get; set; }

    public long? NgoId { get; set; }
    public long? ShelterId { get; set; }

    public string? StaffTitle { get; set; }

    public bool IsActive { get; set; } = true;

    [Required]
    [MinLength(6)]
    public string Password { get; set; } = "";

    public List<SelectListItem> NgoOptions { get; set; } = new();
    public List<SelectListItem> ShelterOptions { get; set; } = new();
}


public class StaffDetailsVm
{
    public long UserId { get; set; }
    public long PersonId { get; set; }

    public string FullName { get; set; } = "";
    public string Email { get; set; } = "";
    public string? Phone { get; set; }
    public string? IcOrPassport { get; set; }
    public string? Gender { get; set; }
    public DateOnly? DateOfBirth { get; set; }

    public string? AddressLine { get; set; }
    public string? City { get; set; }
    public string? State { get; set; }
    public string? PostalCode { get; set; }

    public bool IsActive { get; set; }
    public bool IsGuest { get; set; }
    public DateTime CreatedAt { get; set; }

    public string RolesCsv { get; set; } = "";

    public string StaffType { get; set; } = "";
    public string StaffTitle { get; set; } = "";
    public string LinkedUnitName { get; set; } = "";
    public string LinkedUnitType { get; set; } = "";
    public long? LinkedUnitId { get; set; }

    public string BackAction { get; set; } = "";
}

public class StaffEditVm
{
    public long UserId { get; set; }
    public long PersonId { get; set; }

    public string PageTitle { get; set; } = "";
    public string BackAction { get; set; } = "";
    public string StaffType { get; set; } = "";
    public string LinkedUnitName { get; set; } = "";

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

    [Display(Name = "Staff Title")]
    public string? StaffTitle { get; set; }

    [Display(Name = "Account Status")]
    public bool IsActive { get; set; }

    [Display(Name = "New Password")]
    public string? NewPassword { get; set; }

    public bool IsNgoStaff { get; set; }
}