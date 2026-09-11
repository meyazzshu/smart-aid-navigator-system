using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class PriorityCategory
{
    public int PriorityId { get; set; }

    [Required, MaxLength(60)]
    public string PriorityName { get; set; } = "";

    [MaxLength(255)]
    public string? Description { get; set; }

    public int Weight { get; set; } = 1;
}
