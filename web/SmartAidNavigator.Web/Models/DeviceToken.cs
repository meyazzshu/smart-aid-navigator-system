using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class DeviceToken
{
    public long TokenId { get; set; }

    public long UserId { get; set; }
    public User? User { get; set; }

    [Required, MaxLength(255)]
    public string Token { get; set; } = "";

    [MaxLength(20)]
    public string Platform { get; set; } = "android";

    public bool IsActive { get; set; } = true;

    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}
