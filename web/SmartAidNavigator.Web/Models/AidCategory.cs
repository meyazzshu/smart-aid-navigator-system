using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class AidCategory
{
    public int CategoryId { get; set; }

    [Required, MaxLength(80)]
    public string CategoryName { get; set; } = "";

    public ICollection<AidItem> Items { get; set; } = new List<AidItem>();
}
