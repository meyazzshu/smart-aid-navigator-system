using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class NgoStaff
{
    public long NgoId { get; set; }
    public long UserId { get; set; }

    [MaxLength(100)]
    public string? StaffTitle { get; set; }
}
