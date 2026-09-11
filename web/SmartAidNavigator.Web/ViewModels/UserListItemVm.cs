namespace SmartAidNavigator.Web.ViewModels;

public class UserListItemVm
{
    public long UserId { get; set; }

    public string FullName { get; set; } = "";

    public string Email { get; set; } = "";

    public bool IsActive { get; set; }

    public string RolesCsv { get; set; } = "";
}

public class UserDetailsVm
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

    public string? NgoName { get; set; }
    public string? NgoStaffTitle { get; set; }

    public string? ShelterName { get; set; }
}