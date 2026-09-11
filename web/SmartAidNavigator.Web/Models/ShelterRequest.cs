using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class ShelterRequest
{
    public long RequestId { get; set; }

    public long ShelterId { get; set; }
    public Shelter? Shelter { get; set; }

    public long UserId { get; set; }
    public User? User { get; set; }

    public int BabiesMale { get; set; }
    public int BabiesFemale { get; set; }
    public int KidsMale { get; set; }
    public int KidsFemale { get; set; }
    public int AdultMale { get; set; }
    public int AdultFemale { get; set; }
    public int TotalPeople { get; set; }

    public string Status { get; set; } = "PENDING";

    public long? ConfirmedUserId { get; set; }
    public User? ConfirmedByUser { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime? ConfirmedAt { get; set; }

    [MaxLength(30)]
    //public string Status { get; set; } = "PENDING";

    public DateTime? ArrivedAt { get; set; }

    public long? ProcessedByUserId { get; set; }
    public User? ProcessedByUser { get; set; }

    public ICollection<ShelterRequestDependent> Dependents { get; set; } = new List<ShelterRequestDependent>();
}
