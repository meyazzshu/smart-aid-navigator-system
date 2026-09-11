namespace SmartAidNavigator.Web.Models;

public class Payment
{
    public long PaymentId { get; set; }

    public long DonationId { get; set; }
    public Donation? Donation { get; set; }

    public decimal Amount { get; set; }

    public string Currency { get; set; } = "MYR";
    public string Method { get; set; } = "OTHER";

    public string? Provider { get; set; }
    public string? ProviderRef { get; set; }
    public string? ProviderBillCode { get; set; }
    public string? ProviderInvoiceNo { get; set; }
    public string? ExternalReferenceNo { get; set; }
    public string? CallbackRaw { get; set; }
    public string? ReceiptToken { get; set; }

    public DateTime? ReceiptIssuedAt { get; set; }

    public string PaymentStatus { get; set; } = "PENDING";

    public DateTime? PaidAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
}