using System.ComponentModel.DataAnnotations;

namespace SmartAidNavigator.Web.Models;

public class BeneficiaryNeed
{
    public long NeedId { get; set; }

    public long BeneficiaryId { get; set; }
    public Beneficiary? Beneficiary { get; set; }

    public long ItemId { get; set; }
    public AidItem? Item { get; set; }

    public int RequiredQuantity { get; set; }

    // LOW / MEDIUM / HIGH / CRITICAL
    [MaxLength(10)]
    public string Priority { get; set; } = "MEDIUM";

    // SUBMITTED / UNDER_REVIEW / APPROVED / REJECTED / AWAITING_DONATION / READY_FOR_PICKUP / FULFILLED
    [MaxLength(30)]
    public string RequestStatus { get; set; } = "SUBMITTED";

    public long? RequestedByUserId { get; set; }
    public User? RequestedByUser { get; set; }

    public long? ReviewedByUserId { get; set; }
    public User? ReviewedByUser { get; set; }

    public DateTime? ReviewedAt { get; set; }

    public long? FulfilledByUserId { get; set; }
    public User? FulfilledByUser { get; set; }

    public DateTime? FulfilledAt { get; set; }

    [MaxLength(255)]
    public string? RejectionReason { get; set; }

    [MaxLength(255)]
    public string? Notes { get; set; }

    public DateTime CreatedAt { get; set; }

}