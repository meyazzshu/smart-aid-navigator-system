using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class User
{
    public long UserId { get; set; }

    public long PersonId { get; set; }
    public Person? Person { get; set; }

    [MaxLength(255)]
    public string? PasswordHash { get; set; } // Nullable, guest users (IsGuest=true) have no password

    public bool IsActive { get; set; } = true;
    public bool IsGuest { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<UserRole> UserRoles { get; set; } = new List<UserRole>();
}
