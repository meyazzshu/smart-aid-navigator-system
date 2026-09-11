using System.ComponentModel.DataAnnotations;
namespace SmartAidNavigator.Web.Models;

public class ShelterAssessment
{
    public long AssessmentId { get; set; }

    public long ShelterId { get; set; }
    public Shelter? Shelter { get; set; }

    public int BabiesCount { get; set; }
    public int ElderlyCount { get; set; }

    public RiskLevel RiskLevel { get; set; } = RiskLevel.LOW;

    [MaxLength(255)]
    public string? SituationNotes { get; set; }

    public long? AssessedBy { get; set; }
    public User? AssessedByUser { get; set; }

    public DateTime AssessedAt { get; set; }
}
