using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartAidNavigator.Web.Data;
using SmartAidNavigator.Web.Filters;
using SmartAidNavigator.Web.Helpers;
using SmartAidNavigator.Web.Models;
using SmartAidNavigator.Web.ViewModels;

namespace SmartAidNavigator.Web.Controllers;

[RequireRole("SHELTER_MANAGER")]
public class BeneficiariesController : Controller
{
    private readonly AppDbContext _db;
    private readonly IConfiguration _configuration;

    public BeneficiariesController(AppDbContext db, IConfiguration configuration)
    {
        _db = db;
        _configuration = configuration;
    }

    private void LoadGoogleMapsApiKey()
    {
        ViewBag.GoogleMapsApiKey = _configuration["GoogleMaps:ApiKey"]
            ?? Environment.GetEnvironmentVariable("GOOGLE_MAPS_API_KEY");
    }

    private static string NormalizeStatus(string? status)
        => string.IsNullOrWhiteSpace(status) ? BeneficiaryStatuses.Active : status.Trim().ToUpperInvariant();

    public async Task<IActionResult> Index(
    string? search,
    string? gender,
    string? ageGroup,
    string? status,
    string? sortBy)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        search = string.IsNullOrWhiteSpace(search) ? null : search.Trim();
        gender = string.IsNullOrWhiteSpace(gender) ? null : gender.Trim();
        ageGroup = string.IsNullOrWhiteSpace(ageGroup) ? null : ageGroup.Trim().ToLower();
        status = string.IsNullOrWhiteSpace(status) ? null : status.Trim().ToUpperInvariant();
        sortBy = string.IsNullOrWhiteSpace(sortBy) ? "newest" : sortBy.Trim().ToLower();

        var allRows = await _db.Beneficiaries
            .Include(b => b.Person)
            .Where(b => b.ShelterId == shelterId)
            .ToListAsync();

        var totalCount = allRows.Count;
        var activeCount = allRows.Count(x => x.Status == BeneficiaryStatuses.Active);
        var dischargedCount = allRows.Count(x => x.Status == "DISCHARGED");
        var maleCount = allRows.Count(x => (x.Person?.Gender ?? "").Equals("Male", StringComparison.OrdinalIgnoreCase));
        var femaleCount = allRows.Count(x => (x.Person?.Gender ?? "").Equals("Female", StringComparison.OrdinalIgnoreCase));

        var rows = allRows.AsEnumerable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            rows = rows.Where(x =>
                (x.Person?.FullName ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (x.Person?.IcOrPassport ?? "").Contains(search, StringComparison.OrdinalIgnoreCase) ||
                (x.Person?.Phone ?? "").Contains(search, StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(gender))
        {
            rows = rows.Where(x => (x.Person?.Gender ?? "").Equals(gender, StringComparison.OrdinalIgnoreCase));
        }

        if (!string.IsNullOrWhiteSpace(status))
        {
            rows = rows.Where(x => x.Status.Equals(status, StringComparison.OrdinalIgnoreCase));
        }

        rows = ageGroup switch
        {
            "children" => rows.Where(x => PersonHelper.IsChild(x.Person?.DateOfBirth)),
            "adult" => rows.Where(x => !PersonHelper.IsChild(x.Person?.DateOfBirth)),
            _ => rows
        };

        rows = sortBy switch
        {
            "name-asc" => rows.OrderBy(x => x.Person?.FullName),
            "name-desc" => rows.OrderByDescending(x => x.Person?.FullName),
            "oldest" => rows.OrderBy(x => x.CreatedAt),
            "active-first" => rows.OrderByDescending(x => x.Status == BeneficiaryStatuses.Active)
                                  .ThenByDescending(x => x.CreatedAt),
            "discharged-first" => rows.OrderByDescending(x => x.Status == "DISCHARGED")
                                      .ThenByDescending(x => x.CreatedAt),
            "male" => rows.OrderByDescending(x => (x.Person?.Gender ?? "").Equals("Male", StringComparison.OrdinalIgnoreCase)),
            "female" => rows.OrderByDescending(x => (x.Person?.Gender ?? "").Equals("Female", StringComparison.OrdinalIgnoreCase)),
            "children" => rows.OrderByDescending(x => PersonHelper.IsChild(x.Person?.DateOfBirth)),
            _ => rows.OrderByDescending(x => x.CreatedAt)
        };

        var vm = new BeneficiaryIndexVm
        {
            Search = search,
            Gender = gender,
            AgeGroup = ageGroup,
            Status = status,
            SortBy = sortBy,

            TotalCount = totalCount,
            ActiveCount = activeCount,
            DischargedCount = dischargedCount,
            MaleCount = maleCount,
            FemaleCount = femaleCount,

            Rows = rows.ToList()
        };

        return View(vm);
    }

    public async Task<IActionResult> Details(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var b = await _db.Beneficiaries
            .Include(x => x.Person)
            .Include(x => x.Shelter)
            .FirstOrDefaultAsync(x => x.BeneficiaryId == id && x.ShelterId == shelterId);

        if (b == null || b.Person == null) return NotFound();

        var vm = new BeneficiaryDetailsVm
        {
            BeneficiaryId = b.BeneficiaryId,
            PersonId = b.PersonId,
            ShelterId = b.ShelterId,

            FullName = b.Person.FullName,
            IcOrPassport = b.Person.IcOrPassport,
            Phone = b.Person.Phone,
            Gender = b.Person.Gender,
            DateOfBirth = b.Person.DateOfBirth,

            AddressLine = b.Person.AddressLine,
            City = b.Person.City,
            State = b.Person.State,
            PostalCode = b.Person.PostalCode,

            Status = b.Status,
            AdmittedAt = b.AdmittedAt,
            DischargedAt = b.DischargedAt,
            CreatedAt = b.CreatedAt,

            ShelterName = b.Shelter?.ShelterName ?? "-"
        };

        return View(vm);
    }

    public IActionResult Create()
    {
        LoadGoogleMapsApiKey();
        return View(new BeneficiaryUpsertVm());
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Create(BeneficiaryUpsertVm vm)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var normalizedStatus = NormalizeStatus(vm.Status);
        if (!BeneficiaryStatuses.Allowed.Contains(normalizedStatus))
            ModelState.AddModelError(nameof(vm.Status), "Invalid status.");

        if (!ModelState.IsValid)
        {
            LoadGoogleMapsApiKey();
            return View(vm);
        }

        Person? person = null;
        var normalizedIc = string.IsNullOrWhiteSpace(vm.IcOrPassport) ? null : vm.IcOrPassport.Trim();
        if (!string.IsNullOrEmpty(normalizedIc))
        {
            person = await _db.Persons.FirstOrDefaultAsync(p => p.IcOrPassport == normalizedIc);
        }

        if (person == null)
        {
            person = new Person
            {
                FullName = vm.FullName.Trim(),
                IcOrPassport = normalizedIc,
                Phone = string.IsNullOrWhiteSpace(vm.Phone) ? null : vm.Phone.Trim(),
                Gender = string.IsNullOrWhiteSpace(vm.Gender) ? null : vm.Gender.Trim(),
                DateOfBirth = vm.DateOfBirth,
                AddressLine = string.IsNullOrWhiteSpace(vm.AddressLine) ? null : vm.AddressLine.Trim(),
                City = string.IsNullOrWhiteSpace(vm.City) ? null : vm.City.Trim(),
                State = string.IsNullOrWhiteSpace(vm.State) ? null : vm.State.Trim(),
                PostalCode = string.IsNullOrWhiteSpace(vm.PostalCode) ? null : vm.PostalCode.Trim(),
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            _db.Persons.Add(person);
            await _db.SaveChangesAsync();
        }

        var b = new Beneficiary
        {
            PersonId = person.PersonId,
            ShelterId = shelterId,
            Status = normalizedStatus,
            AdmittedAt = DateTime.UtcNow,
            CreatedAt = DateTime.UtcNow
        };

        _db.Beneficiaries.Add(b);
        await _db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }

    public async Task<IActionResult> Edit(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var b = await _db.Beneficiaries
            .Include(x => x.Person)
            .FirstOrDefaultAsync(x => x.BeneficiaryId == id && x.ShelterId == shelterId);
        if (b == null) return NotFound();

        var vm = new BeneficiaryUpsertVm
        {
            BeneficiaryId = b.BeneficiaryId,
            FullName = b.Person?.FullName ?? "",
            IcOrPassport = b.Person?.IcOrPassport,
            Phone = b.Person?.Phone,
            Gender = b.Person?.Gender,
            DateOfBirth = b.Person?.DateOfBirth,
            AddressLine = b.Person?.AddressLine,
            City = b.Person?.City,
            State = b.Person?.State,
            PostalCode = b.Person?.PostalCode,
            Status = b.Status
        };

        LoadGoogleMapsApiKey();
        return View(vm);
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Edit(long id, BeneficiaryUpsertVm vm)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);
        var normalizedStatus = NormalizeStatus(vm.Status);
        if (!BeneficiaryStatuses.Allowed.Contains(normalizedStatus))
            ModelState.AddModelError(nameof(vm.Status), "Invalid status.");

        if (id != vm.BeneficiaryId) return BadRequest();

        if (!ModelState.IsValid)
        {
            LoadGoogleMapsApiKey();
            return View(vm);
        }

        var b = await _db.Beneficiaries
            .Include(x => x.Person)
            .FirstOrDefaultAsync(x => x.BeneficiaryId == id && x.ShelterId == shelterId);
        if (b == null || b.Person == null) return NotFound();

        b.Status = normalizedStatus;
        b.Person.FullName = vm.FullName.Trim();
        b.Person.IcOrPassport = string.IsNullOrWhiteSpace(vm.IcOrPassport) ? null : vm.IcOrPassport.Trim();
        b.Person.Phone = string.IsNullOrWhiteSpace(vm.Phone) ? null : vm.Phone.Trim();
        b.Person.Gender = string.IsNullOrWhiteSpace(vm.Gender) ? null : vm.Gender.Trim();
        b.Person.DateOfBirth = vm.DateOfBirth;
        b.Person.AddressLine = string.IsNullOrWhiteSpace(vm.AddressLine) ? null : vm.AddressLine.Trim();
        b.Person.City = string.IsNullOrWhiteSpace(vm.City) ? null : vm.City.Trim();
        b.Person.State = string.IsNullOrWhiteSpace(vm.State) ? null : vm.State.Trim();
        b.Person.PostalCode = string.IsNullOrWhiteSpace(vm.PostalCode) ? null : vm.PostalCode.Trim();
        b.Person.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Discharge(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var beneficiary = await _db.Beneficiaries
            .FirstOrDefaultAsync(x => x.BeneficiaryId == id && x.ShelterId == shelterId);

        if (beneficiary == null)
        {
            return NotFound();
        }

        if (beneficiary.Status == "DISCHARGED")
        {
            TempData["Error"] = "This beneficiary has already been discharged.";
            return RedirectToAction(nameof(Index));
        }

        beneficiary.Status = "DISCHARGED";
        beneficiary.DischargedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();

        TempData["Success"] = "Beneficiary discharged successfully.";
        return RedirectToAction(nameof(Index));
    }

    [HttpPost, ActionName("Delete")]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> DeleteConfirmed(long id)
    {
        var shelterId = await CurrentUserHelper.GetMyShelterIdAsync(HttpContext, _db);

        var b = await _db.Beneficiaries.FirstOrDefaultAsync(x => x.BeneficiaryId == id && x.ShelterId == shelterId);
        if (b == null) return NotFound();

        _db.Beneficiaries.Remove(b);
        await _db.SaveChangesAsync();
        return RedirectToAction(nameof(Index));
    }
}
