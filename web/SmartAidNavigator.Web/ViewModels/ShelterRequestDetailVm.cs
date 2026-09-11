using System.ComponentModel.DataAnnotations;
using SmartAidNavigator.Web.Models;

namespace SmartAidNavigator.Web.ViewModels;

public class ShelterRequestDetailVm
{
    public ShelterRequest Request { get; set; } = new();

    public RequestCountsEditVm Counts { get; set; } = new();

    public AddRequestDependentVm NewDependent { get; set; } = new();
}

public class RequestCountsEditVm
{
    public long RequestId { get; set; }

    public int BabiesMale { get; set; }
    public int BabiesFemale { get; set; }
    public int KidsMale { get; set; }
    public int KidsFemale { get; set; }
    public int AdultMale { get; set; }
    public int AdultFemale { get; set; }
}

public class AddRequestDependentVm
{
    public long RequestId { get; set; }

    [Required, MaxLength(160)]
    public string FullName { get; set; } = "";

    [MaxLength(40)]
    public string? IcOrPassport { get; set; }

    [MaxLength(30)]
    public string? Phone { get; set; }

    [MaxLength(190)]
    public string? Email { get; set; }

    [MaxLength(20)]
    public string? Gender { get; set; }

    public DateOnly? DateOfBirth { get; set; }

    [MaxLength(50)]
    public string RelationshipType { get; set; } = "CHILD";

    [MaxLength(255)]
    public string? AddressLine { get; set; }

    [MaxLength(100)]
    public string? City { get; set; }

    [MaxLength(100)]
    public string? State { get; set; }

    [MaxLength(20)]
    public string? PostalCode { get; set; }
}