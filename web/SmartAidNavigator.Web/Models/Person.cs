using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class Person
{
    public long PersonId { get; set; }

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

    [MaxLength(255)]
    public string? AddressLine { get; set; }

    [MaxLength(100)]
    public string? City { get; set; }

    [MaxLength(100)]
    public string? State { get; set; }

    [MaxLength(20)]
    public string? PostalCode { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public User? User { get; set; }

    public ICollection<Beneficiary> Beneficiaries { get; set; } = new List<Beneficiary>();
    public ICollection<PersonRelationship> MainPersonRelationships { get; set; } = new List<PersonRelationship>();
    public ICollection<PersonRelationship> RelatedPersonRelationships { get; set; } = new List<PersonRelationship>();
}
