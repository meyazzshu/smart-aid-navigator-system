using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.Services;
using SmartAidNavigator.Web.ViewModels.Reports;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("SHELTER_MANAGER")]
public class ShelterReportsController : Controller
{
    private readonly AppDbContext _db;
    private readonly ReportPdfService _pdf;

    public ShelterReportsController(AppDbContext db, ReportPdfService pdf)
    {
        _db = db;
        _pdf = pdf;
    }

    private async Task<long> GetMyShelterIdAsync()
    {
        return await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);
    }

    public IActionResult Index()
    {
        return View();
    }

    public async Task<IActionResult> Inventory()
    {
        var vm = await BuildInventoryReport();
        return View("ReportTable", vm);
    }

    public async Task<IActionResult> InventoryPdf()
    {
        var vm = await BuildInventoryReport();
        var bytes = _pdf.GenerateReportPdf(vm);
        return File(bytes, "application/pdf", "Shelter_Inventory_Report.pdf");
    }

    private async Task<ReportVm> BuildInventoryReport()
    {
        var shelterId = await GetMyShelterIdAsync();

        var inventory = await _db.ShelterInventory
            .Include(x => x.Item)
                .ThenInclude(x => x!.Category)
            .Where(x => x.ShelterId == shelterId)
            .OrderBy(x => x.Item!.ItemName)
            .ToListAsync();

        var lowStock = inventory.Count(x => x.MinimumLevel > 0 && x.Quantity < x.MinimumLevel);

        var vm = new ReportVm
        {
            Title = "Inventory Report",
            Subtitle = "Current shelter inventory quantity, minimum level, and stock condition.",
            RoleLabel = "Shelter Manager",
            PdfAction = "InventoryPdf",

            Stats =
            {
                new ReportStatVm { Label = "Item Types", Value = inventory.Count.ToString(), Icon = "fa-solid fa-warehouse", Color = "blue" },
                new ReportStatVm { Label = "Total Quantity", Value = inventory.Sum(x => x.Quantity).ToString(), Icon = "fa-solid fa-cubes", Color = "green" },
                new ReportStatVm { Label = "Low Stock", Value = lowStock.ToString(), Icon = "fa-solid fa-triangle-exclamation", Color = "orange" },
                new ReportStatVm { Label = "Adequate", Value = (inventory.Count - lowStock).ToString(), Icon = "fa-solid fa-circle-check", Color = "purple" }
            },

            Columns = { "Item", "Category", "Quantity", "Unit", "Minimum Level", "Status" }
        };

        foreach (var i in inventory)
        {
            var status = i.MinimumLevel > 0 && i.Quantity < i.MinimumLevel
                ? "LOW STOCK"
                : "ADEQUATE";

            vm.Rows.Add(new List<string>
            {
                i.Item?.ItemName ?? "-",
                i.Item?.Category?.CategoryName ?? "-",
                i.Quantity.ToString(),
                i.Item?.Unit ?? "-",
                i.MinimumLevel.ToString(),
                status
            });
        }

        return vm;
    }

    public async Task<IActionResult> Beneficiary()
    {
        var vm = await BuildBeneficiaryReport();
        return View("ReportTable", vm);
    }

    public async Task<IActionResult> BeneficiaryPdf()
    {
        var vm = await BuildBeneficiaryReport();
        var bytes = _pdf.GenerateReportPdf(vm);
        return File(bytes, "application/pdf", "Shelter_Beneficiary_Report.pdf");
    }

    private async Task<ReportVm> BuildBeneficiaryReport()
    {
        var shelterId = await GetMyShelterIdAsync();

        var beneficiaries = await _db.Beneficiaries
            .Include(x => x.Person)
            .Where(x => x.ShelterId == shelterId)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        var activeCount = beneficiaries.Count(x => x.Status == "ACTIVE");

        var vm = new ReportVm
        {
            Title = "Beneficiary Report",
            Subtitle = "Registered beneficiaries under your shelter.",
            RoleLabel = "Shelter Manager",
            PdfAction = "BeneficiaryPdf",

            Stats =
            {
                new ReportStatVm { Label = "Total", Value = beneficiaries.Count.ToString(), Icon = "fa-solid fa-people-group", Color = "blue" },
                new ReportStatVm { Label = "Active", Value = activeCount.ToString(), Icon = "fa-solid fa-circle-check", Color = "green" },
                new ReportStatVm { Label = "Male", Value = beneficiaries.Count(x => (x.Person?.Gender ?? "").ToUpper() == "MALE").ToString(), Icon = "fa-solid fa-person", Color = "purple" },
                new ReportStatVm { Label = "Female", Value = beneficiaries.Count(x => (x.Person?.Gender ?? "").ToUpper() == "FEMALE").ToString(), Icon = "fa-solid fa-person-dress", Color = "orange" }
            },

            Columns = { "Beneficiary ID", "Full Name", "IC / Passport", "Phone", "Gender", "Status", "Registered" }
        };

        foreach (var b in beneficiaries)
        {
            vm.Rows.Add(new List<string>
            {
                b.BeneficiaryId.ToString(),
                b.Person?.FullName ?? "-",
                b.Person?.IcOrPassport ?? "-",
                b.Person?.Phone ?? "-",
                b.Person?.Gender ?? "-",
                b.Status,
                b.CreatedAt.ToString("dd MMM yyyy")
            });
        }

        return vm;
    }

    public async Task<IActionResult> BeneficiaryNeeds()
    {
        var vm = await BuildBeneficiaryNeedsReport();
        return View("ReportTable", vm);
    }

    public async Task<IActionResult> BeneficiaryNeedsPdf()
    {
        var vm = await BuildBeneficiaryNeedsReport();
        var bytes = _pdf.GenerateReportPdf(vm);
        return File(bytes, "application/pdf", "Shelter_Beneficiary_Needs_Report.pdf");
    }

    private async Task<ReportVm> BuildBeneficiaryNeedsReport()
    {
        var shelterId = await GetMyShelterIdAsync();

        var needs = await _db.BeneficiaryNeeds
            .Include(x => x.Beneficiary)
                .ThenInclude(x => x!.Person)
            .Include(x => x.Item)
            .Where(x => x.Beneficiary != null && x.Beneficiary.ShelterId == shelterId)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        var vm = new ReportVm
        {
            Title = "Beneficiary Needs Report",
            Subtitle = "Aid needs requested by beneficiaries under your shelter.",
            RoleLabel = "Shelter Manager",
            PdfAction = "BeneficiaryNeedsPdf",

            Stats =
            {
                new ReportStatVm { Label = "Total Needs", Value = needs.Count.ToString(), Icon = "fa-solid fa-hand-holding-heart", Color = "blue" },
                new ReportStatVm { Label = "High/Critical", Value = needs.Count(x => x.Priority == "HIGH" || x.Priority == "CRITICAL").ToString(), Icon = "fa-solid fa-triangle-exclamation", Color = "orange" },
                new ReportStatVm { Label = "Awaiting", Value = needs.Count(x => x.RequestStatus == "AWAITING_DONATION").ToString(), Icon = "fa-solid fa-clock", Color = "purple" },
                new ReportStatVm { Label = "Fulfilled", Value = needs.Count(x => x.RequestStatus == "FULFILLED").ToString(), Icon = "fa-solid fa-check-double", Color = "green" }
            },

            Columns = { "Need ID", "Beneficiary", "Item", "Qty", "Priority", "Status", "Created" }
        };

        foreach (var n in needs)
        {
            vm.Rows.Add(new List<string>
            {
                n.NeedId.ToString(),
                n.Beneficiary?.Person?.FullName ?? "-",
                n.Item?.ItemName ?? "-",
                n.RequiredQuantity.ToString(),
                n.Priority,
                n.RequestStatus,
                n.CreatedAt.ToString("dd MMM yyyy")
            });
        }

        return vm;
    }

    public async Task<IActionResult> IncomingReceivedAid()
    {
        var vm = await BuildIncomingReceivedAidReport();
        return View("ReportTable", vm);
    }

    public async Task<IActionResult> IncomingReceivedAidPdf()
    {
        var vm = await BuildIncomingReceivedAidReport();
        var bytes = _pdf.GenerateReportPdf(vm);
        return File(bytes, "application/pdf", "Shelter_Incoming_Received_Aid_Report.pdf");
    }

    private async Task<ReportVm> BuildIncomingReceivedAidReport()
    {
        var shelterId = await GetMyShelterIdAsync();

        var deliveries = await _db.Deliveries
            .Include(x => x.Ngo)
            .Include(x => x.DeliveryItems)
                .ThenInclude(x => x.Item)
            .Where(x => x.ShelterId == shelterId)
            .OrderByDescending(x => x.CreatedAt)
            .ToListAsync();

        var received = deliveries.Where(x => x.Status == DeliveryStatus.DELIVERED).ToList();

        var vm = new ReportVm
        {
            Title = "Incoming/Received Aid Report",
            Subtitle = "Incoming and received aid deliveries for your shelter.",
            RoleLabel = "Shelter Manager",
            PdfAction = "IncomingReceivedAidPdf",

            Stats =
            {
                new ReportStatVm { Label = "Total Deliveries", Value = deliveries.Count.ToString(), Icon = "fa-solid fa-truck", Color = "blue" },
                new ReportStatVm { Label = "Incoming", Value = deliveries.Count(x => x.Status == DeliveryStatus.PLANNED || x.Status == DeliveryStatus.ROUTED || x.Status == DeliveryStatus.IN_TRANSIT).ToString(), Icon = "fa-solid fa-truck-fast", Color = "orange" },
                new ReportStatVm { Label = "Received", Value = received.Count.ToString(), Icon = "fa-solid fa-check-double", Color = "green" },
                new ReportStatVm { Label = "Total Qty", Value = received.Sum(x => x.DeliveryItems.Sum(i => i.Quantity)).ToString(), Icon = "fa-solid fa-cubes", Color = "purple" }
            },

            Columns = { "Delivery ID", "NGO", "Status", "Scheduled", "Item", "Quantity", "Unit" }
        };

        foreach (var d in deliveries)
        {
            if (d.DeliveryItems.Any())
            {
                foreach (var item in d.DeliveryItems)
                {
                    vm.Rows.Add(new List<string>
                    {
                        d.DeliveryId.ToString(),
                        d.Ngo?.NgoName ?? "-",
                        d.Status.ToString(),
                        d.ScheduledDate?.ToString("dd MMM yyyy") ?? "-",
                        item.Item?.ItemName ?? "-",
                        item.Quantity.ToString(),
                        item.Item?.Unit ?? "-"
                    });
                }
            }
            else
            {
                vm.Rows.Add(new List<string>
                {
                    d.DeliveryId.ToString(),
                    d.Ngo?.NgoName ?? "-",
                    d.Status.ToString(),
                    d.ScheduledDate?.ToString("dd MMM yyyy") ?? "-",
                    "-",
                    "0",
                    "-"
                });
            }
        }

        return vm;
    }
}