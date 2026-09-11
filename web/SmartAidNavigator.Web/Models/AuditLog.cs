using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class AuditLog
{
    public long LogId { get; set; }

    public long? UserId { get; set; }
    public User? User { get; set; }

    [Required, MaxLength(120)]
    public string Action { get; set; } = "";

    [MaxLength(80)]
    public string? Entity { get; set; }

    public long? EntityId { get; set; }

    public string? Detail { get; set; }

    public DateTime CreatedAt { get; set; }
}
