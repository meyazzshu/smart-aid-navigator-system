using Microsoft.AspNetCore.Mvc.Rendering;
using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.ViewModels;

public class DeliveryCreateVm
{
    [Required]
    public long NgoId { get; set; }

    [Required]
    public long ShelterId { get; set; }

    public DateOnly? ScheduledDate { get; set; }

    public string? Notes { get; set; }
    public long? BeneficiaryNeedId { get; set; }

    public List<DeliveryCreateItemVm> DeliveryItems { get; set; } = new()
    {
        new DeliveryCreateItemVm()
    };

    public List<SelectListItem> Ngos { get; set; } = new();

    public List<SelectListItem> Shelters { get; set; } = new();

    public List<SelectListItem> Items { get; set; } = new();
}

public class DeliveryCreateItemVm
{
    [Required(ErrorMessage = "Please select an item.")]
    public long? ItemId { get; set; }

    [Range(1, 100000, ErrorMessage = "Quantity must be at least 1.")]
    public int Quantity { get; set; } = 1;
}