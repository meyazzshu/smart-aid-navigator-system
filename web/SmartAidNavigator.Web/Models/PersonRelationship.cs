using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class PersonRelationship
{
    public long RelationshipId { get; set; }

    public long MainPersonId { get; set; }
    public Person? MainPerson { get; set; }

    public long RelatedPersonId { get; set; }
    public Person? RelatedPerson { get; set; }

    [Required, MaxLength(20)]
    public string RelationshipType { get; set; } = "DEPENDENT";

    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
