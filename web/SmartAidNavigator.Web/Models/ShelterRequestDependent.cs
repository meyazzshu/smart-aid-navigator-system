namespace SmartAidNavigator.Web.Models;

public class ShelterRequestDependent
{
    public long RequestDependentId { get; set; }

    public long RequestId { get; set; }
    public ShelterRequest? Request { get; set; }

    public long RelationshipId { get; set; }
    public PersonRelationship? Relationship { get; set; }

    public DateTime CreatedAt { get; set; }
}
